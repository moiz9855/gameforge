import 'dart:math';
import 'package:flutter/material.dart';
import 'package:game_forge/core/constants/app_colors.dart';

class LudoDice extends StatefulWidget {
  final int? value;
  final bool canRoll;
  final VoidCallback onRoll;

  const LudoDice({
    super.key,
    required this.value,
    required this.canRoll,
    required this.onRoll,
  });

  @override
  State<LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<LudoDice>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotate;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _rotate = Tween<double>(begin: 0, end: 2 * pi).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1), weight: 60),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _roll() {
    if (!widget.canRoll) return;
    _ctrl.forward(from: 0);
    widget.onRoll();
  }

  static const _pips = {
    1: [(0.5, 0.5)],
    2: [(0.25, 0.25), (0.75, 0.75)],
    3: [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
    4: [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)],
    5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
    6: [
      (0.25, 0.2),
      (0.75, 0.2),
      (0.25, 0.5),
      (0.75, 0.5),
      (0.25, 0.8),
      (0.75, 0.8)
    ],
  };

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.canRoll ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: _roll,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.rotate(
          angle: _rotate.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: widget.canRoll ? AppColors.fireGradient : null,
                color: widget.canRoll ? null : AppColors.card2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: widget.canRoll ? 0 : 0.45),
                  width: widget.canRoll ? 0 : 1,
                ),
                boxShadow: widget.canRoll
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: widget.value == null
                  ? Icon(Icons.casino_rounded,
                      color: widget.canRoll ? Colors.white : accent, size: 36)
                  : CustomPaint(
                      painter: _PipsPainter(
                        pips: _pips[widget.value] ?? [],
                        color:
                            widget.canRoll ? Colors.white : AppColors.muted,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PipsPainter extends CustomPainter {
  final List<(double, double)> pips;
  final Color color;
  const _PipsPainter({required this.pips, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const pipR = 5.0;
    for (final (rx, ry) in pips) {
      canvas.drawCircle(Offset(rx * size.width, ry * size.height), pipR, paint);
      canvas.drawCircle(
        Offset(rx * size.width, ry * size.height),
        pipR,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_PipsPainter old) => old.pips != pips || old.color != color;
}
