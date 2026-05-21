import 'dart:math' as math;
import 'package:flutter/material.dart';

class CrtOverlay extends StatelessWidget {
  final Widget child;
  final bool enableGlow;
  final bool enableScanlines;

  const CrtOverlay({
    super.key,
    required this.child,
    this.enableGlow = true,
    this.enableScanlines = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The game screen itself
        child,
        
        // The CRT screen filter overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CrtOverlayPainter(
                enableGlow: enableGlow,
                enableScanlines: enableScanlines,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CrtOverlayPainter extends CustomPainter {
  final bool enableGlow;
  final bool enableScanlines;

  const _CrtOverlayPainter({
    required this.enableGlow,
    required this.enableScanlines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Draw horizontal scanlines
    if (enableScanlines && size.height > 0) {
      final scanlinePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = 1.0;
      
      // Step size of 3 pixels gives a nice retro scanline density
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
      }
    }

    // 2. Draw CRT glass screen curve vignette
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = diagonal / 2;

    final vignetteShader = RadialGradient(
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.05),
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: 0.70),
      ],
      stops: const [0.0, 0.65, 0.88, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final vignettePaint = Paint()..shader = vignetteShader;
    canvas.drawRect(rect, vignettePaint);

    // 3. Draw a subtle glowing cathode ray reflection in the center
    if (enableGlow) {
      final glowShader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
      
      final glowPaint = Paint()..shader = glowShader;
      canvas.drawRect(rect, glowPaint);
    }

    // 4. Draw screen bezel inner shadow/border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CrtOverlayPainter oldDelegate) {
    return oldDelegate.enableGlow != enableGlow || oldDelegate.enableScanlines != enableScanlines;
  }
}
