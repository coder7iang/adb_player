import 'dart:async';
import 'dart:io';

import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/services/douyin_resolve_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

String _mediaImageExt(String url) {
  final u = url.toLowerCase();
  if (u.contains('.webp')) return 'webp';
  if (u.contains('.png')) return 'png';
  return 'jpg';
}

Future<void> _promptSaveVideo(
  BuildContext context, {
  required String url,
  required String suggestedName,
}) async {
  final path = await getSaveLocation(suggestedName: suggestedName);
  if (path == null) return;
  try {
    await DouyinResolveService.downloadWithReferer(
      url: url,
      savePath: path.path,
    );
    await DouyinResolveService.assertValidMp4(path.path);
    final size = await File(path.path).length();
    SmartDialogUtils.showSuccess(
      '视频已保存（${(size / 1024 / 1024).toStringAsFixed(1)} MB）',
    );
  } catch (e) {
    try {
      final f = File(path.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    SmartDialogUtils.showError('保存视频失败：$e');
  }
}

Future<void> _promptSaveImage(
  BuildContext context, {
  required String url,
  required String suggestedName,
}) async {
  final path = await getSaveLocation(suggestedName: suggestedName);
  if (path == null) return;
  try {
    await DouyinResolveService.downloadWithReferer(
      url: url,
      savePath: path.path,
    );
    SmartDialogUtils.showSuccess('图片已保存');
  } catch (e) {
    SmartDialogUtils.showError('保存图片失败：$e');
  }
}

Future<void> _showSaveContextMenu(
  BuildContext context,
  TapDownDetails details,
  VoidCallback onSave,
) async {
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      details.globalPosition.dx,
      details.globalPosition.dy,
      details.globalPosition.dx + 1,
      details.globalPosition.dy + 1,
    ),
    items: const [
      PopupMenuItem(
        value: 'save',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_alt_outlined, size: 18),
            SizedBox(width: 8),
            Text('保存'),
          ],
        ),
      ),
    ],
  );
  if (action == 'save' && context.mounted) {
    onSave();
  }
}

/// 右键弹出保存菜单
class _RightClickSaveArea extends StatelessWidget {
  const _RightClickSaveArea({
    required this.onSave,
    required this.child,
  });

  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (d) =>
          _showSaveContextMenu(context, d, onSave),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// 去水印：粘贴链接 → 小封面预览 → 弹窗播放 / 复制直链 / 保存视频
class WatermarkRemovePage extends StatefulWidget {
  const WatermarkRemovePage({Key? key, this.onClose}) : super(key: key);

  final VoidCallback? onClose;

  @override
  State<WatermarkRemovePage> createState() => _WatermarkRemovePageState();
}

class _WatermarkRemovePageState extends State<WatermarkRemovePage> {
  static const Color _accent = Color(0xFF6C5CE7);
  static const Color _ink = Color(0xFF2C2C2E);

  final TextEditingController _inputController = TextEditingController();
  late final WebViewController _webController;

  bool _resolving = false;
  bool _saving = false;
  String? _statusHint;
  DouyinResolveResult? _result;

  Completer<DouyinResolveResult>? _webCompleter;
  Timer? _pollTimer;
  int _pollCount = 0;
  String? _pendingMediaId;
  ShortVideoPlatform? _pendingPlatform;
  bool _pendingIsNote = false;
  int _lastImageCount = 0;
  int _imageStablePolls = 0;

