import 'dart:math';

import 'package:adb_player/dialog/food_roulette_provider.dart';
import 'package:adb_player/dialog/food_roulette_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 吃什么转盘：嵌入 Play 内容区
class FoodRoulettePage extends ConsumerStatefulWidget {
  const FoodRoulettePage({Key? key, this.onClose}) : super(key: key);

  final VoidCallback? onClose;

  @override
  ConsumerState<FoodRoulettePage> createState() => _FoodRoulettePageState();
}

class _FoodRoulettePageState extends ConsumerState<FoodRoulettePage>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFE07A5F);
  static const Color _ink = Color(0xFF2C2C2E);
  static const int _spinExtraTurns = 5;
  static const Duration _spinDuration = Duration(milliseconds: 4000);
  static final Random _random = Random();

  late final AnimationController _wheelController;
  Animation<double>? _wheelAnimation;
  double _baseAngle = 0;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      duration: _spinDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  double get _currentAngle => _wheelAnimation?.value ?? _baseAngle;

  void _start() {
    final state = ref.read(foodRouletteProvider);
    if (state.foods.isEmpty || state.isSpinning) return;
    ref.read(foodRouletteProvider.notifier).startSpinning();

    final totalAngle = _spinExtraTurns * 2 * pi + _random.nextDouble() * 2 * pi;
    final endAngle = _baseAngle + totalAngle;

    setState(() {
      _wheelAnimation = Tween<double>(begin: _baseAngle, end: endAngle).animate(
        CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
      );
    });
    _wheelController.forward(from: 0).whenComplete(() async {
      _baseAngle = endAngle;
      // 转盘停稳后再揭晓，给一点呼吸感
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _commitResultFromAngle(endAngle);
    });
  }

  void _commitResultFromAngle(double endAngle) {
    final foods = ref.read(foodRouletteProvider).foods;
    if (foods.isEmpty) return;
    final n = foods.length;
    final anglePerItem = 2 * pi / n;
    final theta = endAngle % (2 * pi);
    final raw = (3 * pi / 2 - theta) % (2 * pi);
    int idx = (raw / anglePerItem - 0.5).round() % n;
    if (idx < 0) idx += n;
    ref.read(foodRouletteProvider.notifier).revealSpin(idx);
  }

  Future<void> _openCustomDialog() async {
    final current = ref.read(foodRouletteProvider);
    final titleController = TextEditingController(text: current.title);
    final foodsController = TextEditingController(
      text: current.foods.map((f) => f.name).join('\n'),
    );

    void submit() {
      final lines = foodsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final notifier = ref.read(foodRouletteProvider.notifier);
      notifier.setTitle(titleController.text);
      if (lines.isEmpty) {
        SmartDialog.dismiss();
        return;
      }
      final newFoods = [
        for (var i = 0; i < lines.length; i++)
          FoodItem(
            id: i,
            name: lines[i],
            category: '',
            description: '',
            address: '',
          ),
      ];
      notifier.setCustomFoods(newFoods);
      setState(() => _baseAngle = 0);
      SmartDialog.dismiss();
    }

    await SmartDialog.show(
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自定义转盘',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '标题',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: FoodRouletteState.defaultTitle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '选项（一行一个）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: foodsController,
                  maxLines: 10,
                  minLines: 6,
                  decoration: InputDecoration(
                    hintText: '麦当劳\n肯德基\n沙县小吃',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => SmartDialog.dismiss(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleController.dispose();
    foodsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodRouletteProvider);
    final muted = Colors.black.withValues(alpha: 0.42);
    final spinning = state.isSpinning;
    final selected = state.selectedFood;

    return Column(
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
              '吃什么',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: spinning ? null : _openCustomDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('自定义'),
              style: TextButton.styleFrom(
                foregroundColor: muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wheelSize = (min(
                      constraints.maxWidth * 0.72,
                      constraints.maxHeight * 0.62,
                    )).clamp(240.0, 420.0);
                    final bannerWidth = (wheelSize * 0.42).clamp(120.0, 180.0);

                    return Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: wheelSize + 40,
                                height: wheelSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _wheelController,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: _currentAngle,
                                          child: Container(
                                            width: wheelSize,
                                            height: wheelSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _accent.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  blurRadius: 28,
                                                  offset: const Offset(0, 12),
                                                ),
                                                BoxShadow(
                                                  color: Colors.black.withValues(
                                                    alpha: 0.06,
                                                  ),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: CustomPaint(
                                              painter: _RoulettePainter(
                                                foods: state.foods,
                                              ),
                                              size: Size(wheelSize, wheelSize),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: wheelSize / 2 - 14,
                                      child: const _ArrowPointer(),
                                    ),
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: _accent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: bannerWidth,
                                height: 52,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 480),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder:
                                      (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    final fade = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    );
                                    return FadeTransition(
                                      opacity: fade,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.06),
                                          end: Offset.zero,
                                        ).animate(fade),
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.97,
                                            end: 1,
                                          ).animate(fade),
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: selected == null
                                      ? _ResultBanner(
                                          key: const ValueKey('placeholder'),
                                          name: spinning ? '命运转盘中' : '等待开始',
                                          spinning: spinning,
                                          placeholder: true,
                                        )
                                      : _ResultBanner(
                                          key: const ValueKey('result'),
                                          name: selected.name,
                                          spinning: spinning,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: 180,
                                height: 42,
                                child: FilledButton(
                                  onPressed: spinning || state.foods.isEmpty
                                      ? null
                                      : _start,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _accent.withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  child: Text(spinning ? '旋转中' : '开始'),
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
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    Key? key,
    required this.name,
    this.spinning = false,
    this.placeholder = false,
  }) : super(key: key);

  final String name;
  final bool spinning;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final caption = placeholder
        ? (spinning ? '抽取中' : '准备就绪')
        : (spinning ? '重新抽取中…' : '今天就吃');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      opacity: spinning ? 0.5 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE07A5F).withValues(alpha: placeholder ? 0.04 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE07A5F).withValues(
              alpha: spinning ? 0.14 : (placeholder ? 0.12 : 0.28),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Text(
                caption,
                key: ValueKey(caption),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.42),
                  letterSpacing: 1,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
                name,
                key: ValueKey(name),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: placeholder ? 14 : (spinning ? 16 : 18),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE07A5F).withValues(
                    alpha: placeholder ? 0.55 : 1,
                  ),
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowPointer extends StatelessWidget {
  const _ArrowPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(32, 28),
      painter: _ArrowPainter(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, size.height / 2)
      ..lineTo(0, 0)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 3, false);

    final fill = Paint()
      ..color = const Color(0xFFE07A5F)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoulettePainter extends CustomPainter {
  _RoulettePainter({required this.foods});

  final List<FoodItem> foods;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    if (foods.isEmpty) return;

    final anglePerItem = 2 * pi / foods.length;
    final fontSize = (size.width / 28).clamp(10.0, 14.0);

    for (var i = 0; i < foods.length; i++) {
      final startAngle = i * anglePerItem - pi / 2;
      final sweep = anglePerItem;

      final paint = Paint()
        ..color = _colorForIndex(i)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, borderPaint);

      final textAngle = startAngle + anglePerItem / 2;
      final textRadius = radius * 0.68;
      final textX = center.dx + cos(textAngle) * textRadius;
      final textY = center.dy + sin(textAngle) * textRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: foods[i].name,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0.5, 0.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.55);

      textPainter.paint(
        canvas,
        Offset(
          textX - textPainter.width / 2,
          textY - textPainter.height / 2,
        ),
      );
    }

    // 外圈细描边
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFFE07A5F),
      Color(0xFF3D8B7A),
      Color(0xFF5B7CFF),
      Color(0xFFE85D75),
      Color(0xFFC9A45C),
      Color(0xFF2A9D8F),
      Color(0xFF9B6BFF),
      Color(0xFFC23A2B),
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant _RoulettePainter oldDelegate) =>
      oldDelegate.foods != foods;
}
