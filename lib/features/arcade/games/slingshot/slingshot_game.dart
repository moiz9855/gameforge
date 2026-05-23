import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum SBGameState { ready, aiming, shooting, levelComplete, gameOver }
enum BallType { normal, heavy, split, bomb, boomerang }

class SlingshotGame extends FlameGame with PanDetector {
  final void Function(int score, int balls, int level)? onStateUpdate;
  final void Function(int score, int levelsCompleted, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int currentLevel = 1;
  int ballsLeft = 3;
  SBGameState state = SBGameState.ready;
  
  late Vector2 slingPos;
  Vector2? dragStart;
  Vector2? dragCurrent;
  
  BallType currentBallType = BallType.normal;
  SlingshotBall? activeBall;
  final List<BlockComponent> blocks = [];
  final List<EnemyPig> enemies = [];

  SlingshotGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    slingPos = Vector2(80, size.y - 100);
    _loadLevel();
  }

  void _loadLevel() {
    state = SBGameState.ready;
    ballsLeft = 3;
    
    // Setup ball type
    if (currentLevel > 15) currentBallType = BallType.bomb;
    else if (currentLevel > 10) currentBallType = BallType.heavy;
    else if (currentLevel > 5) currentBallType = BallType.split;
    else currentBallType = BallType.normal;
    
    activeBall?.removeFromParent();
    activeBall = null;
    
    for (var b in blocks) { b.removeFromParent(); }
    blocks.clear();
    for (var e in enemies) { e.removeFromParent(); }
    enemies.clear();
    
    // Generate simple structure
    final numCols = min(3 + currentLevel ~/ 5, 6);
    final numRows = min(2 + currentLevel ~/ 3, 5);
    final startX = size.x - 50 - (numCols * 40);
    
    for (int r = 0; r < numRows; r++) {
      for (int c = 0; c < numCols; c++) {
        // Place blocks and enemies
        if (Random().nextDouble() > 0.2) {
           final b = BlockComponent(gameRef: this, position: Vector2(startX + c * 40, size.y - 40 - r * 40));
           blocks.add(b);
           add(b);
        } else {
           final e = EnemyPig(gameRef: this, position: Vector2(startX + c * 40, size.y - 40 - r * 40));
           enemies.add(e);
           add(e);
        }
      }
    }
    
    // Ensure at least one enemy
    if (enemies.isEmpty) {
      final e = EnemyPig(gameRef: this, position: Vector2(startX, size.y - 40));
      enemies.add(e);
      add(e);
    }
    
    onStateUpdate?.call(score, ballsLeft, currentLevel);
  }

  void startGame() {
    score = 0;
    currentLevel = 1;
    _loadLevel();
  }

  void nextLevel() {
    currentLevel++;
    _loadLevel();
  }

  @override
  void onPanDown(DragDownInfo info) {
    if (state != SBGameState.ready) return;
    state = SBGameState.aiming;
    dragStart = info.eventPosition.global;
    dragCurrent = dragStart;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (state != SBGameState.aiming) return;
    dragCurrent = info.eventPosition.global;
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (state != SBGameState.aiming) return;
    
    if (dragStart != null && dragCurrent != null) {
      final diff = dragStart! - dragCurrent!;
      if (diff.length > 20) {
        final velocity = diff * 3.0; // Shoot forward
        _shoot(velocity);
      } else {
        state = SBGameState.ready;
      }
    }
    dragStart = null;
    dragCurrent = null;
  }

  void _shoot(Vector2 initialVelocity) {
    state = SBGameState.shooting;
    ballsLeft--;
    onStateUpdate?.call(score, ballsLeft, currentLevel);
    SoundService.instance.play(SoundType.runnerJump);
    
    activeBall = SlingshotBall(
      gameRef: this,
      startPos: slingPos.clone(),
      velocity: initialVelocity,
      type: currentBallType,
    );
    add(activeBall!);
  }

  void onEnemyDestroyed() {
    score += 500;
    SoundService.instance.play(SoundType.coin);
    onStateUpdate?.call(score, ballsLeft, currentLevel);
  }

