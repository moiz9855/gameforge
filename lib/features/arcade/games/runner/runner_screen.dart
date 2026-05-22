import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'runner_game.dart';

class RunnerScreen extends StatefulWidget {
  const RunnerScreen({super.key});

  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen> {
  RunnerGame? _game;

  bool _started = false;
  bool _gameOver = false;

  int _score = 0;
  double _distance = 0;
  int _coins = 0;
  double _multiplier = 1.0;

  int _finalScore = 0;
  bool _isNewRecord = false;
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    final hs = await AchievementService.instance.getHighScore('runner');
    if (!mounted) return;

    final game = RunnerGame(
      bestScore: hs,
      onScoreUpdate: (score, dist, coins, mult) {
        if (mounted) {
          setState(() {
            _score = score;
            _distance = dist;
            _coins = coins;
            _multiplier = mult;
          });
        }
      },
      onGameOver: (score, dist, coins, isNewRecord) {
        if (mounted) {
          setState(() {
            _gameOver = true;
            _finalScore = score;
            _isNewRecord = isNewRecord;
            _distance = dist;
            _coins = coins;
          });
          AchievementService.instance.saveHighScore('runner', score);
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
      _distance = 0;
      _coins = 0;
      _multiplier = 1.0;
    });
  }

  void _handleSwipe(DragEndDetails details) {
    if (!_started || _gameOver || _game == null) return;

    final v = details.velocity.pixelsPerSecond;
    const threshold = 80.0;

    if (v.dx.abs() > v.dy.abs() && v.dx.abs() > threshold) {
      if (v.dx > 0) {
        _game!.moveRight();
      } else {
        _game!.moveLeft();
      }
      HapticFeedback.selectionClick();
    } else if (v.dy.abs() > threshold) {
      if (v.dy < 0) {
        _game!.jump();
      } else {
        _game!.slide();
      }
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF05A28)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              // ── Flame game canvas ──
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanEnd: _handleSwipe,
                child: GameWidget(game: _game!),
              ),

              // ── HUD ──
              if (_started && !_gameOver)
                IgnorePointer(child: _buildHud()),

              // ── Start overlay ──
              if (!_started) _buildStartOverlay(),

              // ── Game Over overlay ──
              if (_gameOver) _buildGameOverOverlay(),

              // ── Back button (always visible) ──
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

  // ─────────────────────────────────────────────────
  //  HUD
  // ─────────────────────────────────────────────────
  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('SCORE',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 6, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('$_score',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 14, color: Colors.white)),
              ],
            ),
          ),

          // Distance (center)
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text('DISTANCE',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 6, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('${_distance.toInt()}m',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 12, color: const Color(0xFFF05A28))),
              ],
            ),
          ),

          // Coins + multiplier (right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 32),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text('$_coins',
                        style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: const Color(0xFFF05A28))),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05A28).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('x${_multiplier.toStringAsFixed(1)}',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 7, color: AppColors.gold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  //  START OVERLAY
  // ─────────────────────────────────────────────────
  Widget _buildStartOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏃', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text('ENDLESS RUNNER',
                  style: GoogleFonts.pressStart2p(
                      fontSize: 16,
                      color: const Color(0xFFF05A28),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('CYBERPUNK DASH',
                  style: GoogleFonts.shareTechMono(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      letterSpacing: 3)),
              const SizedBox(height: 28),

              // controls guide
              _controlRow('SWIPE  ←  →', 'CHANGE LANE'),
              const SizedBox(height: 6),
              _controlRow('SWIPE  ↑', 'JUMP'),
              const SizedBox(height: 6),
              _controlRow('SWIPE  ↓', 'SLIDE'),
              const SizedBox(height: 6),
              _controlRow('🛡 🧲 ⚡', 'POWER-UPS'),

              const SizedBox(height: 28),
              if (_bestScore > 0) ...[
                Text('BEST SCORE: $_bestScore',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 9, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('TAP TO RUN',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlRow(String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(left,
              textAlign: TextAlign.right,
              style: GoogleFonts.pressStart2p(
                  fontSize: 7, color: const Color(0xFFF05A28))),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(right,
              style: GoogleFonts.pressStart2p(
                  fontSize: 7, color: Colors.white70)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  //  GAME OVER OVERLAY
  // ─────────────────────────────────────────────────
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
                Text('🌟 NEW RECORD! 🌟',
                    style: GoogleFonts.pressStart2p(
                        fontSize: 12, color: AppColors.gold)),
                const SizedBox(height: 12),
              ],

              Text('GAME OVER',
                  style: GoogleFonts.pressStart2p(
                      fontSize: 20,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Score box
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF05A28).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text('SCORE',
                        style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('$_finalScore',
                        style: GoogleFonts.pressStart2p(
                            fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statChip('${_distance.toInt()}m', '🏃'),
                        const SizedBox(width: 16),
                        _statChip('$_coins', '🪙'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text('BEST: $_bestScore',
                  style: GoogleFonts.pressStart2p(
                      fontSize: 9, color: AppColors.textSecondary)),

              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('PLAY AGAIN',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
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
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('BACK TO ARCADE',
                      style: GoogleFonts.pressStart2p(
                          fontSize: 9, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String value, String emoji) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.pressStart2p(
                fontSize: 9, color: const Color(0xFFF05A28))),
      ],
    );
  }
}
