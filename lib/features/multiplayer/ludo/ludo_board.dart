import 'package:flutter/material.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'ludo_logic.dart';

Color _playerColor(int idx) => Color(kPlayerColors[idx]);

// ─── Coordinate Rotation Helpers ──────────────────────────────────────────────

(int, int) _logicalToVisual(int lr, int lc, int myPlayerIdx) {
  int vr = lr;
  int vc = lc;
  final rot = (myPlayerIdx - 3) % 4;
  for (int i = 0; i < rot; i++) {
    final prevV = vr;
    vr = 14 - vc;
    vc = prevV;
  }
  return (vr, vc);
}

(double, double) _logicalToVisualDouble(double lr, double lc, int myPlayerIdx) {
  double vr = lr;
  double vc = lc;
  final rot = (myPlayerIdx - 3) % 4;
  for (int i = 0; i < rot; i++) {
    final prevV = vr;
    vr = 14.0 - vc;
    vc = prevV;
  }
  return (vr, vc);
}

(int, int) _visualToLogical(int vr, int vc, int myPlayerIdx) {
  int lr = vr;
  int lc = vc;
  final rot = (myPlayerIdx - 3) % 4;
  for (int i = 0; i < rot; i++) {
    final prevL = lr;
    lr = lc;
    lc = 14 - prevL;
  }
  return (lr, lc);
}

// ─── Board Widget ─────────────────────────────────────────────────────────────

class LudoBoard extends StatelessWidget {
  final LudoState state;
  final int myPlayerIdx;
  final void Function(int playerIdx, int tokenIdx) onTokenTap;
  final List<int> movableTokenIndices;

