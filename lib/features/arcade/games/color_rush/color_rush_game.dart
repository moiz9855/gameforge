import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum CRGameState { setup, playing, gameOver }

class ColorRushGame extends FlameGame {
  final void Function(int score, int combo, int bestScore)? onStateUpdate;
  final void Function(int score, bool newRecord)? onGameOver;

  int bestScore;
  int score = 0;
  int combo = 0;
  CRGameState state = CRGameState.setup;

  late WheelComponent wheel;
  double spawnTimer = 0;
  double spawnInterval = 2.0;

  final List<Color> colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];

  ColorRushGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    wheel = WheelComponent(gameRef: this, position: Vector2(size.x / 2, size.y - 120));
    add(wheel);
  }

  void startGame() {
    state = CRGameState.playing;
    score = 0;
    combo = 0;
    spawnInterval = 2.0;
    spawnTimer = 0;
    for (var b in children.whereType<FallingBall>()) { b.removeFromParent(); }
    onStateUpdate?.call(score, combo, bestScore);
  }

  void restart() => startGame();

  void handleTap(Offset pos) {
    if (state != CRGameState.playing) return;
    final touchX = pos.dx;
    if (touchX < size.x / 2) {
      wheel.rotate(-pi / 2); // Counter-clockwise
    } else {
      wheel.rotate(pi / 2); // Clockwise
    }
  }

  @override
  void update(double dt) {
    if (state != CRGameState.playing) return;
    super.update(dt);
    
    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      spawnInterval = max(0.5, spawnInterval - 0.05);
      
      final color = colors[Random().nextInt(colors.length)];
      add(FallingBall(gameRef: this, position: Vector2(size.x / 2, -20), color: color, speed: 150 + (2.0 - spawnInterval) * 100));
    }
  }

  void onBallCaught(Color ballColor) {
    final topColor = wheel.getTopColor();
    if (ballColor == topColor) {
      combo++;
      score += 10 * combo;
      SoundService.instance.play(SoundType.coin);
      onStateUpdate?.call(score, combo, bestScore);
    } else {
      SoundService.instance.play(SoundType.wallHit);
      state = CRGameState.gameOver;
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onStateUpdate?.call(score, combo, bestScore);
      onGameOver?.call(score, isRecord);
    }
  }
}

class WheelComponent extends PositionComponent {
  final ColorRushGame gameRef;
  double targetAngle = 0;

  WheelComponent({required this.gameRef, required super.position})
      : super(size: Vector2.all(120), anchor: Anchor.center);

  void rotate(double angleDelta) {
    targetAngle += angleDelta;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Smooth rotation
    final diff = targetAngle - angle;
    angle += diff * 10 * dt;
  }

  Color getTopColor() {
    // Current logical top based on targetAngle
    // Base layout: Top=Red(0), Right=Blue(pi/2), Bottom=Yellow(pi), Left=Green(3pi/2)
    // When we rotate by angle, the top color shifts.
    double normalized = targetAngle % (2 * pi);
    if (normalized < 0) normalized += 2 * pi;
    
    if (normalized < pi/4 || normalized >= 7*pi/4) return Colors.red;
    if (normalized >= pi/4 && normalized < 3*pi/4) return Colors.green; // Left color moves to top
    if (normalized >= 3*pi/4 && normalized < 5*pi/4) return Colors.yellow; // Bottom color moves to top
    return Colors.blue; // Right color moves to top
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: cx);
    
    // Draw 4 segments.
    // Base: 
    // -pi/4 to pi/4 : Red (Top) -> Actually in flutter drawArc 0 is Right. 
    // So -3pi/4 to -pi/4 is Top.
    canvas.drawArc(rect, -3*pi/4, pi/2, true, Paint()..color = Colors.red); // Top
    canvas.drawArc(rect, -pi/4, pi/2, true, Paint()..color = Colors.blue); // Right
    canvas.drawArc(rect, pi/4, pi/2, true, Paint()..color = Colors.yellow); // Bottom
    canvas.drawArc(rect, 3*pi/4, pi/2, true, Paint()..color = Colors.green); // Left
    
    // Inner hole
    canvas.drawCircle(Offset(cx, cy), cx * 0.4, Paint()..color = const Color(0xFF080809));
  }
}

class FallingBall extends PositionComponent {
  final ColorRushGame gameRef;
  final Color color;
  final double speed;
  bool isCaught = false;

  FallingBall({
    required this.gameRef,
    required super.position,
    required this.color,
    required this.speed,
  }) : super(size: Vector2.all(24), anchor: Anchor.center);

  @override
  void update(double dt) {
    if (isCaught) return;
    super.update(dt);
    
    position.y += speed * dt;
    
    // Check collision with wheel top
    final wheelTopY = gameRef.wheel.position.y - gameRef.wheel.size.y / 2;
    if (position.y + size.y / 2 >= wheelTopY) {
      isCaught = true;
      gameRef.onBallCaught(color);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, Paint()..color = color);
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth=2);
  }
}
