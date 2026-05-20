import 'package:flutter/material.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'ludo_logic.dart';

Color _playerColor(int idx) => Color(kPlayerColors[idx]);

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
                painter: _LudoBoardPainter(numPlayers: state.numPlayers),
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
        isMovable: pi == myPlayerIdx && movableTokenIndices.contains(ti),
        onTap: () => onTokenTap(pi, ti),
      );
    }

    final (r, c) = pos;
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
              color: isMovable ? Colors.white : Colors.black.withOpacity(0.35),
              width: isMovable ? 2.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _playerColor(pi).withOpacity(isMovable ? 0.95 : 0.45),
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
  final bool isMovable;
  final VoidCallback onTap;

  const _BaseToken({
    required this.playerIdx,
    required this.tokenIdx,
    required this.cell,
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

    return Positioned(
      left: (qc + ic) * cell,
      top: (qr + ir) * cell,
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
              color: isMovable ? Colors.white : Colors.black.withOpacity(0.32),
              width: isMovable ? 2.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _playerColor(playerIdx).withOpacity(isMovable ? 0.95 : 0.35),
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
  const _LudoBoardPainter({required this.numPlayers});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        final color = _cellColor(r, c);
        if (color == null) continue;
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.border.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    _drawPathOutline(canvas, cell);
    _drawHomeCenter(canvas, cell);

    for (final idx in kSafeIndices) {
      final (r, c) = kMainPath[idx];
      _drawStar(canvas, r, c, cell);
    }
  }

  Color? _cellColor(int r, int c) {
    if (r < 6 && c < 6) return _playerColor(0).withOpacity(0.16);
    if (r < 6 && c > 8) return _playerColor(1).withOpacity(0.16);
    if (r > 8 && c > 8) return _playerColor(2).withOpacity(0.16);
    if (r > 8 && c < 6) return _playerColor(3).withOpacity(0.16);

    if (r >= 1 && r <= 4 && c >= 1 && c <= 4) return _playerColor(0).withOpacity(0.38);
    if (r >= 1 && r <= 4 && c >= 10 && c <= 13) {
      return _playerColor(1).withOpacity(0.38);
    }
    if (r >= 10 && r <= 13 && c >= 10 && c <= 13) {
      return _playerColor(2).withOpacity(0.38);
    }
    if (r >= 10 && r <= 13 && c >= 1 && c <= 4) {
      return _playerColor(3).withOpacity(0.38);
    }

    final isPath = _isPathCell(r, c);
    if (!isPath) return AppColors.background;

    for (int pi = 0; pi < 4; pi++) {
      for (final (hr, hc) in kHomeTracks[pi]) {
        if (hr == r && hc == c) return _playerColor(pi).withOpacity(0.33);
      }
    }

    for (final idx in kSafeIndices) {
      final (pr, pc) = kMainPath[idx];
      if (pr == r && pc == c) return AppColors.primary.withOpacity(0.42);
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
      ..color = AppColors.primary.withOpacity(0.14)
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

    for (int i = 0; i < 4; i++) {
      final path = Path()
        ..moveTo(corners[i].dx, corners[i].dy)
        ..lineTo(next[i].dx, next[i].dy)
        ..lineTo(cx, cy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = _playerColor(i).withOpacity(0.62),
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
          color: AppColors.primary.withOpacity(0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - 5, cy - 5));
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) => false;
}
