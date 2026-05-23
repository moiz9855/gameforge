import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum MBGameState { playing, gameOver }

class MathBlasterGame extends FlameGame {
  final void Function(int score, int lives, int level)? onStateUpdate;
  final void Function(int score, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int lives = 3;
  int currentLevel = 1;
  MBGameState state = MBGameState.playing;
  
  double spawnTimer = 0;
  double spawnInterval = 3.0;

  MathBlasterGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    _startGame();
  }

  void _startGame() {
    score = 0;
    lives = 3;
    currentLevel = 1;
    spawnInterval = 3.0;
    spawnTimer = 0;
    state = MBGameState.playing;
    
    children.whereType<EquationBubble>().forEach((b) => b.removeFromParent());
    onStateUpdate?.call(score, lives, currentLevel);
  }

  void restart() => _startGame();

  @override
  void update(double dt) {
    if (state != MBGameState.playing) return;
    super.update(dt);
    
    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      spawnInterval = max(1.0, 3.0 - currentLevel * 0.1);
      
      _spawnBubble();
    }
    
    // Level up
    if (score > currentLevel * 500) {
      currentLevel++;
      onStateUpdate?.call(score, lives, currentLevel);
    }
  }

  void _spawnBubble() {
    final rand = Random();
    int a = rand.nextInt(10 * currentLevel) + 1;
    int b = rand.nextInt(10 * currentLevel) + 1;
    int ans = 0;
    String op = '+';
    
    final opType = rand.nextInt(min(currentLevel, 4));
    switch (opType) {
      case 0: op = '+'; ans = a + b; break;
      case 1: op = '-'; if (a < b) { final t=a; a=b; b=t; } ans = a - b; break;
      case 2: op = '×'; a=a%10+1; b=b%10+1; ans = a * b; break;
      case 3: op = '÷'; b=b%10+1; ans = a; a = a * b; break;
    }
    
    final text = '$a $op $b';
    final x = 40.0 + rand.nextDouble() * (size.x - 80);
    
    // Sometimes spawn wrong answers
    final isCorrect = rand.nextDouble() > 0.5;
    if (!isCorrect) {
      ans += rand.nextInt(5) + 1;
    }

    add(EquationBubble(
      gameRef: this,
      position: Vector2(x, -40),
      equation: text,
      answer: ans,
      isCorrect: isCorrect,
      speed: 50.0 + currentLevel * 10,
    ));
  }

  void handleTap(Offset pos) {
    if (state != MBGameState.playing) return;
    
    bool hit = false;
    
    for (final b in children.whereType<EquationBubble>().toList().reversed) {
      if (b.toRect().contains(pos)) {
        hit = true;
        if (b.isCorrect) {
          // Popped a correct equation -> GOOD
          score += 50;
          SoundService.instance.play(SoundType.coin);
        } else {
          // Popped a wrong equation -> BAD
          lives--;
          SoundService.instance.play(SoundType.error);
        }
        b.removeFromParent();
        add(PopEffect(position: b.position.clone()));
        onStateUpdate?.call(score, lives, currentLevel);
        break; // Only pop one
      }
    }
    
    if (!hit) {
      // Tap on nothing -> just play a sound
      SoundService.instance.play(SoundType.snakeMove);
    }
    
    _checkGameOver();
  }

  void onBubbleEscaped(EquationBubble b) {
    if (b.isCorrect) {
      // Correct equation escaped -> BAD
      lives--;
      SoundService.instance.play(SoundType.error);
      onStateUpdate?.call(score, lives, currentLevel);
      _checkGameOver();
    } else {
      // Wrong equation escaped -> GOOD
      score += 10;
      onStateUpdate?.call(score, lives, currentLevel);
    }
  }

  void _checkGameOver() {
    if (lives <= 0 && state == MBGameState.playing) {
      state = MBGameState.gameOver;
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onGameOver?.call(score, isRecord);
    }
  }
}

class EquationBubble extends PositionComponent {
  final MathBlasterGame gameRef;
  final String equation;
  final int answer;
  final bool isCorrect;
  final double speed;
  double wobble = 0;
  double wSpeed;

  EquationBubble({
    required this.gameRef,
    required super.position,
    required this.equation,
    required this.answer,
    required this.isCorrect,
    required this.speed,
  }) : wSpeed = 2 + Random().nextDouble() * 3, super(size: Vector2(80, 80), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
    wobble += wSpeed * dt;
    position.x += sin(wobble) * 30 * dt;

    if (position.y > gameRef.size.y + 40) {
      gameRef.onBubbleEscaped(this);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x/2;
    final cy = size.y/2;
    
    canvas.drawCircle(Offset(cx, cy), cx, Paint()..color = Colors.blue.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(cx, cy), cx, Paint()..color = Colors.blue.shade200..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx-10, cy-10), radius: 10), -pi, pi/2, false, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    final tp = TextPainter(
      text: TextSpan(
        text: '$equation\n=$answer',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'PressStart2P'),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    tp.paint(canvas, Offset(cx - tp.width/2, cy - tp.height/2));
  }
}

class PopEffect extends PositionComponent {
  double life = 1.0;
  
  PopEffect({required super.position}) : super(size: Vector2.all(80), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt * 3;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.white.withValues(alpha: life.clamp(0.0, 1.0))..style = PaintingStyle.stroke..strokeWidth = 2;
    final r = size.x/2 * (1 + (1-life));
    canvas.drawCircle(Offset(size.x/2, size.y/2), r, p);
  }
}
