import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/features/home/domain/game.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail (Placeholder)
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    image: game.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(game.thumbnailUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: game.thumbnailUrl == null
                      ? Center(
                          child: const Icon(
                            Icons.gamepad_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: 2.seconds,
                          ),
                        )
                      : null,
                ),
                if (onEdit != null || onDelete != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        if (onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.8)),
                            onPressed: onEdit,
                          ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: AppColors.error.withOpacity(0.8)),
                            onPressed: onDelete,
                          ),
                        ]
                      ],
                    ),
                  ),
              ],
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${game.creatorName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.fire2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Stats
                  Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${game.playCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.favorite, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${game.likeCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
    );
  }
}
