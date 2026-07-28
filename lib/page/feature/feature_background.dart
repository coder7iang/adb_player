import 'dart:io';
import 'dart:ui';

import 'package:adb_player/common/app.dart';
import 'package:adb_player/page/setting/setting_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// 整窗应用背景（图片 / 视频）
/// 适配：cover / repeat / contain / center
class FeatureBackground extends ConsumerStatefulWidget {
  const FeatureBackground({Key? key}) : super(key: key);

  @override
  ConsumerState<FeatureBackground> createState() => _FeatureBackgroundState();
}

class _FeatureBackgroundState extends ConsumerState<FeatureBackground> {
  String _backgroundPath = '';
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromSettings();
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _syncFromSettings() async {
    var path = ref.read(settingProvider).appBackgroundPath;
    if (path.isEmpty) {
      path = await App().getAppBackgroundPath();
      if (path.isNotEmpty && mounted) {
        ref.read(settingProvider.notifier).setAppBackgroundPath(path);
      }
    }

    final notifier = ref.read(settingProvider.notifier);
    final storedFit = await App().getAppBackgroundFit();
    if (mounted && storedFit != ref.read(settingProvider).appBackgroundFit) {
      notifier.setAppBackgroundFit(storedFit);
    }
    final opacity = await App().getAppBackgroundOpacity();
    if (mounted &&
        opacity != ref.read(settingProvider).appBackgroundOpacity) {
      notifier.setAppBackgroundOpacity(opacity);
    }
    final blur = await App().getAppBackgroundBlur();
    if (mounted && blur != ref.read(settingProvider).appBackgroundBlur) {
      notifier.setAppBackgroundBlur(blur);
    }

    await _applyPath(path);
  }

  Future<void> _applyPath(String backgroundPath) async {
    if (_backgroundPath == backgroundPath) {
      if (backgroundPath.isNotEmpty &&
          _isVideoFile(backgroundPath) &&
          !_isVideoInitialized) {
        await _initializeVideoPlayer(backgroundPath);
      }
      return;
    }

    await _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    if (!mounted) return;
    setState(() => _backgroundPath = backgroundPath);

    if (backgroundPath.isNotEmpty && _isVideoFile(backgroundPath)) {
      await _initializeVideoPlayer(backgroundPath);
    }
  }

  bool _isVideoFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);
  }

  bool _isImageFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    try {
      _videoController = VideoPlayerController.file(File(videoPath));
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() => _isVideoInitialized = true);
      _videoController!.setLooping(true);
      await _videoController!.play();
    } catch (e) {
      debugPrint('视频播放器初始化失败: $e');
      if (mounted) {
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fitMode =
        ref.watch(settingProvider.select((s) => s.appBackgroundFit));
    final opacity =
        ref.watch(settingProvider.select((s) => s.appBackgroundOpacity));
    final blur =
        ref.watch(settingProvider.select((s) => s.appBackgroundBlur));

    ref.listen<String>(
      settingProvider.select((s) => s.appBackgroundPath),
      (prev, next) {
        if (prev != next) {
          _applyPath(next);
        }
      },
    );

    if (_backgroundPath.isEmpty) {
      return const ColoredBox(color: Colors.white);
    }

    final file = File(_backgroundPath);
    if (!file.existsSync()) {
      return const ColoredBox(color: Colors.white);
    }

    final Widget media;
    if (_isVideoFile(_backgroundPath)) {
      final videoFit = fitMode == 'repeat' ? 'cover' : fitMode;
      media = _buildVideoMedia(videoFit);
    } else if (_isImageFile(_backgroundPath)) {
      media = _buildImageMedia(file, fitMode);
    } else {
      return const ColoredBox(color: Colors.white);
    }

    final blurred = blur > 0.5
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.clamp,
            ),
            child: media,
          )
        : media;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          blurred,
          if (opacity > 0)
            ColoredBox(color: Colors.white.withValues(alpha: opacity)),
        ],
      ),
    );
  }

  Widget _buildVideoMedia(String fitMode) {
    final boxFit = switch (fitMode) {
      'contain' => BoxFit.contain,
      'center' => BoxFit.none,
      _ => BoxFit.cover,
    };

    if (!_isVideoInitialized || _videoController == null) {
      return const SizedBox.expand();
    }

    return FittedBox(
      fit: boxFit,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _videoController!.value.size.width,
        height: _videoController!.value.size.height,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildImageMedia(File file, String fitMode) {
    if (fitMode == 'repeat') {
      return SizedBox.expand(
        child: Image.file(
          file,
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          fit: BoxFit.none,
        ),
      );
    }

    return Image.file(
      file,
      fit: switch (fitMode) {
        'contain' => BoxFit.contain,
        'center' => BoxFit.none,
        _ => BoxFit.cover,
      },
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
