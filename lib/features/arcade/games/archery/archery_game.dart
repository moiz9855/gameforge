import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum GameState { ready, aiming, shooting, levelComplete, gameOver }

class ArcheryGame extends FlameGame with PanDetector {
  final void Function(int score, int arrows, int level, double wind)? onScoreUpdate;
  final void Function(int score, int levelsCompleted, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int currentLevel = 1;
  int arrowsLeft = 3;
  GameState state = GameState.ready;
  
  double windForce = 0;
  late Vector2 bowPos;
  Vector2? dragStart;
  Vector2? dragCurrent;
  
  TargetComponent? target;
  ArrowComponent? activeArrow;
  
  ArcheryGame({this.onScoreUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    bowPos = Vector2(size.x / 2, size.y - 120);
    _loadLevel();
  }

  void _loadLevel() {
    state = GameState.ready;
    arrowsLeft = 3;
    windForce = (Random().nextDouble() - 0.5) * min(currentLevel, 20) * 15;
    
    target?.removeFromParent();
    activeArrow?.removeFromParent();
    activeArrow = null;
    
    final ty = 120.0 + Random().nextDouble() * (size.y * 0.3);
    final tx = size.x / 2 + (Random().nextDouble() - 0.5) * (size.x * 0.6);
    final isMoving = currentLevel >= 3;
    
    target = TargetComponent(
      gameRef: this,
      startPos: Vector2(tx, ty),
      isMoving: isMoving,
      speed: 30.0 + currentLevel * 5.0,
    );
    add(target!);
    
    onScoreUpdate?.call(score, arrowsLeft, currentLevel, windForce);
  }

  void startGame() {
    score = 0;
    currentLevel = 1;
    _loadLevel();
  }
  
  void nextLevel() {
    if (currentLevel < 60) {
      currentLevel++;
      _loadLevel();
    } else {
      state = GameState.gameOver;
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onGameOver?.call(score, currentLevel, isRecord);
    }
  }

  @override
  void onPanDown(DragDownInfo info) {
    if (state != GameState.ready) return;
    state = GameState.aiming;
    dragStart = info.eventPosition.global;
    dragCurrent = dragStart;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (state != GameState.aiming) return;
    dragCurrent = info.eventPosition.global;
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (state != GameState.aiming) return;
    
    if (dragStart != null && dragCurrent != null) {
      final diff = dragStart! - dragCurrent!;
      if (diff.length > 20) {
        final velocity = diff * 4.5;
        _shoot(velocity);
      } else {
        state = GameState.ready;
      }
    }
    dragStart = null;
    dragCurrent = null;
  }

  void _shoot(Vector2 initialVelocity) {
    state = GameState.shooting;
    arrowsLeft--;
    onScoreUpdate?.call(score, arrowsLeft, currentLevel, windForce);
    SoundService.instance.play(SoundType.snakeMove);
    
    activeArrow = ArrowComponent(
      gameRef: this,
      startPos: bowPos.clone(),
      velocity: initialVelocity,
    );
    add(activeArrow!);
  }

  void onArrowHitTarget(int points, Vector2 hitPos) {
    state = GameState.levelComplete;
    score += points;
    SoundService.instance.play(SoundType.coin);
    onScoreUpdate?.call(score, arrowsLeft, currentLevel, windForce);
    
    add(ScorePopup(points: points, position: hitPos.clone()));
    
    Future.delayed(const Duration(seconds: 2), () {
      if (isMounted) nextLevel();
    });
  }

  void onArrowMiss() {
    SoundService.instance.play(SoundType.wallHit);
    if (arrowsLeft <= 0) {
      state = GameState.gameOver;
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onGameOver?.call(score, currentLevel, isRecord);
    } else {
      state = GameState.ready;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBow(canvas);
    if (state == GameState.aiming && dragStart != null && dragCurrent != null) {
      final diff = dragStart! - dragCurrent!;
      if (diff.length > 20) {
        _drawTrajectory(canvas, diff * 4.5);
      }
    }
  }


  void _drawBow(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xFFF05A28)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    final bowRect = Rect.fromCenter(center: Offset(bowPos.x, bowPos.y), width: 80, height: 20);
    canvas.drawArc(bowRect, pi, pi, false, p);
    
    double pullY = bowPos.y;
    if (state == GameState.aiming && dragStart != null && dragCurrent != null) {
      final pull = (dragStart!.y - dragCurrent!.y).clamp(-60.0, 0.0);
      pullY -= pull;
    }
    
    final stringP = Paint()..color = Colors.white54..strokeWidth = 1;
    canvas.drawLine(Offset(bowPos.x - 40, bowPos.y), Offset(bowPos.x, pullY), stringP);
    canvas.drawLine(Offset(bowPos.x + 40, bowPos.y), Offset(bowPos.x, pullY), stringP);
  }

  void _drawTrajectory(Canvas canvas, Vector2 initVel) {
    final p = Paint()
      ..color = const Color(0xFFF05A28).withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;
    Vector2 pos = bowPos.clone();
    Vector2 vel = initVel.clone();
    
    for (int i = 0; i < 40; i++) {
      if (i % 2 == 0) {
        canvas.drawCircle(pos.toOffset(), 2.5, p);
      }
      vel.y += 400 * 0.03; 
      vel.x += windForce * 0.03; 
      pos += vel * 0.03;
      if (pos.y > size.y || pos.x < 0 || pos.x > size.x) break;
    }
  }
}


class TargetComponent extends PositionComponent {
  final ArcheryGame gameRef;
  final Vector2 startPos;
  final bool isMoving;
  final double speed;
  double _time = 0;

  TargetComponent({
    required this.gameRef,
    required this.startPos,
    this.isMoving = false,
    this.speed = 0,
  }) : super(position: startPos, size: Vector2.all(80), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (isMoving && gameRef.state != GameState.levelComplete) {
      _time += dt;
      x = startPos.x + sin(_time * speed * 0.05) * 80;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rings = [
      (40.0, const Color(0xFFEEEEEE), 10),
      (30.0, const Color(0xFF222222), 25),
      (20.0, const Color(0xFF4FC3F7), 50),
      (10.0, const Color(0xFFE84040), 100),
      (4.0, const Color(0xFFFFD54F), 250),
    ];

    for (var ring in rings) {
      canvas.drawCircle(
        Offset(cx, cy),
        ring.$1,
        Paint()..color = ring.$2,
      );
    }
  }

  int getPoints(Vector2 hitPoint) {
    final dist = hitPoint.distanceTo(position);
    if (dist <= 4) return 250;
    if (dist <= 10) return 100;
    if (dist <= 20) return 50;
    if (dist <= 30) return 25;
    if (dist <= 40) return 10;
    return 0;
  }

  void shake() {
    add(
      SequenceEffect([
        MoveEffect.by(Vector2(5, 0), EffectController(duration: 0.05)),
        MoveEffect.by(Vector2(-10, 0), EffectController(duration: 0.1)),
        MoveEffect.by(Vector2(5, 0), EffectController(duration: 0.05)),
      ]),
    );
  }
}

class ArrowComponent extends PositionComponent {
  final ArcheryGame gameRef;
  Vector2 velocity;
  bool isLanded = false;

  ArrowComponent({
    required this.gameRef,
    required Vector2 startPos,
    required this.velocity,
  }) : super(position: startPos, size: Vector2(4, 30), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (isLanded) return;

    velocity.y += 400 * dt; // Gravity
    velocity.x += gameRef.windForce * dt; // Wind
    position += velocity * dt;
    angle = atan2(velocity.y, velocity.x) + pi / 2;

    if (position.y > gameRef.size.y || position.x < -50 || position.x > gameRef.size.x + 50) {
      isLanded = true;
      gameRef.onArrowMiss();
      return;
    }

    final target = gameRef.target;
    if (target != null && gameRef.state == GameState.shooting) {
      final headPos = position + Vector2(sin(angle), -cos(angle)) * 15;
      final dist = headPos.distanceTo(target.position);
      if (dist <= 40) {
        isLanded = true;
        final pts = target.getPoints(headPos);
        target.shake();
        gameRef.onArrowHitTarget(pts, headPos);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.white;
    canvas.drawLine(const Offset(2, 0), const Offset(2, 30), p);
    // Arrow head
    canvas.drawLine(const Offset(2, 0), const Offset(0, 6), p);
    canvas.drawLine(const Offset(2, 0), const Offset(4, 6), p);
  }
}

class ScorePopup extends PositionComponent {
  final int points;
  double _life = 1.0;

  ScorePopup({required this.points, required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    y -= 50 * dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: '+$points',
        style: GoogleFonts.pressStart2p(
          color: const Color(0xFFFFD54F).withValues(alpha: _life.clamp(0.0, 1.0)),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