  void onBlockDestroyed() {
    score += 50;
    onStateUpdate?.call(score, ballsLeft, currentLevel);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (state == SBGameState.shooting) {
      // Check win condition
      enemies.removeWhere((e) => e.isDead);
      if (enemies.isEmpty) {
        state = SBGameState.levelComplete;
        SoundService.instance.play(SoundType.winFanfare);
        onStateUpdate?.call(score, ballsLeft, currentLevel);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (isMounted) nextLevel();
        });
      }
    }
  }

  void onBallStopped() {
    if (state != SBGameState.shooting) return;
    
    activeBall?.removeFromParent();
    activeBall = null;
    
    if (enemies.isNotEmpty) {
      if (ballsLeft <= 0) {
        state = SBGameState.gameOver;
        final isRecord = score > bestScore;
        if (isRecord) bestScore = score;
        onGameOver?.call(score, currentLevel, isRecord);
      } else {
        state = SBGameState.ready;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw Slingshot
    final p = Paint()..color = Colors.brown..strokeWidth = 6;
    canvas.drawLine(Offset(slingPos.x, slingPos.y + 40), Offset(slingPos.x, slingPos.y), p);
    canvas.drawLine(Offset(slingPos.x, slingPos.y), Offset(slingPos.x - 15, slingPos.y - 20), p);
    canvas.drawLine(Offset(slingPos.x, slingPos.y), Offset(slingPos.x + 15, slingPos.y - 20), p);
    
    // Draw elastic band
    if (state == SBGameState.aiming && dragStart != null && dragCurrent != null) {
      final pull = dragStart! - dragCurrent!;
      pull.clamp(Vector2(-60, -60), Vector2(60, 60));
      final pullPos = slingPos - pull;
      final bandP = Paint()..color = const Color(0xFFE57373)..strokeWidth = 3;
      canvas.drawLine(Offset(slingPos.x - 15, slingPos.y - 20), pullPos.toOffset(), bandP);
      canvas.drawLine(Offset(slingPos.x + 15, slingPos.y - 20), pullPos.toOffset(), bandP);
      
      _drawTrajectory(canvas, pull * 3.0);
    }
  }

  void _drawTrajectory(Canvas canvas, Vector2 initVel) {
    final p = Paint()..color = const Color(0xFFF05A28).withValues(alpha: 0.5);
    Vector2 pos = slingPos.clone();
    Vector2 vel = initVel.clone();
    
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(pos.toOffset(), 2, p);
      vel.y += 400 * 0.05; // Gravity
      pos += vel * 0.05;
      if (pos.y > size.y || pos.x < 0 || pos.x > size.x) break;
    }
  }
}

class SlingshotBall extends PositionComponent {
  final SlingshotGame gameRef;
  Vector2 velocity;
  final BallType type;
  bool hasStopped = false;
  double restTimer = 0;

  SlingshotBall({
    required this.gameRef,
    required Vector2 startPos,
    required this.velocity,
    required this.type,
  }) : super(position: startPos, size: Vector2.all(20), anchor: Anchor.center);

  @override
  void update(double dt) {
    if (hasStopped) return;
    super.update(dt);

    velocity.y += 400 * dt; // Gravity
    position += velocity * dt;

    // Floor collision
    if (position.y > gameRef.size.y - 20) {
      position.y = gameRef.size.y - 20;
      velocity.y *= -0.4;
      velocity.x *= 0.8;
    }

    if (velocity.length < 10) {
      restTimer += dt;
      if (restTimer > 1.0) {
        hasStopped = true;
        gameRef.onBallStopped();
      }
    } else {
      restTimer = 0;
    }

    // AABB Collision with blocks and enemies
    final rect = toRect();
    for (var b in gameRef.blocks) {
      if (!b.isDead && rect.overlaps(b.toRect())) {
        velocity.x *= 0.5;
        b.takeDamage(type == BallType.heavy ? 100 : 50);
      }
    }
    for (var e in gameRef.enemies) {
      if (!e.isDead && rect.overlaps(e.toRect())) {
        velocity.x *= 0.5;
        e.takeDamage(100);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    Color c = Colors.red;
    switch (type) {
      case BallType.normal: c = Colors.red; break;
      case BallType.heavy: c = Colors.black; break;
      case BallType.split: c = Colors.blue; break;
      case BallType.bomb: c = Colors.black87; break;
      case BallType.boomerang: c = Colors.green; break;
    }
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, Paint()..color = c);
  }
}

class BlockComponent extends PositionComponent {
  final SlingshotGame gameRef;
  double hp = 100;
  bool isDead = false;

  BlockComponent({required this.gameRef, required super.position})
      : super(size: Vector2(38, 38), anchor: Anchor.center);

  void takeDamage(double amount) {
    hp -= amount;
    if (hp <= 0 && !isDead) {
      isDead = true;
      gameRef.onBlockDestroyed();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.brown.shade300);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.brown.shade700..style = PaintingStyle.stroke..strokeWidth=2);
  }
}

class EnemyPig extends PositionComponent {
  final SlingshotGame gameRef;
  double hp = 50;
  bool isDead = false;

  EnemyPig({required this.gameRef, required super.position})
      : super(size: Vector2(30, 30), anchor: Anchor.center);

  void takeDamage(double amount) {
    hp -= amount;
    if (hp <= 0 && !isDead) {
      isDead = true;
      gameRef.onEnemyDestroyed();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, Paint()..color = Colors.green);
    // Eyes
    canvas.drawCircle(Offset(size.x*0.3, size.y*0.3), 3, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.x*0.7, size.y*0.3), 3, Paint()..color = Colors.white);
    // Snout
    canvas.drawOval(Rect.fromCenter(center: Offset(size.x/2, size.y*0.6), width: 12, height: 8), Paint()..color = Colors.lightGreen);
  }
}
