import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'package:game_forge/core/services/sound_service.dart';

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  int _activeTab = 0; // 0 = Games, 1 = Trophies/Achievements
  List<Achievement> _achievements = [];
  
  // Game high scores
  int _snakeHighScore = 0;
  int _tetrisHighScore = 0;
  int _pongHighScore = 0;
  int _flappyHighScore = 0;

  @override
  void initState() {
    super.initState();
    _checkCoin();
    _loadData();
  }

  Future<void> _checkCoin() async {
    final coin = await AchievementService.instance.isCoinInserted();
    if (!coin && mounted) {
      context.push('/arcade/startup').then((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    final service = AchievementService.instance;
    await service.init();
    
    final achievements = service.getAchievements();
    final snakeHs = await service.getHighScore('snake');
    final tetrisHs = await service.getHighScore('tetris');
    final pongHs = await service.getHighScore('pong');
    final flappyHs = await service.getHighScore('flappy');

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _snakeHighScore = snakeHs;
        _tetrisHighScore = tetrisHs;
        _pongHighScore = pongHs;
        _flappyHighScore = flappyHs;
      });
    }
  }

  Future<void> _resetProgress() async {
    // Show confirmation dialog in retro styling
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF05A28), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WARNING',
                style: GoogleFonts.pressStart2p(
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reset all high scores and unlocked achievements?',
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textSecondary),
                    ),
                    child: Text('CANCEL', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: Text('RESET', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await AchievementService.instance.resetAll();
      SoundService.instance.play(SoundType.gameOver);
      HapticFeedback.vibrate();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GameForgeAppBar(),
      body: CrtOverlay(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Retro Cabinet Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GF-ARCADE CABINET',
                        style: GoogleFonts.pressStart2p(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFFF05A28), // GameForge Orange
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '100% OFFLINE RETRO SYSTEM',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Color(0xFFF05A28)),
                    onPressed: () {
                      SoundService.instance.toggleMute();
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF0D1117),
                          content: Text(
                            SoundService.instance.isMuted ? 'SOUND MUTED' : 'SOUND ENABLED',
                            style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Segmented Tab Selector
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeTab = 0);
                          SoundService.instance.play(SoundType.tetrisMove);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? const Color(0xFFF05A28) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'GAMES',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 9,
                                color: _activeTab == 0 ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeTab = 1);
                          SoundService.instance.play(SoundType.tetrisMove);
                          _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? const Color(0xFFF05A28) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'TROPHIES',
                              style: GoogleFonts.pressStart2p(
                                fontSize: 9,
                                color: _activeTab == 1 ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Body content based on selected tab
              _activeTab == 0 ? _buildGamesGrid() : _buildAchievementsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 0.86,
      children: [
        _ArcadeCard(
          title: 'Snake',
          emoji: '🐍',
          subtitle: 'Best: $_snakeHighScore',
          isAvailable: true,
          onTap: () => context.push('/arcade/snake').then((_) => _loadData()),
        ).animate().fade(duration: 250.ms).slideY(begin: 0.15),
        _ArcadeCard(
          title: 'Tetris',
          emoji: '🧱',
          subtitle: 'Best: $_tetrisHighScore',
          isAvailable: true,
          onTap: () => context.push('/arcade/tetris').then((_) => _loadData()),
        ).animate(delay: 50.ms).fade(duration: 250.ms).slideY(begin: 0.15),
        _ArcadeCard(
          title: 'Flappy Bird',
          emoji: '🐤',
          subtitle: 'Best: $_flappyHighScore',
          isAvailable: true,
          onTap: () => context.push('/arcade/flappy').then((_) => _loadData()),
        ).animate(delay: 100.ms).fade(duration: 250.ms).slideY(begin: 0.15),
        _ArcadeCard(
          title: 'Pong',
          emoji: '🏓',
          subtitle: 'Best Margin: $_pongHighScore',
          isAvailable: true,
          onTap: () => context.push('/arcade/pong').then((_) => _loadData()),
        ).animate(delay: 150.ms).fade(duration: 250.ms).slideY(begin: 0.15),
      ],
    );
  }

  Widget _buildAchievementsList() {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UNLOCKED: $unlockedCount / ${_achievements.length}',
              style: GoogleFonts.pressStart2p(
                fontSize: 9,
                color: const Color(0xFFF05A28),
              ),
            ),
            GestureDetector(
              onTap: _resetProgress,
              child: Text(
                'RESET ALL',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _achievements.length,
          itemBuilder: (context, index) {
            final a = _achievements[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: a.isUnlocked
                      ? const Color(0xFFF05A28).withOpacity(0.55)
                      : AppColors.border,
                  width: a.isUnlocked ? 1.5 : 1.0,
                ),
                boxShadow: a.isUnlocked
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF05A28).withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Badge / Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.isUnlocked
                          ? const Color(0xFFF05A28).withOpacity(0.15)
                          : Colors.grey.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        a.isUnlocked ? a.badge : '🔒',
                        style: TextStyle(fontSize: a.isUnlocked ? 22 : 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            fontSize: 9,
                            color: a.isUnlocked ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.description,
                          style: GoogleFonts.rajdhani(
                            color: a.isUnlocked
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 200.ms);
          },
        ),
      ],
    );
  }
}

class _ArcadeCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String subtitle;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _ArcadeCard({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0D1117),
          border: Border.all(
            color: const Color(0xFFF05A28).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF05A28).withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 34)),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.pressStart2p(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.shareTechMono(
                      color: const Color(0xFFF05A28),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF05A28).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PLAY',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 7,
                    color: const Color(0xFFF05A28),
                    fontWeight: FontWeight.bold,
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
