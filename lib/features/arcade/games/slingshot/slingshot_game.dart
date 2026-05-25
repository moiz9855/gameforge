import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum SBGameState { ready, aiming, shooting, levelComplete, gameOver }
enum BallType { normal, heavy, split, bomb, bounce }

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
  final List<SlingshotBall> activeBalls = [];
  final List<BlockComponent> blocks = [];
  final List<EnemyPig> enemies = [];

  SlingshotGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    slingPos = Vector2(80, size.y - 120);
    _loadLevel();
  }

  void _loadLevel() {
    state = SBGameState.ready;
    ballsLeft = 3;
    
    // Cycle ball types through levels
    final ballTypes = [BallType.normal, BallType.split, BallType.heavy, BallType.bounce, BallType.bomb];
    currentBallType = ballTypes[(currentLevel - 1) % ballTypes.length];
    
    for (var b in activeBalls) { b.removeFromParent(); }
    activeBalls.clear();
    
    for (var b in blocks) { b.removeFromParent(); }
    blocks.clear();
    for (var e in enemies) { e.removeFromParent(); }
    enemies.clear();
    
    // Generate structure based on level
    final numCols = min(3 + currentLevel ~/ 8, 6);
    final numRows = min(2 + currentLevel ~/ 6, 5);
    final startX = size.x - 40 - (numCols * 42);
    
    final blockHp = 60.0 + currentLevel * 3.0;
    final pigHp = 40.0 + currentLevel * 4.0;
    
    for (int r = 0; r < numRows; r++) {
      for (int c = 0; c < numCols; c++) {
        final pos = Vector2(startX + c * 42, size.y - 40 - r * 42);
        if (Random().nextDouble() > 0.25) {
           final b = BlockComponent(gameRef: this, position: pos, maxHp: blockHp);
           blocks.add(b);
           add(b);
        } else {
           final e = EnemyPig(gameRef: this, position: pos, maxHp: pigHp);
           enemies.add(e);
           add(e);
        }
      }
    }
    
    // Ensure at least one enemy
    if (enemies.isEmpty) {
      final e = EnemyPig(gameRef: this, position: Vector2(startX + 42, size.y - 40), maxHp: pigHp);
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
    currentLevel = min(75, currentLevel + 1);
    _loadLevel();
  }

  @override
  void onPanDown(DragDownInfo info) {
    if (state == SBGameState.shooting) {
      // Split ball ability trigger
      final splitable = activeBalls.where((b) => b.type == BallType.split && !b.hasSplit).toList();
      if (splitable.isNotEmpty) {
        SoundService.instance.play(SoundType.runnerJump);
        final baseBall = splitable.first;
        baseBall.hasSplit = true;
        
        final vel1 = baseBall.velocity.clone()..rotate(-0.25);
        final vel2 = baseBall.velocity.clone()..rotate(0.25);
        
        final b1 = SlingshotBall(
          gameRef: this,
          startPos: baseBall.position.clone(),
          velocity: vel1,
          type: BallType.split,
          isSplitChild: true,
        );
        final b2 = SlingshotBall(
          gameRef: this,
          startPos: baseBall.position.clone(),
          velocity: vel2,
          type: BallType.split,
          isSplitChild: true,
        );
        
        add(b1);
        add(b2);
        activeBalls.addAll([b1, b2]);
      }
      return;
    }
    
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
        final velocity = diff * 3.5;
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
    
    final mainBall = SlingshotBall(
      gameRef: this,
      startPos: slingPos.clone(),
      velocity: initialVelocity,
      type: currentBallType,
    );
    add(mainBall);
    activeBalls.add(mainBall);
  }

  void onEnemyDestroyed() {
    score += 500;
    SoundService.instance.play(SoundType.coin);
    onStateUpdate?.call(score, ballsLeft, currentLevel);
  }

  void onBlockDestroyed(Vector2 pos) {
    score += 50;
    onStateUpdate?.call(score, ballsLeft, currentLevel);
    
    // Adjacent chain reaction logic
    for (var b in List.from(blocks)) {
      if (!b.isDead && b.position.distanceTo(pos) <= 45) {
        b.takeDamage(40);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (state == SBGameState.shooting) {
      enemies.removeWhere((e) => e.isDead);
      if (enemies.isEmpty) {
        state = SBGameState.levelComplete;
        SoundService.instance.play(SoundType.winFanfare);
        onStateUpdate?.call(score, ballsLeft, currentLevel);
      } else if (activeBalls.isEmpty) {
        onBallStopped();
      }
    }
  }

  void onBallStopped() {
    if (state != SBGameState.shooting) return;
    
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
      
      _drawTrajectory(canvas, pull * 3.5);
    }
  }

  void _drawTrajectory(Canvas canvas, Vector2 initVel) {
    final p = Paint()..color = const Color(0xFFF05A28).withValues(alpha: 0.5);
    Vector2 pos = slingPos.clone();
    Vector2 vel = initVel.clone();
    
    final grav = currentBallType == BallType.heavy ? 650.0 : 400.0;
    
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(pos.toOffset(), 2, p);
      vel.y += grav * 0.05;
      pos += vel * 0.05;
      if (pos.y > size.y || pos.x < 0 || pos.x > size.x) break;
    }
  }
}

