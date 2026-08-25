import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 滑动变祖器：31 级梁系强度校准器（嵌入 Play 内容区，不全屏）
class LiangCalibratorPage extends StatefulWidget {
  const LiangCalibratorPage({Key? key, this.onClose}) : super(key: key);

  final VoidCallback? onClose;

  @override
  State<LiangCalibratorPage> createState() => _LiangCalibratorPageState();
}

class _LiangCalibratorPageState extends State<LiangCalibratorPage> {
  static const int _minLevel = 0;
  static const int _maxLevel = 30;
  static const int _stagesPerBucket = 6;
  static const List<String> _stages = [
    '小难梁',
    '牢梁',
    '梁子',
    '梁圣',
    '梁神',
    '梁祖',
  ];

  /// DeepSeek API 价位（元 / 百万 tokens）
  /// https://api-docs.deepseek.com/zh-cn/quick_start/pricing
  /// deepseek-v4-flash / deepseek-v4-pro · 缓存未命中
  static const double _flashInputIdle = 1.5;
  static const double _flashInputPeak = 3.0;
  static const double _flashOutputIdle = 4.5;
  static const double _flashOutputPeak = 9.0;
  static const double _proInputIdle = 4.5;
  static const double _proInputPeak = 9.0;
  static const double _proOutputIdle = 13.5;
  static const double _proOutputPeak = 27.0;

  static const Color _paper = Color(0xFFEFE4CF);
  static const Color _inkLight = Color(0xFF2C2218);
  static const Color _mutedLight = Color(0xFF8A7A64);
  static const Color _accentRed = Color(0xFFC23A2B);
  static const Color _gold = Color(0xFFC9A45C);
  static const Color _inkDark = Color(0xFFF6EDD8);
  static const Color _mutedDark = Color(0xFFCBBCA0);

  int _level = _minLevel;
  bool _loaded = false;
  bool _loadError = false;
  late final _DeepSeekPriceInfo _priceInfo;
  final FocusNode _focusNode = FocusNode();

  _LevelState get _state => _describeLevel(_level);

  double get _strength => _state.strength;

  bool get _isLateStage => _state.stageIndex >= 4;

  bool get _isFinal => _state.stageIndex == 5;

  Color get _ink => _isLateStage ? _inkDark : _inkLight;

  Color get _muted => _isLateStage ? _mutedDark : _mutedLight;

  Color get _accent => _isFinal ? const Color(0xFFD4B36A) : _accentRed;

  Color get _thumbBg =>
      _isLateStage ? const Color(0xFF1C140F) : const Color(0xFFF7EFE0);

