import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:adb_player/page/play/code_rain_page.dart';
import 'package:adb_player/page/play/food_roulette_page.dart';
import 'package:adb_player/page/play/liang_calibrator_page.dart';
import 'package:adb_player/page/play/short_video_page.dart';
import 'package:adb_player/page/play/watermark_remove_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

/// 赏心悦目 —— 全屏 PageView 上下滑动播放
const List<String> _shortVideoUrls = [
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/video_c0e5e2e.mp4',
];

/// 风景视频 —— 复用短视频播放器
const List<String> _landscapeVideoUrls = [
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/video_92ec12a.mp4',
];

class PlayPage extends StatefulWidget {
  /// 全屏覆盖展示（隐蔽入口打开时为 true）
  final bool fullscreen;

  /// 全屏关闭回调
  final VoidCallback? onClose;

  const PlayPage({
    Key? key,
    this.fullscreen = false,
    this.onClose,
  }) : super(key: key);

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  static const String _laborBgmAsset =
      "file/it's 6pm but I miss u already (0.8x).mp3";

  bool _showLaborLawPdf = false;
  bool _showFoodRoulette = false;
  bool _showWatermarkRemove = false;
  bool _showLiangCalibrator = false;
  List<String>? _videoFeedUrls;
  String _videoFeedTitle = '赏心悦目';
  // Windows 不支持 PdfViewPinch，需用 PdfView + PdfController
  PdfControllerPinch? _pdfPinchController;
  PdfController? _pdfController;

  AudioPlayer? _laborPlayer;
  File? _laborBgmTempFile;
  bool _laborMuted = true;
  double _laborVolume = 1.0;

  bool get _usePdfPinch => !Platform.isWindows;

  void _disposePdfControllers() {
    _pdfPinchController?.dispose();
    _pdfPinchController = null;
    _pdfController?.dispose();
    _pdfController = null;
  }

  @override
  void dispose() {
    _disposePdfControllers();
    _disposeLaborPlayer();
    super.dispose();
  }

