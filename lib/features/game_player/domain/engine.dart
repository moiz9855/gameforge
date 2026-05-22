import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:game_forge/features/game_builder/domain/game_object.dart';
import 'components.dart';

class GameForgeEngine extends FlameGame with HasKeyboardHandlerComponents, HasCollisionDetection {
  final List<GameObject> gameData;
  int score = 0;
  int totalCoins = 0;
  PlayerComponent? player;
  
  final VoidCallback onScoreChanged;
  final VoidCallback onWin;

  GameForgeEngine({
    required this.gameData,
    required this.onScoreChanged,
    required this.onWin,
  });

  @override
  Color backgroundColor() => const Color(0xFF0F0F13); // AppColors.background

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    for (final obj in gameData) {
      final pos = Vector2(obj.x, obj.y);
      final size = Vector2(obj.width, obj.height);

      switch (obj.type) {
        case GameObjectType.player:
          player = PlayerComponent(startPosition: pos, size: size);
          add(player!);
          break;
        case GameObjectType.platform:
          add(PlatformComponent(position: pos, size: size));
          break;
        case GameObjectType.coin:
          add(CoinComponent(position: pos, size: size));
          totalCoins++;
          break;
        case GameObjectType.obstacle:
          add(ObstacleComponent(position: pos, size: size));
          break;
        case GameObjectType.enemy:
        case GameObjectType.spring:
        case GameObjectType.key:
        case GameObjectType.door:
          // Implement physical engine components for these types in a future update
          break;
      }
    }
  }

  void incrementScore() {
    score++;
    onScoreChanged();
    if (score >= totalCoins && totalCoins > 0) {
      onWin();
    }
  }

  // Mobile virtual button controls
  void jump() => player?.jump();
  void moveLeft(bool moving) => player?.moveLeft(moving);
  void moveRight(bool moving) => player?.moveRight(moving);
}
