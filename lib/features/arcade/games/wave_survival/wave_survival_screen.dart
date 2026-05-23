import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'wave_survival_game.dart';

class WaveSurvivalScreen extends StatefulWidget {
  const WaveSurvivalScreen({super.key});

  @override
  State<WaveSurvivalScreen> createState() => _WaveSurvivalScreenState();
}

class _WaveSurvivalScreenState extends State<WaveSurvivalScreen> {
  WaveSurvivalGame? _game;
  WSGameState _state = WSGameState.setup;
  int _level = 1;
  int _wave = 1;
  int _score = 0;
  int _bestScore = 0;
  List<HeroClass> _draft = [];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    final hs = await AchievementService.instance.getHighScore('wave_survival');
    if (!mounted) return;

    final game = WaveSurvivalGame(
      bestScore: hs,
      onStateUpdate: (level, wave, state) {
        if (mounted) {
          setState(() {
            _level = level;
            _wave = wave;
            _state = state;
            _score = _game?.score ?? 0;
          });
        }
      },
      onGameOver: (score, levels, isNewRecord) {
        if (mounted) {
          AchievementService.instance.saveHighScore('wave_survival', score);
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

  void _toggleHero(HeroClass h) {
    setState(() {
      if (_draft.contains(h)) {
        _draft.remove(h);
      } else {
        if (_draft.length < 3) _draft.add(h);
      }
    });
  }

  void _startLevel() {
    if (_draft.length != 3) return;
    _game?.startLevel(_draft);
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

              if (_state == WSGameState.playing)
                IgnorePointer(child: _buildHud()),

              if (_state == WSGameState.setup) _buildSetupOverlay(),
              if (_state == WSGameState.levelComplete) _buildCompleteOverlay(),
              if (_state == WSGameState.gameOver) _buildGameOverOverlay(),

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text('SCORE', style: GoogleFonts.pressStart2p(fontSize: 6, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text('$_score', style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 32),
              Text('LEVEL $_level', style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFF05A28))),
              const SizedBox(height: 4),
              Text('WAVE $_wave/10', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetupOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('LEVEL $_level', style: GoogleFonts.pressStart2p(fontSize: 18, color: const Color(0xFFF05A28))),
            const SizedBox(height: 20),
            Text('DRAFT 3 HEROES', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: HeroClass.values.map((h) {
                final isSelected = _draft.contains(h);
                return GestureDetector(
                  onTap: () => _toggleHero(h),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF05A28).withValues(alpha: 0.3) : const Color(0xFF1A1A24),
                      border: Border.all(color: isSelected ? const Color(0xFFF05A28) : Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🗡️', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(h.name.toUpperCase(), style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _draft.length == 3 ? _startLevel : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
              child: Text('FIGHT!', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('LEVEL CLEARED', style: GoogleFonts.pressStart2p(fontSize: 20, color: Colors.green)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _game?.nextLevel(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
              child: Text('NEXT LEVEL', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('DEFEAT', style: GoogleFonts.pressStart2p(fontSize: 24, color: AppColors.error)),
            const SizedBox(height: 20),
            Text('SCORE: $_score', style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _game?.startGame();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
              child: Text('RETRY', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