  void _disposeLaborPlayer() {
    final player = _laborPlayer;
    final temp = _laborBgmTempFile;
    _laborPlayer = null;
    _laborBgmTempFile = null;
    if (player == null && temp == null) return;
    // 先 stop 再 dispose，避免 Temp 资源被占用；播完后清理临时文件
    unawaited(() async {
      try {
        await player?.stop();
      } catch (_) {}
      try {
        await player?.dispose();
      } catch (_) {}
      try {
        if (temp != null && await temp.exists()) {
          await temp.delete();
        }
      } catch (_) {}
    }());
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_videoFeedUrls != null) {
      // 赏心悦目 / 风景面板从上到下全黑，不要外层白底+padding
      content = Container(
        color: const Color(0xFF111114),
        child: _buildShortVideoView(),
      );
    } else if (_showLiangCalibrator) {
      // 滑动变祖器直接撑满，不要外层 padding / 圆角
      content = SizedBox.expand(
        child: LiangCalibratorPage(
          onClose: () => setState(() => _showLiangCalibrator = false),
        ),
      );
    } else {
      final Widget body;
      if (_showLaborLawPdf) {
        body = _buildLaborLawPdfView();
      } else if (_showFoodRoulette) {
        body = FoodRoulettePage(
          onClose: () => setState(() => _showFoodRoulette = false),
        );
      } else if (_showWatermarkRemove) {
        body = WatermarkRemovePage(
          onClose: () => setState(() => _showWatermarkRemove = false),
        );
      } else {
        body = _buildPlayCards();
      }
      content = Container(
        color: (_showLaborLawPdf ||
                _showFoodRoulette ||
                _showWatermarkRemove)
            ? Colors.white
            : widget.fullscreen
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.transparent,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: body,
        ),
      );
    }

    if (!widget.fullscreen) return content;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: '关闭 (Esc)',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 默认展示的趣味功能卡片（每行最多 4 个）
  Widget _buildPlayCards() {
    const gap = 14.0;
    final items = <Widget>[
      _PlayFeatureCard(
        icon: Icons.restaurant_rounded,
        title: '吃什么',
        subtitle: '转盘帮你决定',
        accent: const Color(0xFFE07A5F),
        onTap: () => setState(() => _showFoodRoulette = true),
      ),
      _PlayFeatureCard(
        icon: Icons.menu_book_rounded,
        title: '劳动法',
        subtitle: '摸鱼也要懂法',
        accent: const Color(0xFF5B7CFF),
        onTap: _openLaborLawPdf,
      ),
      _PlayFeatureCard(
        icon: Icons.terminal_rounded,
        title: '装忙模式',
        subtitle: '老板来了装认真',
        accent: const Color(0xFF2A9D8F),
        onTap: _openCodeRain,
      ),
      _PlayFeatureCard(
        icon: Icons.face_retouching_natural,
        title: '赏心悦目',
        subtitle: '刷一刷视频歇会儿',
        accent: const Color(0xFFE85D75),
        onTap: _openShortVideos,
      ),
      _PlayFeatureCard(
        icon: Icons.landscape_rounded,
        title: '风景',
        subtitle: '看看山河养养眼',
        accent: const Color(0xFF3D8B7A),
        onTap: _openLandscapeVideos,
      ),
      _PlayFeatureCard(
        icon: Icons.tune_rounded,
        title: '滑动变祖器',
        subtitle: '31 级梁系校准',
        accent: const Color(0xFFC23A2B),
        onTap: _openLiangCalibrator,
      ),
      _PlayFeatureCard(
        icon: Icons.water_drop_outlined,
        title: '去水印',
        subtitle: '抖音 / 快手 / 图文',
        accent: const Color(0xFF6C5CE7),
        onTap: () => setState(() => _showWatermarkRemove = true),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }

  void _openShortVideos() {
    setState(() {
      _videoFeedTitle = '赏心悦目';
      _videoFeedUrls = _shortVideoUrls;
    });
  }

  void _openLandscapeVideos() {
    setState(() {
      _videoFeedTitle = '风景';
      _videoFeedUrls = _landscapeVideoUrls;
    });
  }

  Widget _buildShortVideoView() {
    final urls = _videoFeedUrls ?? _shortVideoUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _videoFeedUrls = null;
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                _videoFeedTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ShortVideoPage(urls: urls),
        ),
      ],
    );
  }

  void _openCodeRain() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, __, ___) => const CodeRainPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openLiangCalibrator() {
    setState(() => _showLiangCalibrator = true);
  }

  Future<void> _openLaborLawPdf() async {
    try {
      _disposePdfControllers();
      final byteData = await rootBundle.load('assets/file/劳动法学习.pdf');
      final document = PdfDocument.openData(
        byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      if (_usePdfPinch) {
        _pdfPinchController = PdfControllerPinch(document: document);
      } else {
        _pdfController = PdfController(document: document);
      }
      setState(() {
        _showLaborLawPdf = true;
      });
      await _ensureLaborPlayer();
    } catch (e) {
      SmartDialogUtils.showError('打开劳动法文档失败: $e');
    }
  }

  Future<void> _ensureLaborPlayer() async {
    if (_laborPlayer != null) return;
    final player = AudioPlayer();
    _laborPlayer = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_laborMuted ? 0 : _laborVolume);
      // 写入唯一临时文件再播：
      // - Windows：避免 AssetSource 固定 Temp 路径被占用（errno 32）
      // - macOS：Darwin 未实现 BytesSource / setSourceBytes
      final source = await _prepareLaborBgmSource();
      await player.play(source);
    } catch (e) {
      if (_laborPlayer == player) {
        _laborPlayer = null;
      }
      try {
        await player.dispose();
      } catch (_) {}
      SmartDialogUtils.showError('背景音乐加载失败: $e');
    }
  }

  Future<Source> _prepareLaborBgmSource() async {
    final byteData = await rootBundle.load('assets/$_laborBgmAsset');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16);
    final file = File(
      '${dir.path}${Platform.pathSeparator}labor_bgm_${stamp}_$rand.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    _laborBgmTempFile = file;
    return DeviceFileSource(file.path);
  }

  Future<void> _toggleLaborMute() async {
    final player = _laborPlayer;
    if (player == null) return;
    setState(() => _laborMuted = !_laborMuted);
    await player.setVolume(_laborMuted ? 0 : _laborVolume);
  }

  void _closeLaborLawPdf() {
    _disposeLaborPlayer();
    _laborMuted = true;
    _laborVolume = 1.0;
    setState(() {
      _showLaborLawPdf = false;
    });
    _disposePdfControllers();
  }

  Widget _buildLaborPdfViewer() {
    const bg = BoxDecoration(color: Color.fromARGB(255, 250, 250, 250));
    if (_usePdfPinch) {
      final controller = _pdfPinchController;
      if (controller == null) return const SizedBox.shrink();
      return PdfViewPinch(
        controller: controller,
        backgroundDecoration: bg,
      );
    }
    final controller = _pdfController;
    if (controller == null) return const SizedBox.shrink();
    return PdfView(
      controller: controller,
      scrollDirection: Axis.vertical,
      backgroundDecoration: bg,
    );
  }

  Widget _buildLaborLawPdfView() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeLaborLawPdf,
                ),
                const SizedBox(width: 8),
                const Text(
                  '劳动法',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildLaborPdfViewer()),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: _LaborFab(
            tooltip: _laborMuted ? '取消静音' : '静音',
            icon: _laborMuted
                ? Icons.music_off_rounded
                : Icons.music_note_rounded,
            onPressed: _toggleLaborMute,
          ),
        ),
      ],
    );
  }
}

/// 劳动法页右下角浮层按钮
class _LaborFab extends StatelessWidget {
  const _LaborFab({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF5B7CFF),
      elevation: 3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// 玩一玩入口卡片：浅底 + 色点缀，避免整块高饱和渐变抢戏
class _PlayFeatureCard extends StatefulWidget {
  const _PlayFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_PlayFeatureCard> createState() => _PlayFeatureCardState();
}

class _PlayFeatureCardState extends State<_PlayFeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 118,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hovered ? 0.96 : 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? accent.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 18 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, color: accent, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.42),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
