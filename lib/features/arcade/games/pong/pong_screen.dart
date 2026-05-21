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

class PongScreen extends StatefulWidget {
  const PongScreen({super.key});

  @override
  State<PongScreen> createState() => _PongScreenState();
}

class _PongScreenState extends State<PongScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  
  // Game dimensions (logical coordinate space)
  static const double gameWidth = 400.0;
  static const double gameHeight = 600.0;

  static const double paddleWidth = 14.0;
  static const double paddleHeight = 85.0;
  static const double ballSize = 12.0;

  // Game state
  double playerY = (gameHeight - paddleHeight) / 2;
  double aiY = (gameHeight - paddleHeight) / 2;
  
  double ballX = gameWidth / 2;
  double ballY = gameHeight / 2;
  double ballVx = 160.0; // Units per second
  double ballVy = 120.0;

  int playerScore = 0;
  int aiScore = 0;
  int highscore = 0;

  bool isPlaying = false;
  bool isGameOver = false;
  String message = 'TAP SCREEN TO START';
  bool _playerWon = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _ticker = createTicker(_tick);
    _resetBall(toPlayer: true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final hs = await AchievementService.instance.getHighScore('pong');
    setState(() => highscore = hs);
  }

  void _startGame() {
    setState(() {
      playerScore = 0;
      aiScore = 0;
      isGameOver = false;
      isPlaying = true;
      message = '';
    });
    _resetBall(toPlayer: true);
    _ticker.start();
    SoundService.instance.play(SoundType.gameStart);
  }

  void _resetBall({required bool toPlayer}) {
    ballX = gameWidth / 2;
    ballY = gameHeight / 2;
    // Serve towards whoever lost the last point
    ballVx = toPlayer ? -180.0 : 180.0;
    // Random vertical angle
    ballVy = (math.Random().nextDouble() * 2 - 1) * 120.0;
  }

  void _tick(Duration elapsed) {
    // We want delta time in seconds
    const double dt = 0.016; // Fixed timestep for physics stability at 60fps

    setState(() {
      // 1. Move Ball
      ballX += ballVx * dt;
      ballY += ballVy * dt;

      // 2. AI Opponent Paddle Logic
      final double aiTargetY = ballY - paddleHeight / 2;
      final double diffY = aiTargetY - aiY;
      // AI speed scales with score and ball speed to keep challenging
      const double baseAiSpeed = 160.0;
      final double speedScale = 1.0 + (playerScore + aiScore) * 0.08;
      final double maxAiStep = baseAiSpeed * speedScale * dt;
      aiY += diffY.clamp(-maxAiStep, maxAiStep);
      aiY = aiY.clamp(0.0, gameHeight - paddleHeight);

      // 3. Wall Collisions (Top / Bottom)
      if (ballY <= 0) {
        ballY = 0;
        ballVy = -ballVy;
        SoundService.instance.play(SoundType.wallHit);
      } else if (ballY >= gameHeight - ballSize) {
        ballY = gameHeight - ballSize;
        ballVy = -ballVy;
        SoundService.instance.play(SoundType.wallHit);
      }

      // 4. Paddle Collisions
      // Player Paddle (Left)
      const double playerPaddleX = 20.0;
      if (ballVx < 0 &&
          ballX <= playerPaddleX + paddleWidth &&
          ballX >= playerPaddleX &&
          ballY + ballSize >= playerY &&
          ballY <= playerY + paddleHeight) {
        
        // Bounce off player paddle
        ballX = playerPaddleX + paddleWidth;
        ballVx = -ballVx * 1.08; // Accelerate ball slightly
        
        // Apply spin relative to where it hit the paddle
        final double relativeIntersectY = (playerY + (paddleHeight / 2)) - (ballY + ballSize / 2);
        final double normalizedIntersectY = relativeIntersectY / (paddleHeight / 2);
        ballVy = -normalizedIntersectY * 200.0;

        SoundService.instance.play(SoundType.paddleHit);
        HapticFeedback.lightImpact();
      }

      // AI Paddle (Right)
      const double aiPaddleX = gameWidth - 20.0 - paddleWidth;
      if (ballVx > 0 &&
          ballX + ballSize >= aiPaddleX &&
          ballX + ballSize <= aiPaddleX + paddleWidth &&
          ballY + ballSize >= aiY &&
          ballY <= aiY + paddleHeight) {
        
        // Bounce off AI paddle
        ballX = aiPaddleX - ballSize;
        ballVx = -ballVx * 1.08; // Accelerate ball slightly

        final double relativeIntersectY = (aiY + (paddleHeight / 2)) - (ballY + ballSize / 2);
        final double normalizedIntersectY = relativeIntersectY / (paddleHeight / 2);
        ballVy = -normalizedIntersectY * 200.0;

        SoundService.instance.play(SoundType.paddleHit);
      }

      // 5. Scoring (Passing Left/Right bounds)
      if (ballX < 0) {
        // AI scored
        aiScore++;
        HapticFeedback.vibrate();
        SoundService.instance.play(SoundType.wallHit);
        if (aiScore >= 5) {
          _endGame(playerWon: false);
        } else {
          _resetBall(toPlayer: true);
        }
      } else if (ballX > gameWidth) {
        // Player scored
        playerScore++;
        HapticFeedback.mediumImpact();
        SoundService.instance.play(SoundType.scoreUp);
        if (playerScore >= 5) {
          _endGame(playerWon: true);
        } else {
          _resetBall(toPlayer: false);
        }
      }
    });
  }

  void _endGame({required bool playerWon}) {
    _ticker.stop();
    setState(() {
      isPlaying = false;
      isGameOver = true;
      _playerWon = playerWon;
      message = playerWon ? 'YOU WIN!' : 'GAME OVER';
    });

    SoundService.instance.play(SoundType.gameOver);

    if (playerWon) {
      // Unlock Achievements
      AchievementService.instance.unlock('pong_champion');
      if (aiScore <= 1) {
        AchievementService.instance.unlock('paddle_master');
      }
      
      // Save high score (margin of victory or win state)
      final scoreMargin = playerScore - aiScore;
      AchievementService.instance.saveHighScore('pong', scoreMargin);
      _loadHighScore();
    }
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
          'PONG',
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
                Text('BEST MARGIN: $highscore',
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
                          // Scale factor between logical game coordinates and layout size
                          final scaleX = constraints.maxWidth / gameWidth;
                          final scaleY = constraints.maxHeight / gameHeight;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              if (!isPlaying) return;
                              setState(() {
                                // Scale the touch delta to game coordinate space
                                final double dy = details.delta.dy / scaleY;
                                playerY = (playerY + dy).clamp(0.0, gameHeight - paddleHeight);
                              });
                            },
                            onTap: () {
                              if (!isPlaying && !isGameOver) {
                                _startGame();
                              }
                            },
                            child: Stack(
                              children: [
                                // Custom Game Board Paint
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: _PongPainter(
                                    playerY: playerY,
                                    aiY: aiY,
                                    ballX: ballX,
                                    ballY: ballY,
                                    playerScore: playerScore,
                                    aiScore: aiScore,
                                    scaleX: scaleX,
                                    scaleY: scaleY,
                                    ballSize: ballSize,
                                    paddleWidth: paddleWidth,
                                    paddleHeight: paddleHeight,
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
                                              color: isGameOver
                                                  ? (_playerWon ? Colors.green : AppColors.error)
                                                  : AppColors.primary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          if (isGameOver) ...[
                                            Text(
                                              'YOU: $playerScore  -  AI: $aiScore',
                                              style: GoogleFonts.pressStart2p(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                          ] else ...[
                                            Text(
                                              'DRAG LEFT SIDE TO MOVE PADDLE',
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
                                            onPressed: _startGame,
                                            child: Text(
                                              isGameOver ? 'PLAY AGAIN' : 'START GAME',
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
            
            // Drag visual indicators / mobile buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_vert, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'DRAG PADDLE',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'FIRST TO 5 WINS',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 9,
                      color: AppColors.fire2,
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

class _PongPainter extends CustomPainter {
  final double playerY;
  final double aiY;
  final double ballX;
  final double ballY;
  final int playerScore;
  final int aiScore;
  
  final double scaleX;
  final double scaleY;
  final double ballSize;
  final double paddleWidth;
  final double paddleHeight;
  final double gameWidth;
  final double gameHeight;

  const _PongPainter({
    required this.playerY,
    required this.aiY,
    required this.ballX,
    required this.ballY,
    required this.playerScore,
    required this.aiScore,
    required this.scaleX,
    required this.scaleY,
    required this.ballSize,
    required this.paddleWidth,
    required this.paddleHeight,
    required this.gameWidth,
    required this.gameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Center dashed line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 3.0;
    
    double dashedY = 0;
    while (dashedY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, dashedY),
        Offset(size.width / 2, dashedY + 15),
        linePaint,
      );
      dashedY += 30;
    }

    // 2. Draw scores in retro style
    final scorePainterLeft = TextPainter(
      text: TextSpan(
        text: '$playerScore',
        style: GoogleFonts.pressStart2p(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final scorePainterRight = TextPainter(
      text: TextSpan(
        text: '$aiScore',
        style: GoogleFonts.pressStart2p(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    scorePainterLeft.paint(
      canvas,
      Offset(size.width * 0.25 - scorePainterLeft.width / 2, size.height * 0.15),
    );

    scorePainterRight.paint(
      canvas,
      Offset(size.width * 0.75 - scorePainterRight.width / 2, size.height * 0.15),
    );

    // 3. Draw Player Paddle (Left)
    final playerRect = Rect.fromLTWH(
      20.0 * scaleX,
      playerY * scaleY,
      paddleWidth * scaleX,
      paddleHeight * scaleY,
    );
    final paddlePaint = Paint()..color = AppColors.primary;
    canvas.drawRect(playerRect, paddlePaint);

    // Glow on player paddle
    canvas.drawRect(
      playerRect,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 4. Draw AI Paddle (Right)
    final aiRect = Rect.fromLTWH(
      (gameWidth - 20.0 - paddleWidth) * scaleX,
      aiY * scaleY,
      paddleWidth * scaleX,
      paddleHeight * scaleY,
    );
    canvas.drawRect(aiRect, paddlePaint);

    // Glow on AI paddle
    canvas.drawRect(
      aiRect,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 5. Draw Ball
    final ballRect = Rect.fromLTWH(
      ballX * scaleX,
      ballY * scaleY,
      ballSize * scaleX,
      ballSize * scaleY,
    );
    final ballPaint = Paint()..color = AppColors.fire2;
    canvas.drawRect(ballRect, ballPaint);

    // Glow on ball
    canvas.drawRect(
      ballRect,
      Paint()
        ..color = AppColors.fire2.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _PongPainter oldDelegate) => true;
}
