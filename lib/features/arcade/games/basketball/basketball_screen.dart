import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'basketball_game.dart';

class BasketballScreen extends StatefulWidget {
  const BasketballScreen({super.key});

  @override
  State<BasketballScreen> createState() => _BasketballScreenState();
}

class _BasketballScreenState extends State<BasketballScreen> {
  BasketballGame? _game;

  bool _started = false;
  bool _gameOver = false;

  int _score = 0;
  int _shots = 5;
  int _level = 1;

  int _finalScore = 0;
  bool _isNewRecord = false;
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    final hs = await AchievementService.instance.getHighScore('basketball');
    if (!mounted) return;

    final game = BasketballGame(
      bestScore: hs,
      onStateUpdate: (score, shots, level) {
        if (mounted) {
          setState(() {
            _score = score;
            _shots = shots;
            _level = level;
          });
        }
      },
      onGameOver: (score, levels, isNewRecord) {
        if (mounted) {
          setState(() {
            _gameOver = true;
            _finalScore = score;
            _isNewRecord = isNewRecord;
          });
          AchievementService.instance.saveHighScore('basketball', score);
          HapticFeedback.heavyImpact();
          if (isNewRecord) {
            SoundService.instance.play(SoundType.winFanfare);
            setState(() => _bestScore = score);
          } else {
            SoundService.instance.play(SoundType.gameOver);
          }
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
    _game!.startGame();
    setState(() {
      _started = true;
      _gameOver = false;
      _score = 0;
      _shots = 5;
      _level = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(backgroundColor: AppColors.background);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              GameWidget(game: _game!),

              if (_started && !_gameOver)
                IgnorePointer(child: _buildHud()),

              if (!_started) _buildStartOverlay(),

              if (_gameOver) _buildGameOverOverlay(),

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
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
                Text('$_level', style: GoogleFonts.pressStart2p(fontSize: 12, color: const Color(0xFFF05A28))),
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
                    const Text('🏀', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text('$_shots', style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFF05A28))),
                  ],
                ),
              ],
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
              const Text('🏀', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text('HOOP MASTER', style: GoogleFonts.pressStart2p(fontSize: 16, color: const Color(0xFFF05A28), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('SWIPE TO SHOOT', style: GoogleFonts.shareTechMono(fontSize: 14, color: AppColors.textSecondary, letterSpacing: 3)),
              const SizedBox(height: 28),
              
              Text('WATCH OUT FOR THE WIND!', textAlign: TextAlign.center, style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white70, height: 1.8)),
              
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
                  child: Text('PLAY BALL', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
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

              Text('GAME OVER', style: GoogleFonts.pressStart2p(fontSize: 16, color: AppColors.error, fontWeight: FontWeight.bold)),
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
