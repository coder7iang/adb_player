import 'dart:io';
import 'dart:ui';

import 'package:adb_player/common/app.dart';
import 'package:adb_player/page/setting/setting_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// 整窗应用背景（图片 / 视频）
/// 适配：cover / repeat / contain / center / bottom_right
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
    final cornerWidth = await App().getAppBackgroundCornerWidth();
    if (mounted &&
        cornerWidth != ref.read(settingProvider).appBackgroundCornerWidth) {
      notifier.setAppBackgroundCornerWidth(cornerWidth);
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
    final cornerWidth =
        ref.watch(settingProvider.select((s) => s.appBackgroundCornerWidth));

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

    final isCorner = fitMode == 'bottom_right';

    final Widget media;
    if (_isVideoFile(_backgroundPath)) {
      if (isCorner) {
        media = _buildCornerVideo(cornerWidth, opacity, blur);
      } else {
        final videoFit = fitMode == 'repeat' ? 'cover' : fitMode;
        media = _buildVideoMedia(videoFit);
      }
    } else if (_isImageFile(_backgroundPath)) {
      if (isCorner) {
        media = _buildCornerImage(file, cornerWidth, opacity, blur);
      } else {
        media = _buildImageMedia(file, fitMode);
      }
    } else {
      return const ColoredBox(color: Colors.white);
    }

    final blurred = !isCorner && blur > 0.5
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
          if (!isCorner && opacity > 0)
            ColoredBox(color: Colors.white.withValues(alpha: opacity)),
        ],
      ),
    );
  }

  Widget _buildCornerImage(
    File file,
    double cornerWidth,
    double opacity,
    double blur,
  ) {
    Widget content = Image.file(
      file,
      width: cornerWidth,
      fit: BoxFit.fitWidth,
      alignment: Alignment.bottomRight,
      filterQuality: FilterQuality.medium,
    );

    content = _embedSoftEdges(
      child: content,
      feather: (cornerWidth * 0.28).clamp(36.0, 96.0),
    );

    if (blur > 0.5) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur * 0.35,
          sigmaY: blur * 0.35,
          tileMode: TileMode.decal,
        ),
        child: content,
      );
    }

    if (opacity > 0) {
      content = Opacity(
        opacity: (1.0 - opacity).clamp(0.0, 1.0),
        child: content,
      );
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: content,
    );
  }

  Widget _buildCornerVideo(
    double cornerWidth,
    double opacity,
    double blur,
  ) {
    if (!_isVideoInitialized || _videoController == null) {
      return const SizedBox.shrink();
    }
    final size = _videoController!.value.size;
    final h =
        size.width > 0 ? cornerWidth * size.height / size.width : cornerWidth;

    Widget content = SizedBox(
      width: cornerWidth,
      height: h,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );

    content = _embedSoftEdges(
      child: content,
      feather: (cornerWidth * 0.28).clamp(36.0, 96.0),
    );

    if (blur > 0.5) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur * 0.35,
          sigmaY: blur * 0.35,
          tileMode: TileMode.decal,
        ),
        child: content,
      );
    }

    if (opacity > 0) {
      content = Opacity(
        opacity: (1.0 - opacity).clamp(0.0, 1.0),
        child: content,
      );
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: content,
    );
  }

  /// 边缘羽化：贴窗的右/下侧弱淡，朝向界面的左/上侧强淡，消除硬棱角
  Widget _embedSoftEdges({
    required Widget child,
    required double feather,
  }) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fx = (feather / bounds.width).clamp(0.08, 0.45);
        // 右侧、底部几乎贴边，只留很弱的淡出；左侧、顶部大幅溶入白底
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0xCC000000),
          ],
          stops: [0.0, fx, 1.0 - fx * 0.25, 1.0],
        ).createShader(bounds);
      },
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final fy = (feather / bounds.height).clamp(0.08, 0.45);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0xCC000000),
            ],
            stops: [0.0, fy, 1.0 - fy * 0.25, 1.0],
          ).createShader(bounds);
        },
        child: child,
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
