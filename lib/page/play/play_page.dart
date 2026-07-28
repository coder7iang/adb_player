import 'package:adb_player/dialog/music_player_dialog.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/page/play/code_rain_page.dart';
import 'package:adb_player/page/play/short_video_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfx/pdfx.dart';

/// 短视频列表 —— 全屏 PageView 上下滑动播放
const List<String> _shortVideoUrls = [
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/46_1777994045.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/47_1777994051.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/48_1777994056.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/49_1777994059.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/50_1777994070.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/51_1777994072.mp4',
  'https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/%E7%9F%AD%E8%A7%86%E9%A2%91/52_1777994088.mp4',
];

class PlayPage extends StatefulWidget {
  const PlayPage({Key? key}) : super(key: key);

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  bool _showLaborLawPdf = false;
  bool _showShortVideo = false;
  PdfControllerPinch? _pdfController;

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showShortVideo) {
      // 短视频面板从上到下全黑，不要外层白底+padding
      return Container(
        color: const Color(0xFF111114),
        child: _buildShortVideoView(),
      );
    }
    Widget body;
    if (_showLaborLawPdf) {
      body = _buildLaborLawPdfView();
    } else {
      body = _buildPlayCards();
    }
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: body,
      ),
    );
  }

  /// 默认展示的趣味功能卡片（每行最多 4 个）
  Widget _buildPlayCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 吃什么转盘
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        SmartDialogUtils.showFoodRoulette();
                      },
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '🍽️ 吃什么',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 劳动法入口（点击后在当前区域展示网页）
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C6FFF), Color(0xFF82B1FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openLaborLawPdf,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.gavel,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '📖 劳动法',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 音乐播放入口
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E44AD), Color(0xFFE056FD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openMusicPlayer,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '🎵 音乐播放',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 装忙模式（代码雨）
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2027), Color(0xFF003B1F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openCodeRain,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terminal,
                              color: Color(0xFF00FF88),
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '💻 装忙模式',
                              style: TextStyle(
                                color: Color(0xFF00FF88),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 短视频
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF161823), Color(0xFFFE2C55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openShortVideos,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '🎬 短视频',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  void _openShortVideos() {
    setState(() {
      _showShortVideo = true;
    });
  }

  Widget _buildShortVideoView() {
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
                    _showShortVideo = false;
                  });
                },
              ),
              const SizedBox(width: 4),
              const Text(
                '短视频',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: ShortVideoPage(urls: _shortVideoUrls),
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

  void _openMusicPlayer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MusicPlayerDialog(),
    );
  }

  Future<void> _openLaborLawPdf() async {
    try {
      _pdfController?.dispose();
      final byteData = await rootBundle.load('assets/file/劳动法学习.pdf');
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(
          byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        ),
      );
      setState(() {
        _showLaborLawPdf = true;
      });
    } catch (e) {
      SmartDialogUtils.showError('打开劳动法文档失败: $e');
    }
  }

  Widget _buildLaborLawPdfView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showLaborLawPdf = false;
                });
                _pdfController?.dispose();
                _pdfController = null;
              },
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
        Expanded(
          child: _pdfController == null
              ? const SizedBox.shrink()
              : PdfViewPinch(
                  controller: _pdfController!,
                  backgroundDecoration: const BoxDecoration(
                    color: Color.fromARGB(255, 250, 250, 250),
                  ),
                ),
        ),
      ],
    );
  }
}