  const LudoBoard({
    super.key,
    required this.state,
    required this.myPlayerIdx,
    required this.onTokenTap,
    required this.movableTokenIndices,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          final cell = size / 15;
          return Stack(
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _LudoBoardPainter(
                  numPlayers: state.numPlayers,
                  myPlayerIdx: myPlayerIdx,
                ),
              ),
              for (int pi = 0; pi < state.numPlayers; pi++)
                for (int ti = 0; ti < 4; ti++)
                  _buildToken(state.tokens[pi][ti], pi, ti, cell),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToken(LudoToken token, int pi, int ti, double cell) {
    final pos = token.gridPos;
    if (pos == null) {
      return _BaseToken(
        playerIdx: pi,
        tokenIdx: ti,
        cell: cell,
        myPlayerIdx: myPlayerIdx,
        isMovable: pi == myPlayerIdx && movableTokenIndices.contains(ti),
        onTap: () => onTokenTap(pi, ti),
      );
    }

    final (lr, lc) = pos;
    final (r, c) = _logicalToVisual(lr, lc, myPlayerIdx);
    final isMovable = pi == myPlayerIdx && movableTokenIndices.contains(ti);

    return Positioned(
      left: c * cell + cell * 0.1,
      top: r * cell + cell * 0.1,
      child: GestureDetector(
        onTap: isMovable ? () => onTokenTap(pi, ti) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: cell * 0.8,
          height: cell * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _playerColor(pi),
            border: Border.all(
              color: isMovable ? Colors.white : Colors.black.withValues(alpha: 0.35),
              width: isMovable ? 2.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _playerColor(pi).withValues(alpha: isMovable ? 0.95 : 0.45),
                blurRadius: isMovable ? 14 : 5,
                spreadRadius: isMovable ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${ti + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: cell * 0.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BaseToken extends StatelessWidget {
  final int playerIdx;
  final int tokenIdx;
  final double cell;
  final int myPlayerIdx;
  final bool isMovable;
  final VoidCallback onTap;

  const _BaseToken({
    required this.playerIdx,
    required this.tokenIdx,
    required this.cell,
    required this.myPlayerIdx,
    required this.isMovable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const List<(double, double)> quadrantOrigins = [
      (0, 0),
      (0, 9),
      (9, 9),
      (9, 0),
    ];

    const List<(double, double)> innerOffsets = [
      (1.3, 1.3),
      (1.3, 3.3),
      (3.3, 1.3),
      (3.3, 3.3),
    ];

    final (qr, qc) = quadrantOrigins[playerIdx];
    final (ir, ic) = innerOffsets[tokenIdx];
    final (vr, vc) = _logicalToVisualDouble(qr + ir, qc + ic, myPlayerIdx);

    return Positioned(
      left: vc * cell,
      top: vr * cell,
      child: GestureDetector(
        onTap: isMovable ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cell * 0.85,
          height: cell * 0.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _playerColor(playerIdx),
            border: Border.all(
              color: isMovable ? Colors.white : Colors.black.withValues(alpha: 0.32),
              width: isMovable ? 2.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _playerColor(playerIdx).withValues(alpha: isMovable ? 0.95 : 0.35),
                blurRadius: isMovable ? 16 : 4,
                spreadRadius: isMovable ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${tokenIdx + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: cell * 0.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoBoardPainter extends CustomPainter {
  final int numPlayers;
  final int myPlayerIdx;
  const _LudoBoardPainter({required this.numPlayers, required this.myPlayerIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        final (lr, lc) = _visualToLogical(r, c, myPlayerIdx);
        final color = _cellColor(lr, lc);
        if (color == null) continue;
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.border.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    _drawPathOutline(canvas, cell);
    _drawHomeCenter(canvas, cell);

    for (final idx in kSafeIndices) {
      final (lr, lc) = kMainPath[idx];
      final (vr, vc) = _logicalToVisual(lr, lc, myPlayerIdx);
      _drawStar(canvas, vr, vc, cell);
    }
  }

  Color? _cellColor(int r, int c) {
    if (r < 6 && c < 6) return _playerColor(0).withValues(alpha: 0.16);
    if (r < 6 && c > 8) return _playerColor(1).withValues(alpha: 0.16);
    if (r > 8 && c > 8) return _playerColor(2).withValues(alpha: 0.16);
    if (r > 8 && c < 6) return _playerColor(3).withValues(alpha: 0.16);

    if (r >= 1 && r <= 4 && c >= 1 && c <= 4) return _playerColor(0).withValues(alpha: 0.38);
    if (r >= 1 && r <= 4 && c >= 10 && c <= 13) {
      return _playerColor(1).withValues(alpha: 0.38);
    }
    if (r >= 10 && r <= 13 && c >= 10 && c <= 13) {
      return _playerColor(2).withValues(alpha: 0.38);
    }
    if (r >= 10 && r <= 13 && c >= 1 && c <= 4) {
      return _playerColor(3).withValues(alpha: 0.38);
    }

    final isPath = _isPathCell(r, c);
    if (!isPath) return AppColors.background;

    for (int pi = 0; pi < 4; pi++) {
      for (final (hr, hc) in kHomeTracks[pi]) {
        if (hr == r && hc == c) return _playerColor(pi).withValues(alpha: 0.33);
      }
    }

    for (final idx in kSafeIndices) {
      final (pr, pc) = kMainPath[idx];
      if (pr == r && pc == c) return AppColors.primary.withValues(alpha: 0.42);
    }

    return AppColors.card2;
  }

  bool _isPathCell(int r, int c) {
    if (r >= 6 && r <= 8) return true;
    if (c >= 6 && c <= 8) return true;
    return false;
  }

  void _drawPathOutline(Canvas canvas, double cell) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(6 * cell, 0, 3 * cell, 15 * cell),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 6 * cell, 15 * cell, 3 * cell),
      paint,
    );
  }

  void _drawHomeCenter(Canvas canvas, double cell) {
    final cx = 7.5 * cell;
    final cy = 7.5 * cell;

    final corners = [
      Offset(6 * cell, 6 * cell),
      Offset(9 * cell, 6 * cell),
      Offset(9 * cell, 9 * cell),
      Offset(6 * cell, 9 * cell),
    ];
    final next = [
      Offset(9 * cell, 6 * cell),
      Offset(9 * cell, 9 * cell),
      Offset(6 * cell, 9 * cell),
      Offset(6 * cell, 6 * cell),
    ];

    final rot = (myPlayerIdx - 3) % 4;

    for (int i = 0; i < 4; i++) {
      final path = Path()
        ..moveTo(corners[i].dx, corners[i].dy)
        ..lineTo(next[i].dx, next[i].dy)
        ..lineTo(cx, cy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = _playerColor((i + rot) % 4).withValues(alpha: 0.62),
      );
    }
  }

  void _drawStar(Canvas canvas, int r, int c, double cell) {
    final cx = (c + 0.5) * cell;
    final cy = (r + 0.5) * cell;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '★',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.primary.withValues(alpha: 0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - 5, cy - 5));
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) => false;
}