  @override
  void initState() {
    super.initState();
    _priceInfo = _DeepSeekPriceInfo.now();
    _level = _priceInfo.level;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _precacheFrames();
      // 从 0 动画滑到价位对应等级
      _level = _minLevel;
      setState(() {});
      _animateToLevel(_priceInfo.level);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _animateToLevel(int target) async {
    final start = _level;
    if (start == target) {
      _setLevel(target);
      return;
    }
    const steps = 18;
    for (var i = 1; i <= steps; i++) {
      if (!mounted) return;
      final next = start + ((target - start) * i / steps).round();
      setState(() => _level = next.clamp(_minLevel, _maxLevel));
      await Future.delayed(const Duration(milliseconds: 28));
    }
    if (!mounted) return;
    _setLevel(target);
  }

  Future<void> _precacheFrames() async {
    try {
      final futures = <Future<void>>[];
      for (var i = _minLevel; i <= _maxLevel; i++) {
        futures.add(precacheImage(AssetImage(_frameAsset(i)), context));
      }
      await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadError = true;
      });
    }
  }

  void _setLevel(int raw) {
    final next = raw.clamp(_minLevel, _maxLevel);
    if (next == _level) return;
    setState(() => _level = next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _setLevel(_level + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _setLevel(_level - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _setLevel(_minLevel);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _setLevel(_maxLevel);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _state;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      autofocus: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 480),
        curve: Curves.ease,
        decoration: BoxDecoration(
          color: Color.lerp(
            _paper,
            const Color(0xFF0B0806),
            (_strength * 0.96).clamp(0.0, 1.0),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: (0.55 - _strength * 0.2).clamp(0.0, 1.0),
                  child: CustomPaint(painter: _GrainPainter(color: _ink)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.arrow_back,
                          color: _ink.withValues(alpha: 0.75),
                          size: 20,
                        ),
                        onPressed: widget.onClose,
                      ),
                      Text(
                        '滑动变祖器',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          fontFamily: 'Songti SC',
                        ),
                      ),
                      const Spacer(),
                      _buildPriceBadge(),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 与右侧强度表同宽，保证人像水平居中
                        const SizedBox(width: 56),
                        Expanded(child: _buildPortraitZone(stage)),
                        _buildLevelMeter(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildControlPanel(stage),
                  const SizedBox(height: 6),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelMeter() {
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          ..._verticalChars('梁系强度',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                height: 1.25,
                fontFamily: 'Songti SC',
              )),
          const Spacer(),
          Text(
            _pad2(_level),
            style: TextStyle(
              color: _accent,
              fontSize: 22,
              letterSpacing: 1,
              fontFamily: 'Songti SC',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '/ ${_pad2(_maxLevel)}',
            style: TextStyle(
              color: _accent.withValues(alpha: 0.75),
              fontSize: 12,
              fontFamily: 'Songti SC',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _verticalChars(String text, {required TextStyle style}) {
    return [
      for (final ch in text.split(''))
        Text(ch, style: style),
    ];
  }

  Widget _buildPortraitZone(_LevelState stage) {
    return Stack(
      alignment: Alignment.center,
      children: [
            Opacity(
          opacity: 0.05 + _strength * 0.04,
          child: Text(
            '梁',
            style: TextStyle(
              color: _ink,
              fontSize: 220,
              fontWeight: FontWeight.w700,
              height: 0.8,
              fontFamily: 'Kaiti SC',
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isFinal)
                          Transform.rotate(
                            angle: _strength * 0.42,
                            child: Container(
                              width: side * 1.2,
                              height: side * 1.2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.5),
                                ),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.transparent,
                                    _gold.withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.56, 0.57, 0.58],
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9C9A8),
                            border: Border.all(
                              color: Color.lerp(
                                    _accent, const Color(0xFF6B4A22), 0.45)!,
                              width: 6,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_loaded && !_loadError)
                                Image.asset(
                                  _frameAsset(_level),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.high,
                                )
                              else
                                Container(
                                  color: const Color(0xFF1C120C)
                                      .withValues(alpha: 0.88),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _loadError
                                        ? '连续画面加载失败'
                                        : '载入连续祖力…',
                                    style: TextStyle(
                                      color: _loadError
                                          ? const Color(0xFFFFF1EF)
                                          : _inkDark,
                                      fontSize: 13,
                                      letterSpacing: 3,
                                      fontFamily: 'Songti SC',
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    margin: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _ink.withValues(alpha: 0.28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 360,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '当前状态',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontFamily: 'Songti SC',
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isFinal ? const Color(0xFFE4C57A) : _accent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      stage.stage,
                      style: TextStyle(
                        color: _isFinal ? const Color(0xFFE4C57A) : _accent,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        height: 1,
                        fontFamily: 'Kaiti SC',
                        shadows: _isFinal
                            ? [
                                Shadow(
                                  color: _gold.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '阶段 ${_pad2(stage.stageIndex + 1)} / 06',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontFamily: 'Songti SC',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlPanel(_LevelState stage) {
    const railInset = 18.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - railInset * 2;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: railInset,
                      right: railInset,
                      child: Container(
                        height: 3,
                        color: _ink.withValues(alpha: 0.18),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _strength,
                          child: Container(height: 3, color: _accent),
                        ),
                      ),
                    ),
                    Positioned(
                      left: railInset,
                      right: railInset,
                      top: 10,
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_maxLevel - _minLevel + 1, (i) {
                          final active = i <= _level;
                          final major = i % _stagesPerBucket == 0;
                          return Container(
                            width: 1,
                            height: active
                                ? (major ? 24.0 : 12.0)
                                : (major ? 18.0 : 8.0),
                            color: active
                                ? _accent.withValues(alpha: 0.95)
                                : _ink.withValues(
                                    alpha: major ? 0.5 : 0.22,
                                  ),
                          );
                        }),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: _DiamondThumb(
                          color: _accent,
                          ring: _thumbBg,
                        ),
                      ),
                      child: Slider(
                        min: _minLevel.toDouble(),
                        max: _maxLevel.toDouble(),
                        divisions: _maxLevel - _minLevel,
                        value: _level.toDouble(),
                        onChanged: (v) => _setLevel(v.round()),
                      ),
                    ),
                    // 占位保证轨道宽度计算稳定
                    SizedBox(width: trackWidth),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: railInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_stages.length, (index) {
                final markerLevel =
                    index == _stages.length - 1 ? _maxLevel : index * _stagesPerBucket;
                final isCurrent = index == stage.stageIndex;
                final isPassed = index < stage.stageIndex;
                return GestureDetector(
                  onTap: () => _setLevel(markerLevel),
                  child: Text(
                    _stages[index],
                    style: TextStyle(
                      color: isCurrent
                          ? _accent
                          : isPassed
                              ? Color.lerp(_accent, _muted, 0.25)
                              : _muted,
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 1.5,
                      fontFamily: 'Songti SC',
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '←  拖动以增强梁系浓度  →',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 3,
              fontFamily: 'Songti SC',
            ),
          ),
        ],
      ),
    );
  }

  /// 右上角：紧凑对照表，一眼看完 Flash / Pro × 空闲 / 高峰
  Widget _buildPriceBadge() {
    final info = _priceInfo;
    final active = info.isPeak
        ? const Color(0xFFE85D4C)
        : const Color(0xFF2A9D8F);
    final muted = _muted;
    TextStyle cell({bool hi = false, bool head = false}) => TextStyle(
          color: hi ? active : muted,
          fontSize: head ? 10 : 11,
          height: 1.25,
          letterSpacing: 0.2,
          fontFamily: 'Songti SC',
          fontWeight: hi || head ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    Widget col(String a, String b, String c, {bool hi = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(a, style: cell(head: true, hi: hi)),
          Text(b, style: cell(hi: hi)),
          Text(c, style: cell(hi: hi)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DeepSeek  ¥/MTok · ${info.periodLabel}',
            style: TextStyle(
              color: active,
              fontSize: 11,
              letterSpacing: 0.6,
              fontFamily: 'Songti SC',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(' ', style: cell(head: true)), // 对齐表头行高
                  Text('Flash', style: cell()),
                  Text('Pro', style: cell()),
                ],
              ),
              const SizedBox(width: 10),
              col('空闲', info.flashIdle, info.proIdle, hi: !info.isPeak),
              const SizedBox(width: 10),
              col('高峰', info.flashPeak, info.proPeak, hi: info.isPeak),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _ink.withValues(alpha: 0.16)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '31 级连续进化',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontFamily: 'Songti SC',
                ),
              ),
              Text(
                'DeepSeek Flash / Pro · ${_priceInfo.periodLabel}价',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontFamily: 'Songti SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _frameAsset(int level) {
    final n = level.clamp(_minLevel, _maxLevel).toString().padLeft(2, '0');
    return 'assets/liang/frames/frame-$n.webp';
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static _LevelState _describeLevel(int raw) {
    final level = raw.clamp(_minLevel, _maxLevel);
    final stageIndex =
        (level ~/ _stagesPerBucket).clamp(0, _stages.length - 1);
    final isFinal = stageIndex == _stages.length - 1;
    final stageProgress = isFinal
        ? 1.0
        : (level - stageIndex * _stagesPerBucket) / _stagesPerBucket;
    return _LevelState(
      level: level,
      stage: _stages[stageIndex],
      stageIndex: stageIndex,
      strength: level / _maxLevel,
      stageProgress: stageProgress,
    );
  }
}

class _LevelState {
  const _LevelState({
    required this.level,
    required this.stage,
    required this.stageIndex,
    required this.strength,
    required this.stageProgress,
  });

  final int level;
  final String stage;
  final int stageIndex;
  final double strength;
  final double stageProgress;
}


/// DeepSeek 当前时段价位 → 梁系等级
/// 价目：https://api-docs.deepseek.com/zh-cn/quick_start/pricing
class _DeepSeekPriceInfo {
  const _DeepSeekPriceInfo({
    required this.isPeak,
    required this.level,
  });

  final bool isPeak;
  final int level;

  String get periodLabel => isPeak ? '高峰' : '空闲';

  static String _pair(double input, double output) =>
      '${input.toStringAsFixed(1)}/${output.toStringAsFixed(1)}';

  String get flashIdle => _pair(
        _LiangCalibratorPageState._flashInputIdle,
        _LiangCalibratorPageState._flashOutputIdle,
      );

  String get flashPeak => _pair(
        _LiangCalibratorPageState._flashInputPeak,
        _LiangCalibratorPageState._flashOutputPeak,
      );

  String get proIdle => _pair(
        _LiangCalibratorPageState._proInputIdle,
        _LiangCalibratorPageState._proOutputIdle,
      );

  String get proPeak => _pair(
        _LiangCalibratorPageState._proInputPeak,
        _LiangCalibratorPageState._proOutputPeak,
      );

  factory _DeepSeekPriceInfo.now() {
    final beijing = DateTime.now().toUtc().add(const Duration(hours: 8));
    final peak = _isPeakBeijing(beijing);
    final flashIn = peak
        ? _LiangCalibratorPageState._flashInputPeak
        : _LiangCalibratorPageState._flashInputIdle;
    // 以 Flash 输入价映射等级：价越低性价比越高 → 1.5→26，3.0→18
    final level = (30 - flashIn * 4)
        .round()
        .clamp(_LiangCalibratorPageState._minLevel,
            _LiangCalibratorPageState._maxLevel);
    return _DeepSeekPriceInfo(isPeak: peak, level: level);
  }

  /// 北京时间周一至周五 09:00–12:00、14:00–18:00 为高峰
  static bool _isPeakBeijing(DateTime beijing) {
    if (beijing.weekday > DateTime.friday) return false;
    final m = beijing.hour * 60 + beijing.minute;
    return (m >= 9 * 60 && m < 12 * 60) || (m >= 14 * 60 && m < 18 * 60);
  }
}

class _DiamondThumb extends SliderComponentShape {
  const _DiamondThumb({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.785398); // 45°
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -15, 30, 30),
        const Radius.circular(2),
      ),
      Paint()..color = ring,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -11, 22, 22),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.05);
    const step = 12.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
