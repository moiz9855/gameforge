import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

class TowScreen extends StatefulWidget {
  const TowScreen({super.key});

  @override
  State<TowScreen> createState() => _TowScreenState();
}

class _TowScreenState extends State<TowScreen> with TickerProviderStateMixin {
  // Game phases: 'select_difficulty', 'countdown', 'playing', 'round_over', 'match_over'
  String _phase = 'select_difficulty';
  String _difficulty = 'medium';

  // Rope position: 0 = center, negative = player side, positive = AI side
  double _ropePosition = 0.0;
  static const double _winThreshold = 100.0;

  // AI pull force per second
  double _aiPullForce = 20.0;

  // Stamina
  double _stamina = 100.0;
  static const double _maxStamina = 100.0;
  static const double _staminaDrainPerTap = 8.0;
  static const double _staminaRegenPerSecond = 25.0;
  static const double _pullPower = 10.0;

  // Round tracking (best of 3)
  int _playerRoundsWon = 0;
  int _aiRoundsWon = 0;
  int _currentRound = 1;
  static const int _roundsToWin = 2;

  // Timing
  Timer? _gameLoop;
  DateTime? _roundStartTime;
  double _roundDuration = 0.0;
  double _bestMatchTime = 999.9;

  // Stats
  int _totalWins = 0;
  double _allTimeBestTime = 999.9;

  // Countdown
  int _countdownValue = 3;
  Timer? _countdownTimer;

  // Visual feedback
  double _shakeOffset = 0.0;
  bool _isPulling = false;
  int _tapCount = 0;

