import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import '../../game_builder/domain/game_object.dart';
import '../domain/engine.dart';

final gameDataProvider = FutureProvider.family<List<GameObject>, String>((ref, gameId) async {
  final response = await Supabase.instance.client
      .from('games')
      .select('game_data')
      .eq('id', gameId)
      .single();

  final dataList = response['game_data'] as List;
  return dataList.map((json) => GameObject.fromJson(json)).toList();
});

class PlayerScreen extends ConsumerStatefulWidget {
  final String gameId;
  const PlayerScreen({super.key, required this.gameId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  GameForgeEngine? _game;
  int _score = 0;
  bool _hasWon = false;

  void _onScoreChanged() {
    setState(() {
      _score = _game?.score ?? 0;
    });
  }

  void _onWin() {
    setState(() {
      _hasWon = true;
    });
  }

  void _initGame(List<GameObject> data) {
    _game ??= GameForgeEngine(
      gameData: data,
      onScoreChanged: _onScoreChanged,
      onWin: _onWin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameDataAsync = ref.watch(gameDataProvider(widget.gameId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: gameDataAsync.when(
        data: (data) {
          _initGame(data);

          return Stack(
            children: [
              // Flame Engine
              GameWidget(game: _game!),

              // Score Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.go('/'),
                      ),
                      Text(
                        'SCORE: $_score',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.gold,
                          fontSize: 22,
                          shadows: [
                            Shadow(color: AppColors.primary.withValues(alpha: 0.55), blurRadius: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Virtual Controls (Bottom)
              Positioned(
                bottom: 32,
                left: 32,
                right: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left / Right
                    Row(
                      children: [
                        _ControlButton(
                          icon: Icons.arrow_back,
                          onPointerDown: () => _game?.moveLeft(true),
                          onPointerUp: () => _game?.moveLeft(false),
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.arrow_forward,
                          onPointerDown: () => _game?.moveRight(true),
                          onPointerUp: () => _game?.moveRight(false),
                        ),
                      ],
                    ),
                    // Jump
                    _ControlButton(
                      icon: Icons.arrow_upward,
                      onPointerDown: () => _game?.jump(),
                      onPointerUp: () {},
                      color: AppColors.fire2,
                    ),
                  ],
                ),
              ),

              // Win Overlay
              if (_hasWon)
                Container(
                  color: AppColors.background.withValues(alpha: 0.9),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'YOU WIN! 🎉',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppColors.success,
                            shadows: [
                              const Shadow(color: AppColors.success, blurRadius: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Final Score: $_score',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => context.go('/'),
                          child: const Text('BACK TO LOBBY'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.onPointerDown,
    required this.onPointerUp,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onPointerDown(),
      onPointerUp: (_) => onPointerUp(),
      onPointerCancel: (_) => onPointerUp(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
