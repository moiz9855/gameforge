import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_forge/core/services/sound_service.dart';

// ─── Enums ───────────────────────────────────────────────
enum ObstacleType { standard, low, high }
enum PowerUpType { shield, magnet, speedBoost }
enum PlayerState { running, jumping, sliding }

// ─── Main Game ───────────────────────────────────────────
class RunnerGame extends FlameGame {
  final void Function(int score, double distance, int coins, double mult)?
      onScoreUpdate;
  final void Function(int score, double distance, int coins, bool newRecord)?
      onGameOver;

  int bestScore;

  RunnerGame({this.onScoreUpdate, this.onGameOver, this.bestScore = 0});

  // ── state ──
  bool isPlaying = false;
  bool isGameOver = false;

  // ── speed ──
  static const double _baseSpeed = 240.0;
  double currentSpeed = _baseSpeed;
  double _speedTimer = 0;

  // ── scoring ──
  double distance = 0;
  int coinsCollected = 0;
  double get speedMultiplier => currentSpeed / _baseSpeed;

  // ── spawn cooldowns ──
  double _obsCD = 1.8;
  double _coinCD = 0.6;
  double _puCD = 18.0;

  // ── lanes ──
  static const int laneCount = 3;
  late double laneWidth;
  late List<double> laneCenters;

  // ── player ──
  late RunnerPlayer player;

  // ── power-ups ──
  bool shieldActive = false;
  bool magnetActive = false;
  bool boostActive = false;
  double _shieldT = 0, _magnetT = 0, _boostT = 0;

  // ── visuals ──
  double _roadScroll = 0;
  final List<_Bldg> _bldgs = [];
  final Random rng = Random();

  @override
  Color backgroundColor() => const Color(0xFF080809);

  // ─────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    laneWidth = size.x / laneCount;
    laneCenters =
        List.generate(laneCount, (i) => laneWidth * i + laneWidth / 2);

    // pre-generate skyline
    for (int i = 0; i < 28; i++) {
      _bldgs.add(_Bldg.random(size, rng));
    }

