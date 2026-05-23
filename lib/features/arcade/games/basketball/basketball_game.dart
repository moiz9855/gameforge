import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum BBGameState { ready, shooting, evaluating, gameOver }

class BasketballGame extends FlameGame with PanDetector {
  final void Function(int score, int shots, int level)? onStateUpdate;
  final void Function(int score, int levelsCompleted, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int currentLevel = 1;
  int shotsLeft = 5;
  BBGameState state = BBGameState.ready;
  
  Vector2? dragStart;
  Vector2? dragCurrent;
  
  late Vector2 ballStartPos;
  BallComponent? ball;
  HoopComponent? hoop;
  
  double windForce = 0;

  BasketballGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    ballStartPos = Vector2(size.x / 2, size.y - 120);
    _loadLevel();
  }

  void _loadLevel() {
    state = BBGameState.ready;
    shotsLeft = 5;
    windForce = (Random().nextDouble() - 0.5) * min(currentLevel, 15) * 8;
    
    hoop?.removeFromParent();
    ball?.removeFromParent();
    
    final hx = size.x / 2 + (Random().nextDouble() - 0.5) * (size.x * 0.5);
    final hy = 150.0 + Random().nextDouble() * (size.y * 0.2);
    
    hoop = HoopComponent(
      gameRef: this,
      startPos: Vector2(hx, hy),
      isMoving: currentLevel > 4,
      speed: 20.0 + currentLevel * 3,
    );
    add(hoop!);
    
    ball = BallComponent(gameRef: this, startPos: ballStartPos.clone());
    add(ball!);
    
    onStateUpdate?.call(score, shotsLeft, currentLevel);
  }

  void startGame() {
    score = 0;
    currentLevel = 1;
    _loadLevel();
  }

  @override
  void onPanDown(DragDownInfo info) {
    if (state != BBGameState.ready) return;
    dragStart = info.eventPosition.global;
    dragCurrent = dragStart;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (state != BBGameState.ready) return;
    dragCurrent = info.eventPosition.global;
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (state != BBGameState.ready) return;
    
    if (dragStart != null && dragCurrent != null) {
      final diff = dragStart! - dragCurrent!;
      if (diff.y > 20) { // Swipe up
        final velocity = diff * 3.5;
        _shoot(velocity);
      }
    }
    dragStart = null;
    dragCurrent = null;
  }

  void _shoot(Vector2 initialVelocity) {
    state = BBGameState.shooting;
    shotsLeft--;
    onStateUpdate?.call(score, shotsLeft, currentLevel);
    SoundService.instance.play(SoundType.runnerJump);
    
    ball!.velocity = initialVelocity;
    ball!.isShooting = true;
  }

  void onShotEvaluated(bool hit, bool swish) {
    state = BBGameState.evaluating;
    if (hit) {
      final pts = swish ? 3 : 2;
      score += pts;
      SoundService.instance.play(SoundType.coin);
      if (swish) SoundService.instance.play(SoundType.winFanfare);
      
      add(ScorePopup(points: pts, position: hoop!.position.clone()));
      onStateUpdate?.call(score, shotsLeft, currentLevel);
      
      Future.delayed(const Duration(seconds: 1), () {
        if (isMounted) {
          currentLevel++;
          _loadLevel();
        }
      });
    } else {
      SoundService.instance.play(SoundType.wallHit);
      if (shotsLeft <= 0) {
        state = BBGameState.gameOver;
        final isRecord = score > bestScore;
        if (isRecord) bestScore = score;
        onGameOver?.call(score, currentLevel, isRecord);
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (isMounted) {
            state = BBGameState.ready;
            ball?.removeFromParent();
            ball = BallComponent(gameRef: this, startPos: ballStartPos.clone());
            add(ball!);
          }
        });
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawWind(canvas);
    if (state == BBGameState.ready && dragStart != null && dragCurrent != null) {
      final diff = dragStart! - dragCurrent!;
      if (diff.y > 20) {
        _drawTrajectory(canvas, diff * 3.5);
      }
    }
  }

  void _drawWind(Canvas canvas) {
    if (windForce.abs() < 1) return;
    final cx = size.x / 2;
    final p = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final endX = cx + windForce;
    canvas.drawLine(Offset(cx, 80), Offset(endX, 80), p);
    
    final arrowDir = windForce > 0 ? -5 : 5;
    canvas.drawLine(Offset(endX, 80), Offset(endX + arrowDir, 75), p);
    canvas.drawLine(Offset(endX, 80), Offset(endX + arrowDir, 85), p);
  }

