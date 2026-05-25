import 'package:flutter/material.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class DrawingCanvas extends StatefulWidget {
  final bool isDrawer;
  final Color activeColor;
  final double activeSize;
  final bool isEraser;
  final List<DrawingPoint?> points;
  final void Function(Offset localPos)? onStrokeStart;
  final void Function(Offset localPos)? onStrokeUpdate;
  final void Function()? onStrokeEnd;

  const DrawingCanvas({
    super.key,
    required this.isDrawer,
    required this.activeColor,
    required this.activeSize,
    required this.isEraser,
    required this.points,
    this.onStrokeStart,
    this.onStrokeUpdate,
    this.onStrokeEnd,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  @override
  Widget build(BuildContext context) {
    final canvasBorder = Border.all(color: const Color(0xFFF05A28).withValues(alpha: 0.3), width: 1.5);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Premium dark canvas back
        borderRadius: BorderRadius.circular(16),
        border: canvasBorder,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: GestureDetector(
          onPanStart: widget.isDrawer
              ? (details) => widget.onStrokeStart?.call(details.localPosition)
              : null,
          onPanUpdate: widget.isDrawer
              ? (details) => widget.onStrokeUpdate?.call(details.localPosition)
              : null,
          onPanEnd: widget.isDrawer
              ? (_) => widget.onStrokeEnd?.call()
              : null,
          child: CustomPaint(
            painter: CanvasPainter(points: widget.points),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  CanvasPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawCircle(
          points[i]!.offset,
          points[i]!.paint.strokeWidth / 2,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