    player = RunnerPlayer(gameRef: this);
    add(player);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0) {
      laneWidth = size.x / laneCount;
      laneCenters =
          List.generate(laneCount, (i) => laneWidth * i + laneWidth / 2);
    }
  }

  // ─────────────────────────────────────────────────
  void startGame() {
    isPlaying = true;
    isGameOver = false;
    currentSpeed = _baseSpeed;
    distance = 0;
    coinsCollected = 0;
    _speedTimer = 0;
    _obsCD = 1.8;
    _coinCD = 0.6;
    _puCD = 18.0;
    shieldActive = false;
    magnetActive = false;
    boostActive = false;

    player.reset();

    children.whereType<Obstacle>().toList().forEach((c) => c.removeFromParent());
    children.whereType<GameCoin>().toList().forEach((c) => c.removeFromParent());
    children
        .whereType<GamePowerUp>()
        .toList()
        .forEach((c) => c.removeFromParent());
  }

  // ─────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);
    if (!isPlaying || isGameOver) return;

    distance += currentSpeed * dt * 0.01;
    _roadScroll = (_roadScroll + currentSpeed * dt) % 40;

    // speed ramp every 10s
    _speedTimer += dt;
    if (_speedTimer >= 10.0) {
      _speedTimer = 0;
      currentSpeed += 22;
    }

    // ── spawning ──
    _obsCD -= dt;
    if (_obsCD <= 0) {
      _obsCD = max(0.65, 2.0 - distance * 0.004) + rng.nextDouble() * 0.4;
      _spawnObstacle();
    }

    _coinCD -= dt;
    if (_coinCD <= 0) {
      _coinCD = 0.55 + rng.nextDouble() * 0.5;
      _spawnCoins();
    }

    _puCD -= dt;
    if (_puCD <= 0) {
      _puCD = 12.0 + rng.nextDouble() * 10;
      _spawnPowerUp();
    }

    // ── power-up timers ──
    if (shieldActive) {
      _shieldT -= dt;
      if (_shieldT <= 0) shieldActive = false;
    }
    if (magnetActive) {
      _magnetT -= dt;
      if (_magnetT <= 0) magnetActive = false;
    }
    if (boostActive) {
      _boostT -= dt;
      if (_boostT <= 0) boostActive = false;
    }

    // ── magnet pull ──
    if (magnetActive) {
      for (final c in children.whereType<GameCoin>()) {
        final dx = player.x - c.x;
        final dy = player.y - c.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d < 180 && d > 2) {
          c.x += dx / d * 380 * dt;
          c.y += dy / d * 380 * dt;
        }
      }
    }

    _checkCollisions();

    onScoreUpdate?.call(currentScore, distance, coinsCollected,
        boostActive ? speedMultiplier * 2 : speedMultiplier);
  }

  // ─────────────────────────────────────────────────
  void _checkCollisions() {
    final pr = Rect.fromCenter(
      center: Offset(player.x, player.y),
      width: player.width - 14,
      height: player.currentHeight - 8,
    );

    for (final obs in children.whereType<Obstacle>().toList()) {
      final or2 = Rect.fromCenter(
          center: Offset(obs.x, obs.y), width: obs.width, height: obs.height);
      if (!pr.overlaps(or2)) continue;

      if (obs.type == ObstacleType.low &&
          player.state == PlayerState.jumping) {
        continue;
      }
      if (obs.type == ObstacleType.high &&
          player.state == PlayerState.sliding) {
        continue;
      }

      if (shieldActive) {
        shieldActive = false;
        obs.removeFromParent();
        SoundService.instance.play(SoundType.wallHit);
        continue;
      }
      SoundService.instance.play(SoundType.runnerHit);
      _die();
      return;
    }

    for (final c in children.whereType<GameCoin>().toList()) {
      final cr =
          Rect.fromCenter(center: Offset(c.x, c.y), width: 26, height: 26);
      if (pr.overlaps(cr)) {
        coinsCollected++;
        c.removeFromParent();
        SoundService.instance.play(SoundType.coin);
      }
    }

    for (final p in children.whereType<GamePowerUp>().toList()) {
      final pr2 =
          Rect.fromCenter(center: Offset(p.x, p.y), width: 30, height: 30);
      if (pr.overlaps(pr2)) {
        _activate(p.type);
        p.removeFromParent();
        SoundService.instance.play(SoundType.powerupCollect);
      }
    }
  }

  void _activate(PowerUpType t) {
    switch (t) {
      case PowerUpType.shield:
        shieldActive = true;
        _shieldT = 3.0;
        SoundService.instance.play(SoundType.shieldActivate);
      case PowerUpType.magnet:
        magnetActive = true;
        _magnetT = 5.0;
        SoundService.instance.play(SoundType.magnetActivate);
      case PowerUpType.speedBoost:
        boostActive = true;
        _boostT = 5.0;
        SoundService.instance.play(SoundType.speedBoost);
    }
  }

  // ─────────────────────────────────────────────────
  void _spawnObstacle() {
    final lane = rng.nextInt(laneCount);
    final r = rng.nextDouble();
    final type = r < 0.5
        ? ObstacleType.standard
        : r < 0.75
            ? ObstacleType.low
            : ObstacleType.high;
    add(Obstacle(gameRef: this, lane: lane, type: type));
  }

  void _spawnCoins() {
    final lane = rng.nextInt(laneCount);
    final count = 2 + rng.nextInt(3);
    for (int i = 0; i < count; i++) {
      add(GameCoin(gameRef: this, lane: lane, startY: -20.0 - i * 44));
    }
  }

  void _spawnPowerUp() {
    final lane = rng.nextInt(laneCount);
    add(GamePowerUp(
      gameRef: this,
      lane: lane,
      type: PowerUpType.values[rng.nextInt(3)],
    ));
  }

  // ─────────────────────────────────────────────────
  void _die() {
    isGameOver = true;
    isPlaying = false;
    final s = currentScore;
    final nr = s > bestScore;
    if (nr) bestScore = s;
    onGameOver?.call(s, distance, coinsCollected, nr);
  }

  int get currentScore {
    final m = boostActive ? speedMultiplier * 2 : speedMultiplier;
    return (distance * m).toInt() + coinsCollected * 10;
  }

  // ── public controls ──
  void moveLeft() {
    if (isPlaying && !isGameOver) player.moveLane(-1);
  }

  void moveRight() {
    if (isPlaying && !isGameOver) player.moveLane(1);
  }

  void jump() {
    if (isPlaying && !isGameOver) player.jump();
  }

  void slide() {
    if (isPlaying && !isGameOver) player.slide();
  }

  // ─────────────────────────────────────────────────
  //  RENDERING  (background + road drawn before children)
  // ─────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    _drawSky(canvas);
    _drawRoad(canvas);
    super.render(canvas);
  }

  void _drawSky(Canvas canvas) {
    // gradient sky
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03030A), Color(0xFF0A0A1A)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * 0.4), skyPaint);

    // buildings
    for (final b in _bldgs) {
      final sy = (b.baseY + _roadScroll * 0.12) % (size.y * 0.45);
      final bRect = Rect.fromLTWH(b.x, sy - b.h, b.w, b.h);
      canvas.drawRect(bRect, Paint()..color = const Color(0xFF0C0C18));
      // neon windows (pre-generated)
      for (final w in b.wins) {
        canvas.drawRect(
          Rect.fromLTWH(b.x + w.dx, sy - b.h + w.dy, 3, 4),
          Paint()..color = Color.fromRGBO(240, 90, 40, b.glow),
        );
      }
    }

    // horizon neon line
    final hy = size.y * 0.38;
    canvas.drawLine(
      Offset(0, hy),
      Offset(size.x, hy),
      Paint()
        ..color = const Color(0xFFF05A28).withValues(alpha: 0.3)
        ..strokeWidth = 1.5,
    );
  }

  void _drawRoad(Canvas canvas) {
    final top = size.y * 0.38;
    canvas.drawRect(
        Rect.fromLTRB(0, top, size.x, size.y), Paint()..color = const Color(0xFF0E0E15));

    // dashed lane dividers
    final dp = Paint()
      ..color = const Color(0xFF222232)
      ..strokeWidth = 2;
    for (int i = 1; i < laneCount; i++) {
      final lx = laneWidth * i;
      for (double y = top - _roadScroll; y < size.y; y += 40) {
        if (y + 20 > top) {
          canvas.drawLine(
              Offset(lx, max(y, top)), Offset(lx, min(y + 20, size.y)), dp);
        }
      }
    }

    // orange edge glow
    final ep = Paint()
      ..color = const Color(0xFFF05A28).withValues(alpha: 0.3)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(2, top), Offset(2, size.y), ep);
    canvas.drawLine(Offset(size.x - 2, top), Offset(size.x - 2, size.y), ep);
  }
}

