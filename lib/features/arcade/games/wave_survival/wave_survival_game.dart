import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

enum HeroClass { warrior, archer, mage, tank, assassin, healer }
enum EnemyClass { goblin, orc, skeleton, boss }
enum WSGameState { setup, playing, levelComplete, gameOver }

class WaveSurvivalGame extends FlameGame {
  final void Function(int level, int wave, WSGameState state)? onStateUpdate;
  final void Function(int score, int levelsCompleted, bool newRecord)? onGameOver;
  int bestScore;
  
  int score = 0;
  int currentLevel = 1;
  int currentWave = 1;
  WSGameState state = WSGameState.setup;
  
  final List<HeroClass> selectedHeroes = [];
  final List<HeroComponent> heroes = [];
  final List<EnemyComponent> enemies = [];

  WaveSurvivalGame({this.onStateUpdate, this.onGameOver, this.bestScore = 0});

  @override
  Color backgroundColor() => const Color(0xFF080809);

  @override
  Future<void> onLoad() async {
    showSetup();
  }

  void showSetup() {
    state = WSGameState.setup;
    selectedHeroes.clear();
    for (var h in heroes) { h.removeFromParent(); }
    heroes.clear();
    for (var e in enemies) { e.removeFromParent(); }
    enemies.clear();
    onStateUpdate?.call(currentLevel, currentWave, state);
  }

  void startLevel(List<HeroClass> heroesToDeploy) {
    selectedHeroes.addAll(heroesToDeploy);
    state = WSGameState.playing;
    currentWave = 1;
    
    // Spawn heroes
    for (int i = 0; i < selectedHeroes.length; i++) {
      final h = HeroComponent(
        gameRef: this,
        heroClass: selectedHeroes[i],
        startPos: Vector2(50.0 + (i % 2) * 50, size.y / 2 - 60 + i * 60),
      );
      heroes.add(h);
      add(h);
    }
    
    _spawnWave();
    onStateUpdate?.call(currentLevel, currentWave, state);
  }

  void _spawnWave() {
    for (var e in enemies) { e.removeFromParent(); }
    enemies.clear();
    
    final count = currentLevel * 2 + currentWave;
    for (int i = 0; i < count; i++) {
      final isBoss = currentWave % 10 == 0 && i == 0;
      final eClass = isBoss ? EnemyClass.boss : EnemyClass.values[Random().nextInt(3)];
      
      final e = EnemyComponent(
        gameRef: this,
        enemyClass: eClass,
        startPos: Vector2(size.x + 50 + Random().nextDouble() * 100, size.y / 2 - 100 + Random().nextDouble() * 200),
      );
      enemies.add(e);
      add(e);
    }
  }

  @override
  void update(double dt) {
    if (state != WSGameState.playing) return;
    super.update(dt);

    heroes.removeWhere((h) => h.isDead);
    enemies.removeWhere((e) => e.isDead);

    if (heroes.isEmpty) {
      state = WSGameState.gameOver;
      final isRecord = score > bestScore;
      if (isRecord) bestScore = score;
      onStateUpdate?.call(currentLevel, currentWave, state);
      onGameOver?.call(score, currentLevel, isRecord);
    } else if (enemies.isEmpty) {
      currentWave++;
      score += 100 * currentLevel;
      if (currentWave > 10) {
        state = WSGameState.levelComplete;
        SoundService.instance.play(SoundType.winFanfare);
        onStateUpdate?.call(currentLevel, currentWave, state);
      } else {
        _spawnWave();
        onStateUpdate?.call(currentLevel, currentWave, state);
      }
    }
  }

  void nextLevel() {
    currentLevel++;
    currentWave = 1;
    score += heroes.length * 500; // survival bonus
    showSetup();
  }
}

class UnitComponent extends PositionComponent {
  final WaveSurvivalGame gameRef;
  double hp;
  double maxHp;
  double damage;
  double range;
  double attackSpeed;
  double speed;
  double _attackCooldown = 0;
  bool isDead = false;

