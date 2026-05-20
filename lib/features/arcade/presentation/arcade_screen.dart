import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

class ArcadeScreen extends StatelessWidget {
  const ArcadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GameForgeAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOLO ARCADE',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontSize: 22,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offline classics tuned for thumb warriors.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.88,
              children: [
                _ArcadeCard(
                  title: 'Snake',
                  emoji: '🐍',
                  subtitle: 'Classic arcade',
                  isAvailable: true,
                  onTap: () => context.push('/arcade/snake'),
                ).animate().fade(duration: 300.ms).slideY(begin: 0.2),
                const _ArcadeCard(
                  title: 'Tetris',
                  emoji: '🧱',
                  subtitle: 'Coming soon',
                  isAvailable: false,
                  onTap: null,
                ).animate(delay: 60.ms).fade(duration: 300.ms).slideY(begin: 0.2),
                const _ArcadeCard(
                  title: 'Breakout',
                  emoji: '🏓',
                  subtitle: 'Coming soon',
                  isAvailable: false,
                  onTap: null,
                ).animate(delay: 120.ms).fade(duration: 300.ms).slideY(begin: 0.2),
                const _ArcadeCard(
                  title: 'Pong',
                  emoji: '🎯',
                  subtitle: 'Coming soon',
                  isAvailable: false,
                  onTap: null,
                ).animate(delay: 180.ms).fade(duration: 300.ms).slideY(begin: 0.2),
              ],
            ),
          ],
        ),
      ),
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

  static final _fireDeep =
      LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.55)]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isAvailable ? 1 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isAvailable
                ? _fireDeep
                : const LinearGradient(
                    colors: [
                      AppColors.card2,
                      AppColors.card,
                    ],
                  ),
            border: Border.all(
              color: isAvailable ? AppColors.fire2.withValues(alpha: 0.65) : AppColors.border,
              width: isAvailable ? 1.8 : 1,
            ),
            boxShadow: isAvailable
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 38)),
                    const Spacer(),
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        color: isAvailable
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: isAvailable
                            ? Colors.white.withValues(alpha: 0.82)
                            : AppColors.textSecondary.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAvailable)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'SOON',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              if (isAvailable)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PLAY',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