  // AI visual animation
  double _aiPullAnim = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await AchievementService.instance.getTowStats();
    if (mounted) {
      setState(() {
        _totalWins = stats['wins'] as int? ?? 0;
        _allTimeBestTime = stats['best_time'] as double? ?? 999.9;
      });
    }
  }

  void _selectDifficulty(String diff) {
    setState(() => _difficulty = diff);
    SoundService.instance.play(SoundType.difficultySelect);
  }

  void _startMatch() {
    double force;
    switch (_difficulty) {
      case 'easy':
        force = 12.0;
        break;
      case 'hard':
        force = 32.0;
        break;
      default:
        force = 20.0;
    }
    setState(() {
      _aiPullForce = force;
      _playerRoundsWon = 0;
      _aiRoundsWon = 0;
      _currentRound = 1;
      _bestMatchTime = 999.9;
    });
    SoundService.instance.play(SoundType.gameStart);
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _phase = 'countdown';
      _countdownValue = 3;
      _ropePosition = 0.0;
      _stamina = _maxStamina;
      _tapCount = 0;
    });

    SoundService.instance.play(SoundType.countdownTick);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        _startRound();
      } else {
        setState(() => _countdownValue--);
        SoundService.instance.play(SoundType.countdownTick);
      }
    });
  }

  void _startRound() {
    _roundStartTime = DateTime.now();
    SoundService.instance.play(SoundType.countdownGo);
    setState(() {
      _phase = 'playing';
      _ropePosition = 0.0;
      _stamina = _maxStamina;
      _tapCount = 0;
      _isPulling = false;
    });

    _gameLoop?.cancel();
    const frameTime = Duration(milliseconds: 16); // ~60fps
    _gameLoop = Timer.periodic(frameTime, _tick);
  }

  void _tick(Timer timer) {
    if (!mounted || _phase != 'playing') {
      timer.cancel();
      return;
    }

    const dt = 1.0 / 60.0; // seconds per frame

    setState(() {
      // AI pulls right
      double aiPull = _aiPullForce * dt;
      // Add some variation to AI pull to make it feel alive
      aiPull += (math.sin(DateTime.now().millisecondsSinceEpoch * 0.003) * 2.0) * dt;
      _ropePosition += aiPull;

      // AI animation pulse
      _aiPullAnim += dt * 4.0;

      // Regenerate stamina
      _stamina = (_stamina + _staminaRegenPerSecond * dt).clamp(0.0, _maxStamina);

      // Shake decay
      _shakeOffset *= 0.85;

      // Check win/lose
      if (_ropePosition >= _winThreshold) {
        // AI wins this round
        _endRound(playerWon: false);
      } else if (_ropePosition <= -_winThreshold) {
        // Player wins this round
        _endRound(playerWon: true);
      }
    });
  }

  void _onPull() {
    if (_phase != 'playing') return;

    HapticFeedback.lightImpact();
    SoundService.instance.play(SoundType.ropePull);

    setState(() {
      _tapCount++;
      _isPulling = true;

      // Calculate pull power based on stamina
      final staminaMultiplier = (_stamina / _maxStamina).clamp(0.1, 1.0);
      final pull = _pullPower * staminaMultiplier;

      _ropePosition -= pull;
      _stamina = (_stamina - _staminaDrainPerTap).clamp(0.0, _maxStamina);

      // Shake effect
      _shakeOffset = (math.Random().nextDouble() - 0.5) * 6.0;
    });

    // Reset pulling visual after brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isPulling = false);
    });
  }

  void _endRound({required bool playerWon}) {
    _gameLoop?.cancel();

    final elapsed = DateTime.now().difference(_roundStartTime!).inMilliseconds / 1000.0;
    _roundDuration = elapsed;

    // Play rope snap at the end of every round
    SoundService.instance.play(SoundType.ropeSnap);

    if (playerWon) {
      _playerRoundsWon++;
      if (elapsed < _bestMatchTime) _bestMatchTime = elapsed;
    } else {
      _aiRoundsWon++;
    }

    if (_playerRoundsWon >= _roundsToWin || _aiRoundsWon >= _roundsToWin) {
      // Match is over
      _endMatch(playerWon: _playerRoundsWon >= _roundsToWin);
    } else {
      setState(() {
        _phase = 'round_over';
        _currentRound++;
      });

      // Auto-start next round after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _phase == 'round_over') _startCountdown();
      });
    }
  }

  void _endMatch({required bool playerWon}) {
    if (playerWon) {
      SoundService.instance.play(SoundType.winFanfare);
      AchievementService.instance.saveTowResult(
        won: true,
        timeInSeconds: _bestMatchTime,
      );
    } else {
      SoundService.instance.play(SoundType.loseSound);
      AchievementService.instance.saveTowResult(won: false);
    }

    setState(() => _phase = 'match_over');
    _loadStats();
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
            SoundService.instance.play(SoundType.buttonBack);
            _gameLoop?.cancel();
            _countdownTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        titleOverride: Text(
          'TUG OF WAR',
          style: GoogleFonts.pressStart2p(
            fontSize: 10,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: CrtOverlay(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'select_difficulty':
        return _buildDifficultySelector();
      case 'countdown':
        return _buildCountdown();
      case 'playing':
        return _buildGameArea();
      case 'round_over':
        return _buildRoundOver();
      case 'match_over':
        return _buildMatchOver();
      default:
        return const SizedBox.shrink();
    }
  }

  // ──────────────────────────────────────────────
  //  DIFFICULTY SELECTOR
  // ──────────────────────────────────────────────
  Widget _buildDifficultySelector() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪢', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              'TUG OF WAR',
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: const Color(0xFFF05A28),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MASH TO PULL THE ROPE!',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'CHOOSE DIFFICULTY',
              style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ...['easy', 'medium', 'hard'].map((diff) {
              final isSelected = _difficulty == diff;
              final descriptions = {
                'easy': 'AI Pull: Gentle',
                'medium': 'AI Pull: Moderate',
                'hard': 'AI Pull: Brutal',
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: 240,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _selectDifficulty(diff),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFF05A28) : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      backgroundColor: isSelected
                          ? const Color(0xFFF05A28).withValues(alpha: 0.1)
                          : const Color(0xFF0D1117),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          diff.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          descriptions[diff]!,
                          style: GoogleFonts.shareTechMono(
                            fontSize: 9,
                            color: isSelected ? const Color(0xFFF05A28) : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              height: 50,
              child: ElevatedButton(
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'START MATCH',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TOTAL WINS: $_totalWins',
              style: GoogleFonts.shareTechMono(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            if (_allTimeBestTime < 999.0) ...[
              const SizedBox(height: 4),
              Text(
                'BEST TIME: ${_allTimeBestTime.toStringAsFixed(1)}s',
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  color: const Color(0xFFF05A28),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  COUNTDOWN
  // ──────────────────────────────────────────────
  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND $_currentRound',
            style: GoogleFonts.pressStart2p(
              fontSize: 14,
              color: const Color(0xFFF05A28),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '$_countdownValue',
            style: GoogleFonts.pressStart2p(
              fontSize: 64,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GET READY!',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  GAME AREA
  // ──────────────────────────────────────────────
  Widget _buildGameArea() {
    final elapsed = DateTime.now().difference(_roundStartTime!).inMilliseconds / 1000.0;

    return Column(
      children: [
        // Top bar: round info + score
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUND $_currentRound / 3',
                style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.textSecondary),
              ),
              Text(
                'YOU $_playerRoundsWon - $_aiRoundsWon AI',
                style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
              ),
            ],
          ),
        ),

        // Round dots
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              Color color;
              if (i < _playerRoundsWon) {
                color = AppColors.success;
              } else if (i < _playerRoundsWon + _aiRoundsWon) {
                color = AppColors.error;
              } else {
                color = Colors.transparent;
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF05A28),
                    width: 1.5,
                  ),
                  color: color,
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        // Time elapsed
        Text(
          '${elapsed.toStringAsFixed(1)}s',
          style: GoogleFonts.shareTechMono(
            fontSize: 18,
            color: const Color(0xFFF05A28),
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 8),

        // Tug of War Field
        Expanded(
          child: Transform.translate(
            offset: Offset(_shakeOffset, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _buildRopeField(constraints.maxWidth, constraints.maxHeight);
                },
              ),
            ),
          ),
        ),

        // Stamina bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STAMINA',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: _stamina < 20 ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${_stamina.toInt()}%',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 7,
                      color: _stamina < 20 ? AppColors.error : const Color(0xFFF05A28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_stamina / _maxStamina).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _stamina < 20
                                ? [AppColors.error, AppColors.error]
                                : [const Color(0xFFF05A28), const Color(0xFFFF7A45)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_stamina < 20) ...[
                const SizedBox(height: 4),
                Text(
                  'LOW STAMINA! PULL POWER REDUCED',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 6,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Tap counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'TAPS: $_tapCount',
            style: GoogleFonts.shareTechMono(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // PULL button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 32.0, right: 32.0),
            child: SizedBox(
              width: double.infinity,
              height: 72,
              child: GestureDetector(
                onTapDown: (_) => _onPull(),
                child: Container(
                  decoration: BoxDecoration(
                    color: _isPulling
                        ? const Color(0xFFFF7A45)
                        : const Color(0xFFF05A28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF05A28).withValues(alpha: _isPulling ? 0.5 : 0.2),
                        blurRadius: _isPulling ? 20 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '💪 PULL! 💪',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRopeField(double width, double height) {
    // Normalize rope position to a visual fraction: -1 (player win) to +1 (AI win)
    final normalizedPos = (_ropePosition / _winThreshold).clamp(-1.0, 1.0);
    final centerX = width / 2;
    final ropeShift = normalizedPos * (width / 2 - 30);

    return CustomPaint(
      painter: _TugFieldPainter(
        ropeShift: ropeShift,
        centerX: centerX,
        height: height,
        aiPullAnim: _aiPullAnim,
        isPulling: _isPulling,
        stamina: _stamina,
      ),
      size: Size(width, height),
    );
  }

  // ──────────────────────────────────────────────
  //  ROUND OVER
  // ──────────────────────────────────────────────
  Widget _buildRoundOver() {
    final playerWonRound = _ropePosition <= -_winThreshold;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            playerWonRound ? 'ROUND WON! 💪' : 'ROUND LOST! 😤',
            style: GoogleFonts.pressStart2p(
              fontSize: 14,
              color: playerWonRound ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (playerWonRound)
            Text(
              'TIME: ${_roundDuration.toStringAsFixed(1)}s',
              style: GoogleFonts.shareTechMono(
                fontSize: 16,
                color: const Color(0xFFF05A28),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'YOU $_playerRoundsWon - $_aiRoundsWon AI',
            style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'NEXT ROUND IN 2s...',
            style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  MATCH OVER
  // ──────────────────────────────────────────────
  Widget _buildMatchOver() {
    final playerWon = _playerRoundsWon >= _roundsToWin;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              playerWon ? 'VICTORY 🏆' : 'DEFEAT 💀',
              style: GoogleFonts.pressStart2p(
                fontSize: 20,
                color: playerWon ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'FINAL SCORE',
              style: GoogleFonts.shareTechMono(
                fontSize: 16,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YOU $_playerRoundsWon  -  $_aiRoundsWon AI',
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            if (playerWon && _bestMatchTime < 999.0) ...[
              const SizedBox(height: 16),
              Text(
                'BEST ROUND: ${_bestMatchTime.toStringAsFixed(1)}s',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFF05A28),
                ),
              ),
              if (_bestMatchTime <= 8.0) ...[
                const SizedBox(height: 8),
                Text(
                  '⚡ SPEEDRUN BONUS! ⚡',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              'TOTAL WINS: $_totalWins',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton(
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'PLAY AGAIN',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  SoundService.instance.play(SoundType.buttonBack);
                  setState(() => _phase = 'select_difficulty');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'BACK TO MENU',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  CUSTOM PAINTER: TUG OF WAR FIELD
// ──────────────────────────────────────────────
class _TugFieldPainter extends CustomPainter {
  final double ropeShift;
  final double centerX;
  final double height;
  final double aiPullAnim;
  final bool isPulling;
  final double stamina;

  _TugFieldPainter({
    required this.ropeShift,
    required this.centerX,
    required this.height,
    required this.aiPullAnim,
    required this.isPulling,
    required this.stamina,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // Ground line
    final groundPaint = Paint()
      ..color = const Color(0xFF26262E)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, midY + 40),
      Offset(size.width, midY + 40),
      groundPaint,
    );

    // Center marker (flag / ribbon)
    final centerMarkerPaint = Paint()
      ..color = const Color(0xFFF05A28)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(centerX, midY - 20),
      Offset(centerX, midY + 40),
      centerMarkerPaint,
    );

    // Win zones
    final leftZonePaint = Paint()
      ..color = const Color(0xFF27C96A).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, midY - 30, 30, midY + 40), leftZonePaint);

    final rightZonePaint = Paint()
      ..color = const Color(0xFFE84040).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(size.width - 30, midY - 30, size.width, midY + 40), rightZonePaint);

    // Rope
    final ropeX = centerX + ropeShift;
    final ropePaint = Paint()
      ..color = const Color(0xFFA08060)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(ropeX - 80, midY),
      Offset(ropeX + 80, midY),
      ropePaint,
    );

    // Rope knots
    final knotPaint = Paint()..color = const Color(0xFF705030);
    for (double kx = -60; kx <= 60; kx += 30) {
      canvas.drawCircle(Offset(ropeX + kx, midY), 5, knotPaint);
    }

    // Center ribbon on rope
    final ribbonPaint = Paint()
      ..color = const Color(0xFFF05A28)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(ropeX, midY), width: 8, height: 18),
      ribbonPaint,
    );

    // Player character (left side)
    final playerX = ropeX - 100;
    final playerBob = isPulling ? -4.0 : 0.0;
    _drawStickFigure(
      canvas,
      Offset(playerX, midY + 10 + playerBob),
      const Color(0xFFF05A28),
      facingRight: true,
    );

    // Player label
    final playerLabelPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: Color(0xFFF05A28),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    playerLabelPainter.paint(canvas, Offset(playerX - 10, midY - 40));

    // AI character (right side)
    final aiX = ropeX + 100;
    final aiBob = math.sin(aiPullAnim) * 3.0;
    _drawStickFigure(
      canvas,
      Offset(aiX, midY + 10 + aiBob),
      const Color(0xFFE84040),
      facingRight: false,
    );

    // AI label
    final aiLabelPainter = TextPainter(
      text: const TextSpan(
        text: 'AI',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: Color(0xFFE84040),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    aiLabelPainter.paint(canvas, Offset(aiX - 5, midY - 40));

    // Position indicator bar at top
    const barY = 20.0;
    final barWidth = size.width - 60;
    const barLeft = 30.0;
    
    // Bar background
    final barBgPaint = Paint()
      ..color = const Color(0xFF0D1117)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY, barWidth, 8),
        const Radius.circular(4),
      ),
      barBgPaint,
    );

    // Bar border
    final barBorderPaint = Paint()
      ..color = const Color(0xFF26262E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY, barWidth, 8),
        const Radius.circular(4),
      ),
      barBorderPaint,
    );

    // Position indicator dot
    final normalized = (ropeShift / (centerX - 30)).clamp(-1.0, 1.0);
    final dotX = barLeft + barWidth / 2 + (normalized * barWidth / 2);
    final dotPaint = Paint()
      ..color = normalized < -0.3
          ? const Color(0xFF27C96A)
          : normalized > 0.3
              ? const Color(0xFFE84040)
              : const Color(0xFFF05A28);
    canvas.drawCircle(Offset(dotX, barY + 4), 6, dotPaint);
  }

  void _drawStickFigure(Canvas canvas, Offset pos, Color color, {required bool facingRight}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Head
    canvas.drawCircle(Offset(pos.dx, pos.dy - 20), 7, paint);

    // Body
    canvas.drawLine(
      Offset(pos.dx, pos.dy - 13),
      Offset(pos.dx, pos.dy + 5),
      paint,
    );

    // Arms reaching toward rope
    final armDir = facingRight ? 1.0 : -1.0;
    canvas.drawLine(
      Offset(pos.dx, pos.dy - 8),
      Offset(pos.dx + armDir * 18, pos.dy - 12),
      paint,
    );
    canvas.drawLine(
      Offset(pos.dx, pos.dy - 4),
      Offset(pos.dx + armDir * 18, pos.dy - 6),
      paint,
    );

    // Legs in pulling stance
    canvas.drawLine(
      Offset(pos.dx, pos.dy + 5),
      Offset(pos.dx - armDir * 10, pos.dy + 22),
      paint,
    );
    canvas.drawLine(
      Offset(pos.dx, pos.dy + 5),
      Offset(pos.dx + armDir * 5, pos.dy + 22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TugFieldPainter oldDelegate) => true;
}
