import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

class FlappyScreen extends StatefulWidget {
  const FlappyScreen({super.key});

  @override
  State<FlappyScreen> createState() => _FlappyScreenState();
}

class _FlappyScreenState extends State<FlappyScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  
  // Game dimensions
  static const double gameWidth = 400.0;
  static const double gameHeight = 600.0;
  
  // Physics constants
  static const double gravity = 900.0;
  static const double jumpVelocity = -290.0;
  static const double pipeSpeed = 160.0;
  static const double pipeSpacing = 220.0;
  static const double pipeGap = 160.0;
  static const double birdRadius = 14.0;
  static const double birdX = 100.0;

  // Game state variables
  double birdY = gameHeight / 2;
  double birdVy = 0.0;
  List<_Pipe> pipes = [];
  
  int score = 0;
  int highscore = 0;
  
  bool isPlaying = false;
  bool isGameOver = false;
  String message = 'TAP TO FLAP';

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _ticker = createTicker(_tick);
    _resetGame();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final hs = await AchievementService.instance.getHighScore('flappy');
    setState(() => highscore = hs);
  }

  void _resetGame() {
    setState(() {
      birdY = gameHeight / 2;
      birdVy = 0.0;
      pipes = [
        _Pipe(x: gameWidth + 100),
        _Pipe(x: gameWidth + 100 + pipeSpacing),
      ];
      score = 0;
      isGameOver = false;
      isPlaying = false;
      message = 'TAP TO FLAP';
    });
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
      message = '';
    });
    _ticker.start();
    _flap();
    SoundService.instance.play(SoundType.gameStart);
  }

  void _flap() {
    if (isGameOver) return;
    if (!isPlaying) {
      _startGame();
      return;
    }
    setState(() {
      birdVy = jumpVelocity;
    });
    SoundService.instance.play(SoundType.flap);
    HapticFeedback.lightImpact();
  }

  void _tick(Duration elapsed) {
    const double dt = 0.016; // Fixed timestep for physics stability at 60fps

    setState(() {
      // 1. Apply gravity to bird
      birdVy += gravity * dt;
      birdY += birdVy * dt;

      // 2. Move & generate pipes
      for (final pipe in pipes) {
        pipe.x -= pipeSpeed * dt;
        
        // Pass pipe trigger
        if (!pipe.passed && pipe.x + 50.0 < birdX - birdRadius) {
          pipe.passed = true;
          score++;
          SoundService.instance.play(SoundType.scoreUp);
          HapticFeedback.selectionClick();
        }
      }

      // Remove off-screen pipes and add a new one
      if (pipes.first.x < -60) {
        pipes.removeAt(0);
        final lastX = pipes.last.x;
        pipes.add(_Pipe(x: lastX + pipeSpacing));
      }

      // 3. Collision checks
      // Ceiling/floor collisions
      if (birdY - birdRadius < 0 || birdY + birdRadius > gameHeight) {
        _endGame();
        return;
      }

      // Pipe collisions
      for (final pipe in pipes) {
        if (pipe.x < birdX + birdRadius && pipe.x + 50 > birdX - birdRadius) {
          // Bird is horizontally inside this pipe's column.
          // Check vertical bounds
          if (birdY - birdRadius < pipe.topHeight || birdY + birdRadius > pipe.topHeight + pipeGap) {
            _endGame();
            return;
          }
        }
      }
    });
  }

  void _endGame() {
    _ticker.stop();
    setState(() {
      isPlaying = false;
      isGameOver = true;
      message = 'GAME OVER';
    });

    SoundService.instance.play(SoundType.gameOver);
    HapticFeedback.vibrate();

    AchievementService.instance.saveHighScore('flappy', score);
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
            if (_ticker.isTicking) _ticker.stop();
            Navigator.pop(context);
          },
        ),
        titleOverride: Text(
          'FLAPPY',
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: gameWidth / gameHeight,
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
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scaleX = constraints.maxWidth / gameWidth;
                          final scaleY = constraints.maxHeight / gameHeight;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _flap,
                            child: Stack(
                              children: [
                                // Custom Game Canvas
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: _FlappyPainter(
                                    birdY: birdY,
                                    birdVy: birdVy,
                                    pipes: pipes,
                                    score: score,
                                    scaleX: scaleX,
                                    scaleY: scaleY,
                                    birdRadius: birdRadius,
                                    birdX: birdX,
                                    pipeGap: pipeGap,
                                    gameWidth: gameWidth,
                                    gameHeight: gameHeight,
                                  ),
                                ),

                                // Overlays
                                if (!isPlaying)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            message,
                                            style: GoogleFonts.pressStart2p(
                                              color: isGameOver ? AppColors.error : AppColors.primary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          if (isGameOver) ...[
                                            Text(
                                              'SCORE: $score',
                                              style: GoogleFonts.pressStart2p(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                          ] else ...[
                                            Text(
                                              'TAP ANYWHERE TO JUMP',
                                              style: GoogleFonts.pressStart2p(
                                                color: AppColors.textSecondary,
                                                fontSize: 10,
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
                                              } else {
                                                _startGame();
                                              }
                                            },
                                            child: Text(
                                              isGameOver ? 'RETRY' : 'PLAY NOW',
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
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'TAP ANYWHERE TO FLAP',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _Pipe {
  double x;
  double topHeight;
  bool passed = false;

  _Pipe({required this.x})
      : topHeight = 100.0 + math.Random().nextDouble() * 200.0;
}

class _FlappyPainter extends CustomPainter {
  final double birdY;
  final double birdVy;
  final List<_Pipe> pipes;
  final int score;
  final double scaleX;
  final double scaleY;
  final double birdRadius;
  final double birdX;
  final double pipeGap;
  final double gameWidth;
  final double gameHeight;

  const _FlappyPainter({
    required this.birdY,
    required this.birdVy,
    required this.pipes,
    required this.score,
    required this.scaleX,
    required this.scaleY,
    required this.birdRadius,
    required this.birdX,
    required this.pipeGap,
    required this.gameWidth,
    required this.gameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw background grid
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    
    final double stepX = 25.0 * scaleX;
    final double stepY = 25.0 * scaleY;
    for (double x = 0; x < size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw Pipes
    final pipePaint = Paint()..color = const Color(0xFF2E7D32); // Retro green pipe
    final pipeBorderPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * scaleX;

    for (final pipe in pipes) {
      final double px = pipe.x * scaleX;
      final double pw = 50.0 * scaleX;
      final double topH = pipe.topHeight * scaleY;
      final double bottomY = (pipe.topHeight + pipeGap) * scaleY;
      final double bottomH = size.height - bottomY;

      // Top pipe
      final topRect = Rect.fromLTWH(px, 0, pw, topH);
      canvas.drawRect(topRect, pipePaint);
      canvas.drawRect(topRect, pipeBorderPaint);

      // Top pipe flange/lip
      final topLipRect = Rect.fromLTWH(px - 4 * scaleX, topH - 20 * scaleY, pw + 8 * scaleX, 20 * scaleY);
      canvas.drawRect(topLipRect, pipePaint);
      canvas.drawRect(topLipRect, pipeBorderPaint);

      // Bottom pipe
      final bottomRect = Rect.fromLTWH(px, bottomY, pw, bottomH);
      canvas.drawRect(bottomRect, pipePaint);
      canvas.drawRect(bottomRect, pipeBorderPaint);

      // Bottom pipe flange/lip
      final bottomLipRect = Rect.fromLTWH(px - 4 * scaleX, bottomY, pw + 8 * scaleX, 20 * scaleY);
      canvas.drawRect(bottomLipRect, pipePaint);
      canvas.drawRect(bottomLipRect, pipeBorderPaint);
    }

    // 3. Draw Bird (Retro pixel-art custom rendering)
    final double bx = birdX * scaleX;
    final double by = birdY * scaleY;
    
    // Rotate bird based on velocity
    canvas.save();
    canvas.translate(bx, by);
    final double rotation = (birdVy / 400.0).clamp(-0.5, 0.7);
    canvas.rotate(rotation);

    // Pixel width is 3 units
    final double px = 3.0 * scaleX;
    final double py = 3.0 * scaleY;

    // A blocky retro pixel layout of the bird
    // Drawing a blocky body
    final birdPaint = Paint()..color = const Color(0xFFFBC02D); // Yellow body
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final beakPaint = Paint()..color = const Color(0xFFE65100); // Orange beak
    final wingPaint = Paint()..color = Colors.white;

    // Body base rect
    canvas.drawRect(Rect.fromLTRB(-4 * px, -3 * py, 4 * px, 4 * py), birdPaint);
    canvas.drawRect(Rect.fromLTRB(-2 * px, -4 * py, 3 * px, -3 * py), birdPaint);

    // Beak
    canvas.drawRect(Rect.fromLTRB(3 * px, 0, 6 * px, 3 * py), beakPaint);

    // Eye
    canvas.drawRect(Rect.fromLTRB(1 * px, -3 * py, 3 * px, -1 * py), eyePaint);
    canvas.drawRect(Rect.fromLTRB(2 * px, -3 * py, 3 * px, -2 * py), pupilPaint);

    // Wing
    canvas.drawRect(Rect.fromLTRB(-3 * px, 0, 0, 3 * py), wingPaint);

    canvas.restore();

    // 4. Draw Score
    if (score > 0) {
      final scorePainter = TextPainter(
        text: TextSpan(
          text: '$score',
          style: GoogleFonts.pressStart2p(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      scorePainter.paint(
        canvas,
        Offset(size.width / 2 - scorePainter.width / 2, size.height * 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter oldDelegate) => true;
}