  UnitComponent({
    required this.gameRef,
    required Vector2 startPos,
    required this.maxHp,
    required this.damage,
    required this.range,
    required this.attackSpeed,
    required this.speed,
  }) : hp = maxHp, super(position: startPos, size: Vector2(30, 30), anchor: Anchor.center);

  @override
  void update(double dt) {
    if (isDead) return;
    super.update(dt);
    if (_attackCooldown > 0) _attackCooldown -= dt;
  }

  void takeDamage(double amount) {
    hp -= amount;
    if (hp <= 0) {
      hp = 0;
      isDead = true;
      removeFromParent();
    }
  }

  void drawHealthBar(Canvas canvas) {
    final pct = hp / maxHp;
    canvas.drawRect(Rect.fromLTWH(0, -10, size.x, 4), Paint()..color = Colors.red);
    canvas.drawRect(Rect.fromLTWH(0, -10, size.x * pct, 4), Paint()..color = Colors.green);
  }
}

class HeroComponent extends UnitComponent {
  final HeroClass heroClass;
  
  HeroComponent({required super.gameRef, required this.heroClass, required super.startPos})
      : super(
          maxHp: heroClass == HeroClass.tank ? 300 : 100,
          damage: heroClass == HeroClass.assassin ? 40 : 15,
          range: (heroClass == HeroClass.archer || heroClass == HeroClass.mage) ? 150 : 40,
          attackSpeed: heroClass == HeroClass.assassin ? 0.5 : 1.2,
          speed: 60,
        );

  @override
  void update(double dt) {
    if (isDead || gameRef.state != WSGameState.playing) return;
    super.update(dt);
    
    // Find nearest enemy
    EnemyComponent? target;
    double minDist = double.infinity;
    for (var e in gameRef.enemies) {
      final d = position.distanceTo(e.position);
      if (d < minDist) {
        minDist = d;
        target = e;
      }
    }

    if (target != null) {
      if (minDist <= range) {
        if (_attackCooldown <= 0) {
          target.takeDamage(damage);
          _attackCooldown = attackSpeed;
          // Healer logic
          if (heroClass == HeroClass.healer) {
             for (var h in gameRef.heroes) {
                h.hp = min(h.maxHp, h.hp + 10);
             }
          }
        }
      } else {
        final dir = (target.position - position).normalized();
        position += dir * speed * dt;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    Color c = Colors.blue;
    switch (heroClass) {
      case HeroClass.warrior: c = Colors.orange; break;
      case HeroClass.archer: c = Colors.green; break;
      case HeroClass.mage: c = Colors.purple; break;
      case HeroClass.tank: c = Colors.blueGrey; break;
      case HeroClass.assassin: c = Colors.black; break;
      case HeroClass.healer: c = Colors.teal; break;
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = c);
    drawHealthBar(canvas);
  }
}

class EnemyComponent extends UnitComponent {
  final EnemyClass enemyClass;
  
  EnemyComponent({required super.gameRef, required this.enemyClass, required super.startPos})
      : super(
          maxHp: enemyClass == EnemyClass.boss ? 1000 : 50,
          damage: enemyClass == EnemyClass.boss ? 50 : 10,
          range: 30,
          attackSpeed: 1.5,
          speed: 40,
        ) {
          if (enemyClass == EnemyClass.boss) size = Vector2(60, 60);
        }

  @override
  void update(double dt) {
    if (isDead || gameRef.state != WSGameState.playing) return;
    super.update(dt);
    
    HeroComponent? target;
    double minDist = double.infinity;
    for (var h in gameRef.heroes) {
      final d = position.distanceTo(h.position);
      if (d < minDist) {
        minDist = d;
        target = h;
      }
    }

    if (target != null) {
      if (minDist <= range) {
        if (_attackCooldown <= 0) {
          target.takeDamage(damage);
          _attackCooldown = attackSpeed;
        }
      } else {
        final dir = (target.position - position).normalized();
        position += dir * speed * dt;
      }
    } else {
      position.x -= speed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    Color c = Colors.red;
    if (enemyClass == EnemyClass.boss) c = Colors.deepPurple;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = c);
    drawHealthBar(canvas);
  }
}