class SlingshotBall extends PositionComponent {
  final SlingshotGame gameRef;
  Vector2 velocity;
  final BallType type;
  final bool isSplitChild;
  
  bool hasStopped = false;
  double restTimer = 0;
  bool hasSplit = false;
  int bounceCount = 0;

  SlingshotBall({
    required this.gameRef,
    required Vector2 startPos,
    required this.velocity,
    required this.type,
    this.isSplitChild = false,
  }) : super(
          position: startPos,
          size: Vector2.all(type == BallType.heavy ? 26 : (isSplitChild ? 14 : 20)),
          anchor: Anchor.center,
        );

  void destroyBall() {
    removeFromParent();
    gameRef.activeBalls.remove(this);
  }

  void triggerExplosion() {
    SoundService.instance.play(SoundType.gameOver);
    gameRef.add(ExplosionComponent(position: position.clone(), radius: 90));
    
    // Damage all blocks and enemies in radius
    for (var b in List.from(gameRef.blocks)) {
      if (!b.isDead && b.position.distanceTo(position) <= 90) {
        b.takeDamage(120);
      }
    }
    for (var e in List.from(gameRef.enemies)) {
      if (!e.isDead && e.position.distanceTo(position) <= 90) {
        e.takeDamage(120);
      }
    }
    
    destroyBall();
  }

  @override
  void update(double dt) {
    if (hasStopped) return;
    super.update(dt);

    final grav = type == BallType.heavy ? 650.0 : 400.0;
    velocity.y += grav * dt;
    position += velocity * dt;

    // Floor collision
    if (position.y > gameRef.size.y - 20) {
      position.y = gameRef.size.y - 20;
      if (type == BallType.bomb) {
        triggerExplosion();
        return;
      }
      if (type == BallType.bounce && bounceCount < 3) {
        velocity.y = -velocity.y * 0.85;
        velocity.x *= 0.9;
        bounceCount++;
        SoundService.instance.play(SoundType.wallHit);
      } else {
        velocity.y *= -0.3;
        velocity.x *= 0.7;
      }
    }

    // Side walls collision
    if (position.x < 10) {
      position.x = 10;
      if (type == BallType.bounce && bounceCount < 3) {
        velocity.x = -velocity.x * 0.85;
        bounceCount++;
        SoundService.instance.play(SoundType.wallHit);
      } else {
        velocity.x *= -0.3;
      }
    } else if (position.x > gameRef.size.x - 10) {
      position.x = gameRef.size.x - 10;
      if (type == BallType.bounce && bounceCount < 3) {
        velocity.x = -velocity.x * 0.85;
        bounceCount++;
        SoundService.instance.play(SoundType.wallHit);
      } else {
        velocity.x *= -0.3;
      }
    }

    // Off-screen bounds check
    if (position.y > gameRef.size.y + 40 || position.x < -40 || position.x > gameRef.size.x + 40) {
      destroyBall();
      return;
    }

    // AABB Collision with blocks and enemies
    final rect = toRect();
    for (var b in List.from(gameRef.blocks)) {
      if (!b.isDead && rect.overlaps(b.toRect())) {
        if (type == BallType.bomb) {
          triggerExplosion();
          return;
        }
        if (type == BallType.bounce && bounceCount < 3) {
          final overlap = rect.intersect(b.toRect());
          if (overlap.width < overlap.height) {
            velocity.x = -velocity.x * 0.85;
          } else {
            velocity.y = -velocity.y * 0.85;
          }
          bounceCount++;
          SoundService.instance.play(SoundType.wallHit);
        } else {
          velocity.x *= 0.4;
          velocity.y *= 0.6;
        }
        b.takeDamage(type == BallType.heavy ? 120 : 60);
      }
    }
    for (var e in List.from(gameRef.enemies)) {
      if (!e.isDead && rect.overlaps(e.toRect())) {
        if (type == BallType.bomb) {
          triggerExplosion();
          return;
        }
        if (type == BallType.bounce && bounceCount < 3) {
          velocity.x = -velocity.x * 0.85;
          bounceCount++;
          SoundService.instance.play(SoundType.wallHit);
        } else {
          velocity.x *= 0.4;
        }
        e.takeDamage(100);
      }
    }

    // Stopped moving detection
    if (velocity.length < 15) {
      restTimer += dt;
      if (restTimer > 0.8) {
        hasStopped = true;
        if (type == BallType.bomb) {
          triggerExplosion();
        } else {
          destroyBall();
        }
      }
    } else {
      restTimer = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    Color c = Colors.red;
    switch (type) {
      case BallType.normal: c = const Color(0xFFE57373); break;
      case BallType.heavy: c = const Color(0xFF37474F); break;
      case BallType.split: c = const Color(0xFF64B5F6); break;
      case BallType.bomb: c = const Color(0xFF212121); break;
      case BallType.bounce: c = const Color(0xFFFFD54F); break;
    }
    
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = c);
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    
    // Draw minor details for bomb ball
    if (type == BallType.bomb) {
      canvas.drawCircle(Offset(r, r), r * 0.4, Paint()..color = Colors.red);
    }
  }
}

