import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'engine.dart';

class PlatformComponent extends PositionComponent with CollisionCallbacks {
  PlatformComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = AppColors.textSecondary.withOpacity(0.8);
    canvas.drawRect(size.toRect(), paint);
    
    // Border
    final borderPaint = Paint()
      ..color = AppColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);
  }
}

class CoinComponent extends PositionComponent with CollisionCallbacks, HasGameRef<GameForgeEngine> {
  CoinComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = AppColors.warning.withOpacity(0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(20)),
      paint,
    );
    
    // Border
    final borderPaint = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(20)),
      borderPaint,
    );
  }

  void collect() {
    gameRef.incrementScore();
    removeFromParent();
  }
}

class ObstacleComponent extends PositionComponent with CollisionCallbacks, HasGameRef<GameForgeEngine> {
  ObstacleComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = AppColors.error.withOpacity(0.8);
    canvas.drawRect(size.toRect(), paint);
    
    // Border
    final borderPaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);
  }
}

class PlayerComponent extends PositionComponent with KeyboardHandler, CollisionCallbacks, HasGameRef<GameForgeEngine> {
  Vector2 velocity = Vector2.zero();
  final double gravity = 900;
  final double jumpSpeed = -400;
  final double moveSpeed = 200;
  
  bool isJumping = false;
  bool isMovingLeft = false;
  bool isMovingRight = false;
  
  final Vector2 startPosition;

  PlayerComponent({required this.startPosition, required Vector2 size})
      : super(position: startPosition, size: size) {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = AppColors.fire2.withOpacity(0.8);
    canvas.drawRect(size.toRect(), paint);
    
    // Glow effect
    final shadowPaint = Paint()
      ..color = AppColors.fire2.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(size.toRect(), shadowPaint);
    
    // Border
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Apply gravity
    velocity.y += gravity * dt;
    
    // Apply horizontal movement (Virtual buttons OR keyboard)
    if (isMovingLeft) {
      velocity.x = -moveSpeed;
    } else if (isMovingRight) {
      velocity.x = moveSpeed;
    } else {
      velocity.x = 0;
    }

    position += velocity * dt;

    // Floor boundary fallback
    if (position.y > gameRef.size.y) {
      die();
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    isMovingLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    isMovingRight = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    
    if (keysPressed.contains(LogicalKeyboardKey.space) || keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      jump();
    }
    return true;
  }

  void jump() {
    if (!isJumping) {
      velocity.y = jumpSpeed;
      isJumping = true;
    }
  }

  void moveLeft(bool moving) => isMovingLeft = moving;
  void moveRight(bool moving) => isMovingRight = moving;

  void die() {
    position = startPosition.clone();
    velocity = Vector2.zero();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is PlatformComponent) {
      // Very basic AABB resolution
      if (velocity.y > 0 && position.y + size.y / 2 < other.position.y) {
        // Landed on top
        position.y = other.position.y - size.y;
        velocity.y = 0;
        isJumping = false;
      } else if (velocity.y < 0 && position.y > other.position.y + other.size.y / 2) {
        // Hit bottom
        position.y = other.position.y + other.size.y;
        velocity.y = 0;
      } else if (velocity.x > 0 && position.x < other.position.x) {
        // Hit left
        position.x = other.position.x - size.x;
        velocity.x = 0;
      } else if (velocity.x < 0 && position.x > other.position.x) {
        // Hit right
        position.x = other.position.x + other.size.x;
        velocity.x = 0;
      }
    } else if (other is CoinComponent) {
      other.collect();
    } else if (other is ObstacleComponent) {
      die();
    }
  }
}
