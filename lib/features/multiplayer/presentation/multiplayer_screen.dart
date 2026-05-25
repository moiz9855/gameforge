import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

/// Chess + Cyber Ludo entry points only — visuals only; routing unchanged per game.
class MultiplayerScreen extends StatelessWidget {
  const MultiplayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GameForgeAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'MULTIPLAYER',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontSize: 26,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Challenge friends in curated competitive modes.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          _MultiGameRowCard(
            title: 'Chess',
            subtitle: 'Strategic 1v1 · synced clocks',
            icon: Icons.grid_4x4_rounded,
            tint: AppColors.chessTint,
            onTap: () => context.push('/chess-lobby'),
          ),
          const SizedBox(height: 16),
          _MultiGameRowCard(
            title: 'Cyber Ludo',
            subtitle: 'Digital chaos · 2-4 pilots',
            icon: Icons.casino_rounded,
            tint: AppColors.ludoTint,
            onTap: () => context.push('/ludo-lobby'),
          ),
          const SizedBox(height: 16),
          _MultiGameRowCard(
            title: 'UNO 🃏',
            subtitle: 'Colors & action cards · 2-4 players',
            icon: Icons.style_rounded,
            tint: Colors.redAccent,
            onTap: () => context.push('/uno-lobby'),
          ),
          const SizedBox(height: 16),
          _MultiGameRowCard(
            title: 'Draw & Guess ✏️',
            subtitle: 'Doodle & chat guess live · 2-8 players',
            icon: Icons.gesture_rounded,
            tint: Colors.cyanAccent,
            onTap: () => context.push('/draw-lobby'),
          ),
          const SizedBox(height: 16),
          _MultiGameRowCard(
            title: 'Trivia Quiz ❓',
            subtitle: '1v1 speed battle · 10 questions',
            icon: Icons.quiz_rounded,
            tint: Colors.amberAccent,
            onTap: () => context.push('/trivia-lobby'),
          ),
          const SizedBox(height: 16),
          _MultiGameRowCard(
            title: 'Meme Battle 😂',
            subtitle: '3-8 Players · Caption battle',
            icon: Icons.emoji_emotions_rounded,
            tint: const Color(0xFFF05A28),
            onTap: () => context.push('/meme-lobby'),
          ),
        ],
      ),
    );
  }
}

class _MultiGameRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _MultiGameRowCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tint.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, color: tint, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          letterSpacing: 1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: tint.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