// ─── Pre-generated building data ─────────────────────────
class _Bldg {
  final double x, baseY, w, h, glow;
  final List<Offset> wins;

  _Bldg._(this.x, this.baseY, this.w, this.h, this.glow, this.wins);

  factory _Bldg.random(Vector2 screen, Random rng) {
    final w = 16.0 + rng.nextDouble() * 36;
    final h = 30.0 + rng.nextDouble() * 85;
    final windows = <Offset>[];
    for (double wy = 6; wy < h - 4; wy += 10) {
      for (double wx = 3; wx < w - 3; wx += 7) {
        if (rng.nextDouble() < 0.35) windows.add(Offset(wx, wy));
      }
    }
    return _Bldg._(
      rng.nextDouble() * screen.x,
      rng.nextDouble() * screen.y * 0.45,
      w,
      h,
      0.04 + rng.nextDouble() * 0.12,
      windows,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PLAYER
// ═══════════════════════════════════════════════════════════
class RunnerPlayer extends PositionComponent {
  final RunnerGame gameRef;

  int _lane = 1;
  double _targetX = 0;
  PlayerState state = PlayerState.running;
  double _jumpT = 0;
  double _slideT = 0;
  double _baseY = 0;
  double _footstepTimer = 0;

  static const double _jumpDur = 0.5;
  static const double _slideDur = 0.55;
  static const double _normalH = 56;
  static const double _slideH = 26;

  double get currentHeight =>
      state == PlayerState.sliding ? _slideH : _normalH;

  RunnerPlayer({required this.gameRef}) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _baseY = gameRef.size.y * 0.78;
    size = Vector2(36, _normalH);
    reset();
  }

  void reset() {
    _lane = 1;
    _targetX = gameRef.laneCenters[1];
    position = Vector2(_targetX, _baseY);
    state = PlayerState.running;
    _jumpT = 0;
    _slideT = 0;
    size.y = _normalH;
    _footstepTimer = 0;
  }

  void moveLane(int dir) {
    final oldLane = _lane;
    _lane = (_lane + dir).clamp(0, RunnerGame.laneCount - 1);
    if (_lane != oldLane) {
      _targetX = gameRef.laneCenters[_lane];
      SoundService.instance.play(SoundType.snakeMove);
    }
  }

  void jump() {
    if (state != PlayerState.running) return;
    state = PlayerState.jumping;
    _jumpT = 0;
    SoundService.instance.play(SoundType.runnerJump);
  }

  void slide() {
    if (state != PlayerState.running) return;
    state = PlayerState.sliding;
    _slideT = 0;
    size.y = _slideH;
    SoundService.instance.play(SoundType.runnerSlide);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // smooth lane switch
    x += (_targetX - x) * 14 * dt;

    if (state == PlayerState.jumping) {
      _jumpT += dt;
      if (_jumpT >= _jumpDur) {
        state = PlayerState.running;
        y = _baseY;
      } else {
        y = _baseY - sin(_jumpT / _jumpDur * pi) * 85;
      }
    } else if (state == PlayerState.sliding) {
      _slideT += dt;
      if (_slideT >= _slideDur) {
        state = PlayerState.running;
        size.y = _normalH;
      }
    }

    if (state == PlayerState.running) {
      y = _baseY;
      _footstepTimer += dt;
      final interval = 0.35 / gameRef.speedMultiplier;
      if (_footstepTimer >= interval) {
        _footstepTimer = 0;
        SoundService.instance.play(SoundType.runnerStep);
      }
    } else {
      _footstepTimer = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // orange glow
    canvas.drawCircle(
      Offset(cx, cy),
      30,
      Paint()
        ..color = const Color(0xFFF05A28)
            .withValues(alpha: gameRef.shieldActive ? 0.28 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // shield ring
    if (gameRef.shieldActive) {
      canvas.drawCircle(
        Offset(cx, cy),
        28,
        Paint()
          ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    // magnet aura
    if (gameRef.magnetActive) {
      canvas.drawCircle(
        Offset(cx, cy),
        32,
        Paint()
          ..color = const Color(0xFFAB47BC).withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    // boost aura
    if (gameRef.boostActive) {
      canvas.drawCircle(
        Offset(cx, cy),
        28,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    final p = Paint()..color = const Color(0xFFF05A28);
    final h = currentHeight;

    if (state == PlayerState.sliding) {
      // crouched capsule
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 38, height: h),
            const Radius.circular(6)),
        p,
      );
      canvas.drawCircle(Offset(cx - 10, cy - 2), 7, p);
    } else {
      // head
      canvas.drawCircle(Offset(cx, cy - h / 2 + 9), 9, p);
      // torso
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 8, cy - h / 2 + 20, 16, h * 0.34),
            const Radius.circular(3)),
        p,
      );
      // legs (animated)
      final legPhase = gameRef.distance * 8;
      final sw = sin(legPhase) * 10;
      final lp = Paint()
        ..color = const Color(0xFFD04A1C)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final bodyBot = cy - h / 2 + 20 + h * 0.34;
      canvas.drawLine(Offset(cx, bodyBot), Offset(cx + sw, cy + h / 2 - 2), lp);
      canvas.drawLine(
          Offset(cx, bodyBot), Offset(cx - sw, cy + h / 2 - 2), lp);
      // arms
      final aw = sin(legPhase + pi) * 8;
      canvas.drawLine(
          Offset(cx, cy - h / 2 + 26), Offset(cx + aw + 12, cy - h / 2 + 38), lp);
      canvas.drawLine(
          Offset(cx, cy - h / 2 + 26), Offset(cx - aw - 12, cy - h / 2 + 38), lp);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  OBSTACLE
// ═══════════════════════════════════════════════════════════
class Obstacle extends PositionComponent {
  final RunnerGame gameRef;
  final int lane;
  final ObstacleType type;

  Obstacle({required this.gameRef, required this.lane, required this.type})
      : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    x = gameRef.laneCenters[lane];
    y = -40;
    switch (type) {
      case ObstacleType.standard:
        size = Vector2(gameRef.laneWidth * 0.55, 44);
      case ObstacleType.low:
        size = Vector2(gameRef.laneWidth * 0.65, 22);
      case ObstacleType.high:
        size = Vector2(gameRef.laneWidth * 0.6, 44);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    y += gameRef.currentSpeed * dt;
    if (y > gameRef.size.y + 60) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: width, height: height);

    Color fill, border;
    switch (type) {
      case ObstacleType.standard:
        fill = const Color(0xFF1A0A0A);
        border = const Color(0xFFE84040);
      case ObstacleType.low:
        fill = const Color(0xFF0F1A0A);
        border = const Color(0xFFFF6B35);
      case ObstacleType.high:
        fill = const Color(0xFF0A0A1F);
        border = const Color(0xFFAB47BC);
    }

    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // glow
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(6)),
        Paint()
          ..color = border.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // directional hints
    if (type == ObstacleType.low) {
      final arrow = Path()
        ..moveTo(cx - 4, cy + 3)
        ..lineTo(cx, cy - 4)
        ..lineTo(cx + 4, cy + 3);
      canvas.drawPath(
          arrow,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    } else if (type == ObstacleType.high) {
      final arrow = Path()
        ..moveTo(cx - 4, cy - 3)
        ..lineTo(cx, cy + 4)
        ..lineTo(cx + 4, cy - 3);
      canvas.drawPath(
          arrow,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  COIN
// ═══════════════════════════════════════════════════════════
class GameCoin extends PositionComponent {
  final RunnerGame gameRef;
  final int lane;

  GameCoin({required this.gameRef, required this.lane, double startY = -20})
      : super(anchor: Anchor.center, size: Vector2.all(20)) {
    y = startY;
  }

  @override
  Future<void> onLoad() async {
    x = gameRef.laneCenters[lane];
  }

  @override
  void update(double dt) {
    super.update(dt);
    y += gameRef.currentSpeed * dt;
    if (y > gameRef.size.y + 30) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // glow
    canvas.drawCircle(
        Offset(cx, cy),
        14,
        Paint()
          ..color = const Color(0xFFF05A28).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // body
    canvas.drawCircle(
        Offset(cx, cy), 10, Paint()..color = const Color(0xFFF05A28));
    // shine
    canvas.drawCircle(Offset(cx - 2, cy - 2), 4,
        Paint()..color = const Color(0xFFFF9050).withValues(alpha: 0.65));
    // ring
    canvas.drawCircle(
        Offset(cx, cy),
        10,
        Paint()
          ..color = const Color(0xFFFF7A45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }
}

// ═══════════════════════════════════════════════════════════
//  POWER-UP
// ═══════════════════════════════════════════════════════════
class GamePowerUp extends PositionComponent {
  final RunnerGame gameRef;
  final int lane;
  final PowerUpType type;
  double _pulse = 0;

  GamePowerUp(
      {required this.gameRef, required this.lane, required this.type})
      : super(anchor: Anchor.center, size: Vector2.all(32));

  @override
  Future<void> onLoad() async {
    x = gameRef.laneCenters[lane];
    y = -30;
  }

  @override
  void update(double dt) {
    super.update(dt);
    y += gameRef.currentSpeed * dt;
    _pulse += dt;
    if (y > gameRef.size.y + 40) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    Color color;
    String label;
    switch (type) {
      case PowerUpType.shield:
        color = const Color(0xFF4FC3F7);
        label = '🛡';
      case PowerUpType.magnet:
        color = const Color(0xFFAB47BC);
        label = '🧲';
      case PowerUpType.speedBoost:
        color = const Color(0xFFFFD54F);
        label = '⚡';
    }

    final r = 15.0 + sin(_pulse * 4) * 2.5;

    // outer glow
    canvas.drawCircle(
        Offset(cx, cy),
        r + 6,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // body
    canvas.drawCircle(
        Offset(cx, cy), r, Paint()..color = color.withValues(alpha: 0.85));
    // border
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // emoji
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}
