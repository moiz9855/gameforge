import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen> {
  // Board configuration
  static const int cols = 10;
  static const int rows = 20;

  // Game grid representation: null means empty cell, otherwise stores block color
  List<List<Color?>> grid = List.generate(rows, (_) => List.generate(cols, (_) => null));

  // Current falling piece state
  String currentType = '';
  List<math.Point<int>> currentPiece = [];
  Color currentPieceColor = Colors.transparent;
  int currentX = 0;
  int currentY = 0;

  // Next piece preview
  String nextType = '';
  List<math.Point<int>> nextPiece = [];
  Color nextPieceColor = Colors.transparent;

  // Game stats
  int score = 0;
  int linesCleared = 0;
  int level = 1;
  int highscore = 0;
  
  bool isPlaying = false;
  bool isGameOver = false;
  Timer? gameTimer;

  // Tetromino definitions (I, O, T, S, Z, J, L)
  static const Map<String, List<math.Point<int>>> shapes = {
    'I': [math.Point(0, 0), math.Point(-1, 0), math.Point(1, 0), math.Point(2, 0)],
    'O': [math.Point(0, 0), math.Point(1, 0), math.Point(0, 1), math.Point(1, 1)],
    'T': [math.Point(0, 0), math.Point(-1, 0), math.Point(1, 0), math.Point(0, 1)],
    'S': [math.Point(0, 0), math.Point(1, 0), math.Point(0, 1), math.Point(-1, 1)],
    'Z': [math.Point(0, 0), math.Point(-1, 0), math.Point(0, 1), math.Point(1, 1)],
    'J': [math.Point(0, 0), math.Point(-1, 0), math.Point(1, 0), math.Point(1, 1)],
    'L': [math.Point(0, 0), math.Point(-1, 0), math.Point(1, 0), math.Point(-1, 1)],
  };

  static const Map<String, Color> colors = {
    'I': Colors.cyan,
    'O': Colors.yellow,
    'T': Colors.purple,
    'S': Colors.green,
    'Z': Colors.red,
    'J': Colors.blue,
    'L': Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _resetGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final hs = await AchievementService.instance.getHighScore('tetris');
    setState(() => highscore = hs);
  }

  void _resetGame() {
    setState(() {
      grid = List.generate(rows, (_) => List.generate(cols, (_) => null));
      score = 0;
      linesCleared = 0;
      level = 1;
      isGameOver = false;
      isPlaying = false;
    });
    _generateNextPiece();
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
    });
    _spawnPiece();
    _startTimer();
    SoundService.instance.play(SoundType.gameStart);
  }

  void _startTimer() {
    gameTimer?.cancel();
    // Speed scales up: gets 80ms faster per level, capped at 100ms
    final int speedMs = math.max(100, 800 - (level - 1) * 80);
    gameTimer = Timer.periodic(Duration(milliseconds: speedMs), (_) => _tick());
  }

  void _generateNextPiece() {
    final rand = math.Random();
    final keys = shapes.keys.toList();
    nextType = keys[rand.nextInt(keys.length)];
    nextPiece = List.from(shapes[nextType]!);
    nextPieceColor = colors[nextType]!;
  }

  void _spawnPiece() {
    currentType = nextType;
    currentPiece = List.from(nextPiece);
    currentPieceColor = nextPieceColor;
    
    // Spawn at top center
    currentX = cols ~/ 2 - 1;
    currentY = 0;

    _generateNextPiece();

    // Check collision right after spawning -> Game Over
    if (_checkCollision(currentPiece, currentX, currentY)) {
      _endGame();
    }
  }

  void _tick() {
    if (isGameOver || !isPlaying) return;
    _moveDown();
  }

  void _moveDown() {
    if (!_checkCollision(currentPiece, currentX, currentY + 1)) {
      setState(() {
        currentY++;
      });
    } else {
      _lockPiece();
    }
  }

  void _lockPiece() {
    setState(() {
      for (final pt in currentPiece) {
        final int gx = currentX + pt.x;
        final int gy = currentY + pt.y;
        if (gy >= 0 && gy < rows && gx >= 0 && gx < cols) {
          grid[gy][gx] = currentPieceColor;
        }
      }
    });

    SoundService.instance.play(SoundType.tetrisMove);
    HapticFeedback.lightImpact();

    _clearLines();
    _spawnPiece();
  }

  void _clearLines() {
    int cleared = 0;
    for (int y = rows - 1; y >= 0; y--) {
      bool isRowFull = true;
      for (int x = 0; x < cols; x++) {
        if (grid[y][x] == null) {
          isRowFull = false;
          break;
        }
      }

      if (isRowFull) {
        cleared++;
        grid.removeAt(y);
        grid.insert(0, List.generate(cols, (_) => null));
        y++; // Re-check this line position since rows shifted down
      }
    }

    if (cleared > 0) {
      // Calculate scores (Classic Tetris-style scoring)
      final scoreBonus = [0, 100, 300, 500, 800];
      setState(() {
        score += scoreBonus[cleared] * level;
        linesCleared += cleared;
        level = (linesCleared ~/ 10) + 1;
      });

      SoundService.instance.play(SoundType.tetrisClear);
      HapticFeedback.mediumImpact();

      // Recalculate timer speed in case level changed
      _startTimer();

      // Check achievements
      AchievementService.instance.saveHighScore('tetris', score);
      _loadHighScore();
    }
  }

  bool _checkCollision(List<math.Point<int>> piece, int cx, int cy) {
    for (final pt in piece) {
      final int targetX = cx + pt.x;
      final int targetY = cy + pt.y;

      if (targetX < 0 || targetX >= cols || targetY >= rows) {
        return true;
      }
      if (targetY >= 0 && grid[targetY][targetX] != null) {
        return true;
      }
    }
    return false;
  }

  void _moveLeft() {
    if (isGameOver || !isPlaying) return;
    if (!_checkCollision(currentPiece, currentX - 1, currentY)) {
      setState(() => currentX--);
      SoundService.instance.play(SoundType.tetrisMove);
    }
  }

  void _moveRight() {
    if (isGameOver || !isPlaying) return;
    if (!_checkCollision(currentPiece, currentX + 1, currentY)) {
      setState(() => currentX++);
      SoundService.instance.play(SoundType.tetrisMove);
    }
  }

  void _rotate() {
    if (isGameOver || !isPlaying) return;
    if (currentType == 'O') return; // O piece does not rotate

    final rotated = currentPiece.map((pt) {
      // Rotate 90 degrees clockwise: (x, y) -> (-y, x)
      return math.Point(-pt.y, pt.x);
    }).toList();

    // Check collision. If colliding, try wall-kicks (adjust left/right/up)
    final kicks = [0, -1, 1, -2, 2];
    for (final kick in kicks) {
      if (!_checkCollision(rotated, currentX + kick, currentY)) {
        setState(() {
          currentPiece = rotated;
          currentX += kick;
        });
        SoundService.instance.play(SoundType.tetrisMove);
        HapticFeedback.selectionClick();
        return;
      }
    }
  }

  void _hardDrop() {
    if (isGameOver || !isPlaying) return;
    int dropY = currentY;
    while (!_checkCollision(currentPiece, currentX, dropY + 1)) {
      dropY++;
    }
    
    // Animate hard drop points addition
    setState(() {
      score += (dropY - currentY) * 2;
      currentY = dropY;
    });

    HapticFeedback.heavyImpact();
    _lockPiece();
  }

  void _endGame() {
    gameTimer?.cancel();
    setState(() {
      isPlaying = false;
      isGameOver = true;
    });
    SoundService.instance.play(SoundType.gameOver);
    HapticFeedback.vibrate();

    AchievementService.instance.saveHighScore('tetris', score);
    _loadHighScore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () {
            gameTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        titleOverride: Text(
          'TETRIS',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('BEST: $highscore',
                    style: const TextStyle(color: AppColors.fire2, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
      body: CrtOverlay(
        child: Column(
          children: [
            // Score, Level & Next Piece Panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCORE: $score',
                        style: GoogleFonts.pressStart2p(fontSize: 11, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'LEVEL: $level  LINES: $linesCleared',
                        style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'NEXT: ',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.textSecondary),
                        ),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _NextPiecePainter(
                              piece: nextPiece,
                              color: nextPieceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Game Matrix
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: AspectRatio(
                  aspectRatio: cols / rows,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size.infinite,
                            painter: _TetrisPainter(
                              grid: grid,
                              currentPiece: currentPiece,
                              currentX: currentX,
                              currentY: currentY,
                              currentPieceColor: currentPieceColor,
                              cols: cols,
                              rows: rows,
                            ),
                          ),

                          // Overlays
                          if (!isPlaying)
                            Container(
                              color: Colors.black.withValues(alpha: 0.78),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isGameOver ? 'GAME OVER' : 'TETRIS',
                                      style: GoogleFonts.pressStart2p(
                                        color: isGameOver ? AppColors.error : AppColors.primary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (isGameOver) ...[
                                      Text(
                                        'FINAL SCORE: $score',
                                        style: GoogleFonts.pressStart2p(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ] else ...[
                                      Text(
                                        'MANEUVER FALLING BLOCKS',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.pressStart2p(
                                          color: AppColors.textSecondary,
                                          fontSize: 8,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 28, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        if (isGameOver) {
                                          _resetGame();
                                        }
                                        _startGame();
                                      },
                                      child: Text(
                                        isGameOver ? 'PLAY AGAIN' : 'START BOOT',
                                        style: GoogleFonts.pressStart2p(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Virtual controls D-Pad & Action Buttons
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // D-Pad for Directional movements
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ControlBtn(
                            icon: Icons.arrow_back,
                            onTap: _moveLeft,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _ControlBtn(
                            icon: Icons.arrow_forward,
                            onTap: _moveRight,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _ControlBtn(
                            icon: Icons.arrow_downward,
                            onTap: _moveDown,
                          ),
                        ),
                        const Center(
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.card2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons (Rotate & Hard drop)
                  Row(
                    children: [
                      Column(
                        children: [
                          _ActionBtn(
                            label: 'ROT',
                            color: AppColors.primary,
                            onTap: _rotate,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ROTATE',
                            style: GoogleFonts.pressStart2p(fontSize: 7, color: AppColors.textSecondary),
                          )
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          _ActionBtn(
                            label: 'DROP',
                            color: AppColors.fire2,
                            onTap: _hardDrop,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DROP',
                            style: GoogleFonts.pressStart2p(fontSize: 7, color: AppColors.textSecondary),
                          )
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.fire2, size: 24),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _TetrisPainter extends CustomPainter {
  final List<List<Color?>> grid;
  final List<math.Point<int>> currentPiece;
  final int currentX;
  final int currentY;
  final Color currentPieceColor;
  final int cols;
  final int rows;

  const _TetrisPainter({
    required this.grid,
    required this.currentPiece,
    required this.currentX,
    required this.currentY,
    required this.currentPieceColor,
    required this.cols,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double blockW = size.width / cols;
    final double blockH = size.height / rows;

    // Draw background grid lines (subtle)
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * blockH), Offset(size.width, r * blockH), gridPaint);
    }
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * blockW, 0), Offset(c * blockW, size.height), gridPaint);
    }

    // Draw locked grid cells
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final Color? color = grid[y][x];
        if (color != null) {
          _drawBlock(canvas, x, y, blockW, blockH, color);
        }
      }
    }

    // Draw currently active falling piece
    if (currentPieceColor != Colors.transparent) {
      for (final pt in currentPiece) {
        final int px = currentX + pt.x;
        final int py = currentY + pt.y;
        if (py >= 0 && py < rows && px >= 0 && px < cols) {
          _drawBlock(canvas, px, py, blockW, blockH, currentPieceColor);
        }
      }
    }
  }

  void _drawBlock(Canvas canvas, int x, int y, double w, double h, Color color) {
    final rect = Rect.fromLTWH(x * w + 1, y * h + 1, w - 2, h - 2);
    final paint = Paint()..color = color;
    
    // Draw base block
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);

    // Draw highlights for a nice 3D/retro look
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), highlightPaint);

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(rect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _TetrisPainter oldDelegate) => true;
}

class _NextPiecePainter extends CustomPainter {
  final List<math.Point<int>> piece;
  final Color color;

  const _NextPiecePainter({required this.piece, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (piece.isEmpty) return;
    
    // Calculate block bounds in order to center the preview
    int minX = 999, maxX = -999, minY = 999, maxY = -999;
    for (final pt in piece) {
      minX = math.min(minX, pt.x);
      maxX = math.max(maxX, pt.x);
      minY = math.min(minY, pt.y);
      maxY = math.max(maxY, pt.y);
    }
    
    final int widthInBlocks = maxX - minX + 1;
    final int heightInBlocks = maxY - minY + 1;
    
    final double blockSize = math.min(size.width / 4, size.height / 4);
    
    // Offsets to center the piece in the preview canvas
    final double offsetX = (size.width - widthInBlocks * blockSize) / 2 - minX * blockSize;
    final double offsetY = (size.height - heightInBlocks * blockSize) / 2 - minY * blockSize;

    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final pt in piece) {
      final rect = Rect.fromLTWH(
        offsetX + pt.x * blockSize + 1,
        offsetY + pt.y * blockSize + 1,
        blockSize - 2,
        blockSize - 2,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) => true;
}
