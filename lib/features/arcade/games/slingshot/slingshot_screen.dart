import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'slingshot_game.dart';

class SlingshotScreen extends StatefulWidget {
  const SlingshotScreen({super.key});

  @override
  State<SlingshotScreen> createState() => _SlingshotScreenState();
}

class _SlingshotScreenState extends State<SlingshotScreen> {
  SlingshotGame? _game;

  SBGameState _state = SBGameState.ready;
  int _score = 0;
  int _balls = 3;
  int _level = 1;
  bool _gameStarted = false;

  int _finalScore = 0;
  bool _isNewRecord = false;
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    final hs = await AchievementService.instance.getHighScore('slingshot');
    if (!mounted) return;

    final game = SlingshotGame(
      bestScore: hs,
      onStateUpdate: (score, balls, level) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _score = score;
                _balls = balls;
                _level = level;
                _state = _game!.state;
              });
            }
          });
        }
      },
      onGameOver: (score, levels, isNewRecord) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _state = SBGameState.gameOver;
                _finalScore = score;
                _isNewRecord = isNewRecord;
              });
              AchievementService.instance.saveHighScore('slingshot', score);
              HapticFeedback.heavyImpact();
              if (isNewRecord) {
                SoundService.instance.play(SoundType.winFanfare);
                setState(() => _bestScore = score);
              } else {
                SoundService.instance.play(SoundType.gameOver);
              }
            }
          });
        }
      },
    );

    setState(() {
      _bestScore = hs;
      _game = game;
    });
  }

  void _startGame() {
    if (_game == null) return;
    SoundService.instance.play(SoundType.gameStart);
    HapticFeedback.lightImpact();
    setState(() => _gameStarted = true);
    _game!.startGame();
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) return const Scaffold(backgroundColor: AppColors.background);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              GameWidget(game: _game!),

              if (_state != SBGameState.gameOver && _state != SBGameState.levelComplete)
                IgnorePointer(child: _buildHud()),

              if (!_gameStarted) _buildStartOverlay(),

              if (_state == SBGameState.levelComplete) _buildCompleteOverlay(),
              if (_state == SBGameState.gameOver) _buildGameOverOverlay(),

              Positioned(
                top: 6,
                left: 6,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () {
                    SoundService.instance.play(SoundType.buttonBack);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    String typeText = 'NORMAL';
    switch (_game?.currentBallType ?? BallType.normal) {
      case BallType.normal: typeText = '🔴 NORMAL'; break;
      case BallType.heavy: typeText = '⚫ HEAVY'; break;
      case BallType.split: typeText = '🔵 SPLIT'; break;
      case BallType.bomb: typeText = '💣 BOMB'; break;
      case BallType.bounce: typeText = '🟡 BOUNCE'; break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text('SCORE', style: GoogleFonts.pressStart2p(fontSize: 6, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$_score', style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Text('LEVEL', style: GoogleFonts.pressStart2p(fontSize: 6, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$_level/75', style: GoogleFonts.pressStart2p(fontSize: 12, color: const Color(0xFFF05A28))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔴', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text('$_balls', style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFF05A28))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              typeText,
              style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎪', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text('SLINGSHOT BLAST', style: GoogleFonts.pressStart2p(fontSize: 16, color: const Color(0xFFF05A28), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('PULL TO SHOOT', style: GoogleFonts.shareTechMono(fontSize: 14, color: AppColors.textSecondary, letterSpacing: 3)),
              const SizedBox(height: 28),
              
              Text('TAP IN MID-AIR FOR SPLIT ABILITY!\nCYCLE 5 UNIQUE POWER BALLS ACROSS 75 LEVELS!', textAlign: TextAlign.center, style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white60, height: 1.8)),
              
              const SizedBox(height: 28),
              if (_bestScore > 0) ...[
                Text('BEST SCORE: $_bestScore', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                  child: Text('START BLAST', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteOverlay() {
    final stars = (_balls + 1).clamp(1, 3);
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LEVEL $_level CLEARED! 🎉',
                style: GoogleFonts.pressStart2p(
                  fontSize: 12,
                  color: const Color(0xFFF05A28),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Stars display
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final filled = index < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      filled ? '⭐' : '☆',
                      style: TextStyle(
                        fontSize: 48,
                        color: filled ? AppColors.gold : Colors.white24,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF05A28).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text('SCORE', style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('$_score', style: GoogleFonts.pressStart2p(fontSize: 24, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.gameStart);
                    _game?.nextLevel();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                  child: Text('NEXT LEVEL', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.buttonBack);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                  child: Text('BACK TO ARCADE', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isNewRecord) ...[
                Text('🌟 NEW RECORD! 🌟', style: GoogleFonts.pressStart2p(fontSize: 12, color: AppColors.gold)),
                const SizedBox(height: 12),
              ],

              Text('OUT OF BALLS', style: GoogleFonts.pressStart2p(fontSize: 16, color: AppColors.error, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF05A28).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text('SCORE', style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('$_finalScore', style: GoogleFonts.pressStart2p(fontSize: 24, color: Colors.white)),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text('BEST: $_bestScore', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),

              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                  child: Text('PLAY AGAIN', style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.buttonBack);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                  child: Text('BACK TO ARCADE', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