  void _log(String msg) => debugPrint('[去水印] $msg');

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DouyinResolveService.userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _injectHook(platform: _pendingPlatform),
          onProgress: (_) => _injectHook(platform: _pendingPlatform),
          onPageFinished: (_) {
            _injectHook(platform: _pendingPlatform);
            _kickPoll();
          },
        ),
      );
  }

  Future<void> _injectHook({ShortVideoPlatform? platform}) async {
    try {
      await _webController.runJavaScript(DouyinResolveService.captureHookJs);
      if (platform == ShortVideoPlatform.kuaishou) {
        await _webController.runJavaScript(
          DouyinResolveService.kuaishouCaptureHookJs,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _webCompleter = null;
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      SmartDialogUtils.showWarning('剪贴板没有文本');
      return;
    }
    setState(() => _inputController.text = text);
  }

  Future<void> _resolve() async {
    if (_resolving) return;
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      SmartDialogUtils.showWarning('请先粘贴抖音 / 快手分享链接');
      return;
    }

    setState(() {
      _resolving = true;
      _result = null;
      _statusHint = '正在解析…';
    });
    _log('开始解析 inputLen=${input.length}');

    try {
      final platform = DouyinResolveService.detectPlatform(input);
      if (platform == null) {
        throw Exception('未识别到抖音或快手链接');
      }

      if (platform == ShortVideoPlatform.kuaishou) {
        setState(() => _statusHint = '尝试快速解析快手…');
        final http = await DouyinResolveService.tryResolveKuaishouHttp(input);
        if (http != null && mounted) {
          _finishSuccess(http);
          return;
        }

        final meta = await DouyinResolveService.resolveKuaishouMeta(input);
        if (meta.isAtlas) {
          setState(() => _statusHint = 'App 内打开快手图文页提取图片…');
          final web = await _extractViaWebView(
            mediaId: meta.photoId,
            platform: ShortVideoPlatform.kuaishou,
            isNote: true,
            pageUrlOverride: meta.finalUrl.isNotEmpty
                ? meta.finalUrl
                : DouyinResolveService.kuaishouPhotoPageUrl(meta.photoId),
          );
          if (!mounted) return;
          _finishSuccess(web);
          return;
        }

        setState(() => _statusHint = 'App 内打开快手页提取直链…');
        final web = await _extractViaWebView(
          mediaId: meta.photoId,
          platform: ShortVideoPlatform.kuaishou,
        );
        if (!mounted) return;
        _finishSuccess(web);
        return;
      }

      // 抖音图文
      if (platform == ShortVideoPlatform.douyin &&
          DouyinResolveService.isDouyinNote(input)) {
        setState(() => _statusHint = 'App 内打开图文页提取图片…');
        final noteId = await DouyinResolveService.resolveNoteId(input);
        final web = await _extractViaWebView(
          mediaId: noteId,
          platform: ShortVideoPlatform.douyin,
          isNote: true,
        );
        if (!mounted) return;
        _finishSuccess(web);
        return;
      }

      // 抖音视频：可选 yt-dlp，再 WebView
      setState(() => _statusHint = '尝试快速解析抖音…');
      final yt = await DouyinResolveService.tryResolveWithYtDlp(input);
      if (yt != null && mounted) {
        _finishSuccess(yt);
        return;
      }

      setState(() => _statusHint = 'App 内打开抖音页提取直链…');
      final awemeId = await DouyinResolveService.resolveAwemeId(input);
      final web = await _extractViaWebView(
        mediaId: awemeId,
        platform: ShortVideoPlatform.douyin,
      );
      if (!mounted) return;
      _finishSuccess(web);
    } catch (e) {
      _log('解析失败: $e');
      if (!mounted) return;
      setState(() => _statusHint = null);
      SmartDialogUtils.showError('解析失败：$e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _finishSuccess(DouyinResolveResult result) {
    _log(
      '解析完成 source=${result.source} id=${result.awemeId} '
      'type=${result.mediaType.name} '
      'images=${result.imageUrls.length} cover=${result.coverUrl != null}',
    );
    final hint = result.isImageNote
        ? '解析成功（${result.source}），共 ${result.imageUrls.length} 张图。直链有时效，请尽快保存。'
        : '解析成功（${result.source}）。直链有时效，请尽快复制或保存。';
    setState(() {
      _result = result;
      _statusHint = hint;
    });
    SmartDialogUtils.showSuccess('解析成功');
  }

  Future<DouyinResolveResult> _extractViaWebView({
    required String mediaId,
    required ShortVideoPlatform platform,
    bool isNote = false,
    String? pageUrlOverride,
  }) async {
    _pollTimer?.cancel();
    final old = _webCompleter;
    if (old != null && !old.isCompleted) {
      old.completeError(Exception('已取消'));
    }
    final completer = Completer<DouyinResolveResult>();
    _webCompleter = completer;
    _pollCount = 0;
    _pendingMediaId = mediaId;
    _pendingPlatform = platform;
    _pendingIsNote = isNote;
    _lastImageCount = 0;
    _imageStablePolls = 0;

    if (platform == ShortVideoPlatform.kuaishou) {
      await _webController.setUserAgent(DouyinResolveService.mobileUserAgent);
    } else {
      await _webController.setUserAgent(DouyinResolveService.userAgent);
    }

    await _injectHook(platform: platform);
    final pageUrl = pageUrlOverride ??
        (isNote
            ? (platform == ShortVideoPlatform.kuaishou
                ? DouyinResolveService.kuaishouPhotoPageUrl(mediaId)
                : DouyinResolveService.notePageUrl(mediaId))
            : platform == ShortVideoPlatform.kuaishou
                ? DouyinResolveService.kuaishouVideoPageUrl(mediaId)
                : DouyinResolveService.videoPageUrl(mediaId));
    await _webController.loadRequest(Uri.parse(pageUrl));
    unawaited(_injectHook(platform: platform));

    _pollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      _tryReadMedia(mediaId: mediaId, platform: platform, isNote: isNote);
    });

    return completer.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () {
        _pollTimer?.cancel();
        throw Exception('提取超时，请稍后重试');
      },
    );
  }

  void _kickPoll() {
    final id = _pendingMediaId;
    final platform = _pendingPlatform;
    if (id == null || platform == null) return;
    _tryReadMedia(
      mediaId: id,
      platform: platform,
      isNote: _pendingIsNote,
    );
  }

  Future<void> _tryReadMedia({
    required String mediaId,
    required ShortVideoPlatform platform,
    bool isNote = false,
  }) async {
    final completer = _webCompleter;
    if (completer == null || completer.isCompleted) return;
    if (_pollCount++ > 55) return;

    await _injectHook(platform: platform);
    try {
      if (isNote) {
        await _webController.runJavaScript(DouyinResolveService.noteNudgeJs);
      }
      final raw = await _webController.runJavaScriptReturningResult(
        DouyinResolveService.readCaptureJs,
      );
      final map = DouyinResolveService.decodeJsJson(raw);
      if (map == null) return;

      var title = (map['title'] as String?)?.trim() ?? '';
      title = title.replaceAll(RegExp(r'\s*-\s*抖音\s*$'), '').trim();
      if (platform == ShortVideoPlatform.kuaishou) {
        title = title.replaceAll(RegExp(r'\s*-\s*快手\s*$'), '').trim();
      }

      if (isNote) {
        var images = _parseImageUrls(map['images']);
        if (images.isEmpty) return;
        if (platform == ShortVideoPlatform.kuaishou) {
          images = DouyinResolveService.sortKuaishouAtlasUrls(images);
        }

        final source = (map['source'] as String?)?.trim() ?? '';
        // detail 接口一般一次给全量；atlas 需等张数稳定，避免首张就收工
        final fromDetail = source.contains('detail');
        if (images.length == _lastImageCount) {
          _imageStablePolls++;
        } else {
          _lastImageCount = images.length;
          _imageStablePolls = 0;
          _log('图文收集中… ${images.length} 张 (source=$source)');
        }

        final stableEnough = _imageStablePolls >= 4 && _pollCount >= 8;
        final forceFinish = _pollCount >= 40 && images.isNotEmpty;
        if (!fromDetail && !stableEnough && !forceFinish) return;

        _pollTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(
            DouyinResolveResult(
              awemeId: mediaId,
              videoUrl: '',
              title: title,
              coverUrl: images.first,
              source: fromDetail ? source : 'webview',
              platform: platform,
              mediaType: DouyinMediaType.images,
              imageUrls: images,
            ),
          );
        }
        return;
      }

      final video = (map['video'] as String?)?.trim() ?? '';
      if (!DouyinResolveService.isDownloadableVideoUrl(video)) return;
      final cover = (map['cover'] as String?)?.trim();

      _pollTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(
          DouyinResolveResult(
            awemeId: mediaId,
            videoUrl: video,
            title: title,
            coverUrl: (cover != null && cover.isNotEmpty) ? cover : null,
            source: 'webview',
            platform: platform,
          ),
        );
      }
    } catch (_) {}
  }

  List<String> _parseImageUrls(Object? raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final keys = <String>{};
    for (final item in raw) {
      final url = '$item'.trim();
      if (!DouyinResolveService.isDownloadableImageUrl(url)) continue;
      final key = url.split('?').first;
      if (keys.contains(key)) continue;
      keys.add(key);
      out.add(url);
    }
    return out;
  }

  Future<void> _openImageViewer(int initialIndex) async {
    final result = _result;
    if (result == null || !result.isImageNote) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ImageViewerDialog(
        urls: result.imageUrls,
        initialIndex: initialIndex,
        referer: DouyinResolveService.refererFor(result.platform),
        fileNameBase: _safeFileBase(result),
      ),
    );
  }

  Future<void> _copyImageUrls() async {
    final urls = _result?.imageUrls;
    if (urls == null || urls.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: urls.join('\n')));
    SmartDialogUtils.showSuccess('已复制 ${urls.length} 条图片直链');
  }

  String _imageExt(String url) => _mediaImageExt(url);

  Future<void> _saveAllImages() async {
    final result = _result;
    if (result == null || !result.isImageNote) return;

    final dir = await getDirectoryPath();
    if (dir == null) return;

    setState(() => _saving = true);
    final base = _safeFileBase(result);
    var ok = 0;
    try {
      for (var i = 0; i < result.imageUrls.length; i++) {
        final url = result.imageUrls[i];
        final ext = _imageExt(url);
        final path =
            '$dir/${base}_${(i + 1).toString().padLeft(2, '0')}.$ext';
        _log('下载图片 ${i + 1}/${result.imageUrls.length} -> $path');
        await DouyinResolveService.downloadWithReferer(
          url: url,
          savePath: path,
        );
        ok++;
      }
      SmartDialogUtils.showSuccess('已保存 $ok 张图片到所选文件夹');
    } catch (e) {
      _log('保存图片失败: $e');
      SmartDialogUtils.showError('保存图片失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPlayer() async {
    final result = _result;
    if (result == null) return;
    if (!DouyinResolveService.isDownloadableVideoUrl(result.videoUrl)) {
      SmartDialogUtils.showWarning('当前直链不可用，请重新解析');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _VideoPlayDialog(
        videoUrl: result.videoUrl,
        referer: DouyinResolveService.refererFor(result.platform),
        saveFileName: '${_safeFileBase(result)}.mp4',
      ),
    );
  }

  Future<void> _copyVideoUrl() async {
    final url = _result?.videoUrl;
    if (url == null || url.isEmpty) return;
    if (!DouyinResolveService.isDownloadableVideoUrl(url)) {
      SmartDialogUtils.showWarning('当前直链不可用，请重新解析');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    SmartDialogUtils.showSuccess('直链已复制（浏览器直接打开可能 403）');
  }

  String _safeFileBase(DouyinResolveResult result) {
    final prefix =
        result.platform == ShortVideoPlatform.kuaishou ? 'kuaishou' : 'douyin';
    var base = result.title.isNotEmpty ? result.title : '${prefix}_${result.awemeId}';
    base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (base.length > 40) base = base.substring(0, 40);
    return base.isEmpty ? '${prefix}_${result.awemeId}' : base;
  }

  Future<void> _saveVideo() async {
    final result = _result;
    if (result == null) return;
    if (!DouyinResolveService.isDownloadableVideoUrl(result.videoUrl)) {
      SmartDialogUtils.showWarning('当前没有可下载的直链，请重新解析');
      return;
    }
    final path = await getSaveLocation(
      suggestedName: '${_safeFileBase(result)}.mp4',
    );
    if (path == null) return;

    setState(() => _saving = true);
    try {
      _log('开始下载视频 -> ${path.path}');
      await DouyinResolveService.downloadWithReferer(
        url: result.videoUrl,
        savePath: path.path,
      );
      await DouyinResolveService.assertValidMp4(path.path);
      final size = await File(path.path).length();
      _log('视频已保存 size=$size');
      SmartDialogUtils.showSuccess(
        '视频已保存（${(size / 1024 / 1024).toStringAsFixed(1)} MB）',
      );
    } catch (e) {
      _log('保存视频失败: $e');
      try {
        final f = File(path.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      SmartDialogUtils.showError('保存视频失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Colors.black.withValues(alpha: 0.42);
    final result = _result;

    return Stack(
      children: [
        // 隐藏 WebView：自行访问抖音 / 快手拿直链，用户无需开浏览器
        Positioned(
          left: -2400,
          top: 0,
          width: 720,
          height: 1280,
          child: IgnorePointer(
            child: WebViewWidget(controller: _webController),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                ),
                const SizedBox(width: 4),
                const Text(
                  '去水印',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _inputController,
                      maxLines: 3,
                      enabled: !_resolving && !_saving,
                      decoration: InputDecoration(
                        hintText: '粘贴抖音 / 快手分享文案或短链（支持图文）',
                        hintStyle: TextStyle(color: muted, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF6F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_resolving || _saving)
                              ? null
                              : _pasteFromClipboard,
                          icon:
                              const Icon(Icons.content_paste_rounded, size: 18),
                          label: const Text('粘贴'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed:
                              (_resolving || _saving) ? null : _resolve,
                          icon: _resolving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.water_drop_outlined, size: 18),
                          label: Text(_resolving ? '解析中' : '解析'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (_statusHint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusHint!,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 16),
                      if (result.isImageNote) ...[
                        Row(
                          children: [
                            Text(
                              '共 ${result.imageUrls.length} 张图片',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _openImageViewer(0),
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('查看全部'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _ImagePreviewStrip(
                          urls: result.imageUrls,
                          referer:
                              DouyinResolveService.refererFor(result.platform),
                          onTap: _openImageViewer,
                        ),
                      ] else ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _PreviewCard(
                            result: result,
                            onPlay: _openPlayer,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (result.title.isNotEmpty)
                        SelectableText(
                          result.title,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (result.isImageNote)
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : _copyImageUrls,
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('复制全部直链'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _saveAllImages,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded,
                                      size: 18),
                              label: Text(_saving ? '保存中' : '保存全部'),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : _copyVideoUrl,
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('复制直链'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _saveVideo,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded,
                                      size: 18),
                              label: Text(_saving ? '保存中' : '保存视频'),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 小封面 + 播放按钮
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.result, required this.onPlay});

  final DouyinResolveResult result;
  final VoidCallback onPlay;

  static const double _width = 132;
  static const double _height = 176;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.black.withValues(alpha: 0.42);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: const Color(0xFF111114),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (result.coverUrl != null)
                  Image.network(
                    result.coverUrl!,
                    fit: BoxFit.cover,
                    headers: {
                      'Referer': DouyinResolveService.refererFor(result.platform),
                      'User-Agent': DouyinResolveService.userAgent,
                    },
                    errorBuilder: (_, __, ___) => _placeholder(muted),
                  )
                else
                  _placeholder(muted),
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Color muted) {
    return ColoredBox(
      color: const Color(0xFF1E1E22),
      child: Icon(Icons.videocam_outlined, color: muted, size: 36),
    );
  }
}

/// 弹窗内播放（无标题，带进度条）
class _VideoPlayDialog extends StatefulWidget {
  const _VideoPlayDialog({
    required this.videoUrl,
    required this.referer,
    required this.saveFileName,
  });

  final String videoUrl;
  final String referer;
  final String saveFileName;

  @override
  State<_VideoPlayDialog> createState() => _VideoPlayDialogState();
}

class _VideoPlayDialogState extends State<_VideoPlayDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'Referer': widget.referer,
          'User-Agent': DouyinResolveService.userAgent,
        },
      );
      _controller = c;
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.initialize();
      if (!mounted || _controller != c) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildScrubber(VideoPlayerController c) {
    final totalMs = c.value.duration.inMilliseconds;
    final maxValue = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final posMs =
        c.value.position.inMilliseconds.toDouble().clamp(0.0, maxValue);
    final value = _dragValue ?? posMs;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor: Colors.white.withValues(alpha: 0.25),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        min: 0,
        max: maxValue,
        value: value.clamp(0.0, maxValue),
        onChanged: totalMs <= 0
            ? null
            : (v) {
                setState(() => _dragValue = v);
              },
        onChangeEnd: totalMs <= 0
            ? null
            : (v) async {
                await c.seekTo(Duration(milliseconds: v.toInt()));
                if (!mounted) return;
                setState(() => _dragValue = null);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final size = c?.value.size;
    final aspect = (size != null && size.width > 0 && size.height > 0)
        ? size.width / size.height
        : 9 / 16;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: '关闭',
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: _error
                            ? const Center(
                                child: Text(
                                  '播放失败',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : !_ready || c == null
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white54,
                                    ),
                                  )
                                : _RightClickSaveArea(
                                    onSave: () => _promptSaveVideo(
                                      context,
                                      url: widget.videoUrl,
                                      suggestedName: widget.saveFileName,
                                    ),
                                    child: GestureDetector(
                                      onTap: _togglePlay,
                                      behavior: HitTestBehavior.opaque,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          VideoPlayer(c),
                                          if (!c.value.isPlaying)
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.45),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 36,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    if (_ready && c != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(
                          children: [
                            Text(
                              _fmtDuration(c.value.position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: _buildScrubber(c)),
                            const SizedBox(width: 8),
                            Text(
                              _fmtDuration(c.value.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主界面紧凑预览：最多 4 格，多余收成「+N」
class _ImagePreviewStrip extends StatelessWidget {
  const _ImagePreviewStrip({
    required this.urls,
    required this.referer,
    required this.onTap,
  });

  final List<String> urls;
  final String referer;
  final void Function(int index) onTap;

  static const int _maxSlots = 4;
  static const double _height = 112;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final overflow = urls.length > _maxSlots;
    final visibleCount = overflow ? _maxSlots : urls.length;
    final moreCount = overflow ? urls.length - (_maxSlots - 1) : 0;

    return SizedBox(
      height: _height,
      child: Row(
        children: [
          for (var i = 0; i < visibleCount; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _thumb(
                index: i,
                url: urls[i],
                // 最后一格叠「+N」，点击仍从该索引打开
                moreLabel: (overflow && i == visibleCount - 1)
                    ? '+$moreCount'
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb({
    required int index,
    required String url,
    String? moreLabel,
  }) {
    return Material(
      color: const Color(0xFF111114),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              headers: {
                'Referer': referer,
                'User-Agent': DouyinResolveService.userAgent,
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white38),
              ),
            ),
            if (moreLabel == null)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              )
            else ...[
              Container(color: Colors.black.withValues(alpha: 0.52)),
              Center(
                child: Text(
                  moreLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 图文大图预览（左右箭头 / 滑动）
class _ImageViewerDialog extends StatefulWidget {
  const _ImageViewerDialog({
    required this.urls,
    required this.initialIndex,
    required this.referer,
    required this.fileNameBase,
  });

  final List<String> urls;
  final int initialIndex;
  final String referer;
  final String fileNameBase;

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _go(int delta) async {
    final next = (_index + delta).clamp(0, widget.urls.length - 1);
    if (next == _index) return;
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white.withValues(alpha: onPressed == null ? 0.3 : 0.95)),
        iconSize: 28,
      ),
    );
  }

  Future<void> _saveCurrentImage() async {
    final url = widget.urls[_index];
    final ext = _mediaImageExt(url);
    final name =
        '${widget.fileNameBase}_${(_index + 1).toString().padLeft(2, '0')}.$ext';
    await _promptSaveImage(context, url: url, suggestedName: name);
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = _index > 0;
    final canNext = _index < widget.urls.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '${_index + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: '关闭',
              ),
            ],
          ),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: _RightClickSaveArea(
                  onSave: _saveCurrentImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: widget.urls.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: Center(
                              child: Image.network(
                                widget.urls[index],
                                fit: BoxFit.contain,
                                headers: {
                                  'Referer': widget.referer,
                                  'User-Agent': DouyinResolveService.userAgent,
                                },
                                errorBuilder: (_, __, ___) => const Text(
                                  '图片加载失败',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.urls.length > 1) ...[
                        Positioned(
                          left: 8,
                          child: _arrowButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: '上一张',
                            onPressed: canPrev ? () => _go(-1) : null,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          child: _arrowButton(
                            icon: Icons.chevron_right_rounded,
                            tooltip: '下一张',
                            onPressed: canNext ? () => _go(1) : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
