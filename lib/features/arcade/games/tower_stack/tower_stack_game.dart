import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum TSGameState { playing, gameOver }

class TowerStackGame extends FlameGame {
  final void Function(int score, int height, int bestScore)? onStateUpdate;
  final void Function(int score, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int towerHeight = 0;
  TSGameState state = TSGameState.playing;

  final List<BlockComponent> blocks = [];
  late SwingingBlock currentBlock;
  double cameraY = 0;
  double currentWidth = 100;

  TowerStackGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    _startGame();
  }

  void _startGame() {
    score = 0;
    towerHeight = 0;
    currentWidth = 100;
    state = TSGameState.playing;
    
    for (var b in blocks) { b.removeFromParent(); }
    blocks.clear();
    
    // Base block
    final base = BlockComponent(gameRef: this, position: Vector2(size.x/2, size.y - 20), size: Vector2(100, 40));
    blocks.add(base);
    add(base);
    
    cameraY = size.y - 60;
    _spawnBlock();
    
    onStateUpdate?.call(score, towerHeight, bestScore);
  }

  void restart() {
    currentBlock.removeFromParent();
    _startGame();
  }

  void _spawnBlock() {
    final speed = 100.0 + min(towerHeight, 20) * 10.0;
    currentBlock = SwingingBlock(
      gameRef: this,
      startPos: Vector2(size.x/2, cameraY - 150),
      blockWidth: currentWidth,
      speed: speed,
    );
    add(currentBlock);
  }

  void handleTap() {
    if (state != TSGameState.playing) return;
    
    final lastBlock = blocks.last;
    final lastX = lastBlock.position.x;
    final currX = currentBlock.position.x;
    
    final diff = currX - lastX;
    
    if (diff.abs() > currentWidth) {
      // Missed completely
      SoundService.instance.play(SoundType.wallHit);
      state = TSGameState.gameOver;
      currentBlock.fall();
      
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onGameOver?.call(score, isRecord);
      return;
    }
    
    if (diff.abs() < 5) {
      // Perfect match
      SoundService.instance.play(SoundType.coin);
      score += 50;
      currentBlock.position.x = lastX; // Align perfectly
    } else {
      SoundService.instance.play(SoundType.runnerStep);
      score += 10;
      currentWidth -= diff.abs();
      if (diff > 0) {
        currentBlock.position.x -= diff.abs()/2; // shift left
      } else {
        currentBlock.position.x += diff.abs()/2; // shift right
      }
      currentBlock.size.x = currentWidth;
    }
    
    currentBlock.isSwinging = false;
    currentBlock.position.y = lastBlock.position.y - 40;
    
    final newBlock = BlockComponent(
      gameRef: this,
      position: currentBlock.position.clone(),
      size: currentBlock.size.clone(),
    );
    blocks.add(newBlock);
    add(newBlock);
    
    currentBlock.removeFromParent();
    
    towerHeight++;
    cameraY -= 40;
    
    // Move camera down smoothly
    for (var b in blocks) {
      b.targetY = b.position.y + 40;
    }
    
    _spawnBlock();
    onStateUpdate?.call(score, towerHeight, bestScore);
  }
}

class BlockComponent extends PositionComponent {
  final TowerStackGame gameRef;
  double? targetY;

  BlockComponent({required this.gameRef, required super.position, required super.size})
      : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (targetY != null) {
      position.y += (targetY! - position.y) * 10 * dt;
      if ((targetY! - position.y).abs() < 1) {
        position.y = targetY!;
        targetY = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final r = Rect.fromCenter(center: Offset(size.x/2, size.y/2), width: size.x, height: size.y);
    canvas.drawRect(r, Paint()..color = const Color(0xFFF05A28));
    canvas.drawRect(r, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

class SwingingBlock extends PositionComponent {
  final TowerStackGame gameRef;
  final double speed;
  double _time = 0;
  bool isSwinging = true;
  double fallSpeed = 0;

  SwingingBlock({
    required this.gameRef,
    required Vector2 startPos,
    required double blockWidth,
    required this.speed,
  }) : super(position: startPos, size: Vector2(blockWidth, 40), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (isSwinging) {
      _time += dt;
      x = gameRef.size.x/2 + sin(_time * speed * 0.02) * (gameRef.size.x/2 - size.x/2);
    } else {
      fallSpeed += 500 * dt;
      position.y += fallSpeed * dt;
    }
  }

  void fall() {
    isSwinging = false;
  }

  @override
  void render(Canvas canvas) {
    final r = Rect.fromCenter(center: Offset(size.x/2, size.y/2), width: size.x, height: size.y);
    canvas.drawRect(r, Paint()..color = const Color(0xFF4FC3F7));
    canvas.drawRect(r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}