  void _drawTrajectory(Canvas canvas, Vector2 initVel) {
    final p = Paint()..color = const Color(0xFFF05A28).withValues(alpha: 0.5);
    Vector2 pos = ballStartPos.clone();
    Vector2 vel = initVel.clone();
    
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(pos.toOffset(), 2, p);
      vel.y += 600 * 0.05; // Gravity
      vel.x += windForce * 0.05; // Wind
      pos += vel * 0.05;
      if (pos.y > size.y || pos.x < 0 || pos.x > size.x) break;
    }
  }
}

class BallComponent extends PositionComponent {
  final BasketballGame gameRef;
  Vector2 velocity = Vector2.zero();
  bool isShooting = false;
  double zScale = 1.0;
  bool evaluated = false;
  double rot = 0;

  BallComponent({required this.gameRef, required Vector2 startPos})
      : super(position: startPos, size: Vector2.all(40), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (!isShooting) return;

    velocity.y += 600 * dt; // Gravity
    velocity.x += gameRef.windForce * dt; // Wind
    position += velocity * dt;
    
    // Fake 3D depth scaling (ball gets smaller as it goes up, bigger as it comes down)
    // We assume rim is at scale 0.6
    zScale = 1.0 - ((gameRef.ballStartPos.y - position.y) / gameRef.ballStartPos.y) * 0.5;
    zScale = zScale.clamp(0.5, 1.0);
    size = Vector2.all(40 * zScale);
    
    rot += dt * velocity.length * 0.02;

    if (!evaluated && velocity.y > 0 && position.y > gameRef.hoop!.position.y - 10) {
      // Evaluate if passed hoop rim
      final hoopP = gameRef.hoop!.position;
      final dist = position.distanceTo(hoopP);
      if (dist < 30 && zScale < 0.7) {
        evaluated = true;
        gameRef.onShotEvaluated(true, dist < 10);
      }
    }

    if (!evaluated && position.y > gameRef.size.y) {
      evaluated = true;
      gameRef.onShotEvaluated(false, false);
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rot);
    
    final r = size.x / 2;
    // Ball body
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFE65100));
    // Lines
    final p = Paint()..color = const Color(0xFF3E2723)..strokeWidth = max(1, 2 * zScale)..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-r, 0), Offset(r, 0), p);
    canvas.drawLine(Offset(0, -r), Offset(0, r), p);
    canvas.drawArc(Rect.fromCircle(center: Offset(-r*0.6, 0), radius: r*0.8), -pi/2, pi, false, p);
    canvas.drawArc(Rect.fromCircle(center: Offset(r*0.6, 0), radius: r*0.8), pi/2, pi, false, p);
    
    canvas.restore();
  }
}

class HoopComponent extends PositionComponent {
  final BasketballGame gameRef;
  final Vector2 startPos;
  final bool isMoving;
  final double speed;
  double _time = 0;

  HoopComponent({
    required this.gameRef,
    required this.startPos,
    this.isMoving = false,
    this.speed = 0,
  }) : super(position: startPos, size: Vector2(80, 60), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (isMoving && gameRef.state == BBGameState.ready) {
      _time += dt;
      x = startPos.x + sin(_time * speed * 0.05) * 60;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    
    // Backboard
    final boardR = Rect.fromCenter(center: Offset(cx, cy - 20), width: 70, height: 50);
    canvas.drawRect(boardR, Paint()..color = Colors.white24);
    canvas.drawRect(boardR, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    
    // Inner box
    final innerR = Rect.fromCenter(center: Offset(cx, cy - 10), width: 30, height: 24);
    canvas.drawRect(innerR, Paint()..color = const Color(0xFFF05A28)..style = PaintingStyle.stroke..strokeWidth = 2);
    
    // Rim
    final rimP = Paint()..color = const Color(0xFFD84315)..strokeWidth = 4..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 50, height: 16), rimP);
    
    // Net
    final netP = Paint()..color = Colors.white54..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 25, cy), Offset(cx - 15, cy + 30), netP);
    canvas.drawLine(Offset(cx + 25, cy), Offset(cx + 15, cy + 30), netP);
    canvas.drawLine(Offset(cx - 15, cy + 30), Offset(cx + 15, cy + 30), netP);
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
    final text = points > 2 ? 'SWISH! +3' : '+$points';
    final color = points > 2 ? const Color(0xFF4FC3F7) : const Color(0xFFFFD54F);
    
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: _life.clamp(0.0, 1.0)),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'PressStart2P',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