class BlockComponent extends PositionComponent {
  final SlingshotGame gameRef;
  double hp;
  final double maxHp;
  bool isDead = false;

  BlockComponent({required this.gameRef, required super.position, required this.maxHp})
      : hp = maxHp,
        super(size: Vector2(38, 38), anchor: Anchor.center);

  void takeDamage(double amount) {
    hp -= amount;
    if (hp <= 0 && !isDead) {
      isDead = true;
      gameRef.blocks.remove(this);
      gameRef.onBlockDestroyed(position.clone());
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final healthRatio = (hp / maxHp).clamp(0.0, 1.0);
    final baseColor = Color.lerp(Colors.brown.shade800, Colors.brown.shade300, healthRatio)!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = baseColor);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = Colors.brown.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    
    // Draw wood grain details
    if (hp > 0) {
      final p = Paint()..color = Colors.brown.shade900.withValues(alpha: 0.3)..strokeWidth = 1.5;
      canvas.drawLine(const Offset(4, 4), Offset(size.x - 4, size.y - 4), p);
      canvas.drawLine(Offset(size.x - 4, 4), Offset(4, size.y - 4), p);
    }
  }
}

class EnemyPig extends PositionComponent {
  final SlingshotGame gameRef;
  double hp;
  final double maxHp;
  bool isDead = false;

  EnemyPig({required this.gameRef, required super.position, required this.maxHp})
      : hp = maxHp,
        super(size: Vector2(30, 30), anchor: Anchor.center);

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
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = const Color(0xFF81C784));
    canvas.drawCircle(Offset(r, r), r, Paint()..color = Colors.green.shade900..style = PaintingStyle.stroke..strokeWidth = 1.5);
    
    // Eyes
    canvas.drawCircle(Offset(size.x * 0.35, size.y * 0.35), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.x * 0.35, size.y * 0.35), 1.0, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(size.x * 0.65, size.y * 0.35), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.x * 0.65, size.y * 0.35), 1.0, Paint()..color = Colors.black);
    
    // Snout
    canvas.drawOval(Rect.fromCenter(center: Offset(r, size.y * 0.6), width: 12, height: 8), Paint()..color = const Color(0xFFC8E6C9));
    canvas.drawCircle(Offset(r - 2.5, size.y * 0.6), 1, Paint()..color = Colors.green.shade800);
    canvas.drawCircle(Offset(r + 2.5, size.y * 0.6), 1, Paint()..color = Colors.green.shade800);
  }
}

class ExplosionComponent extends PositionComponent {
  double lifeTime = 0.3;
  double radius;

  ExplosionComponent({required Vector2 position, required this.radius})
      : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    lifeTime -= dt;
    if (lifeTime <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (lifeTime / 0.3).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: t * 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius * (1.0 - t * 0.5), paint);

    final innerPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: t * 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius * 0.5 * (1.0 - t * 0.5), innerPaint);
  }
}
