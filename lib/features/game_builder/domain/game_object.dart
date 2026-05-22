import 'package:flutter/material.dart';

enum GameObjectType { player, platform, coin, obstacle, enemy, spring, key, door }

class GameObject {
  final String id;
  final GameObjectType type;
  double x;
  double y;
  final double width;
  final double height;

  GameObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    double? width,
    double? height,
  })  : width = width ?? type.defaultWidth,
        height = height ?? type.defaultHeight;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory GameObject.fromJson(Map<String, dynamic> json) {
    return GameObject(
      id: json['id'] as String,
      type: GameObjectType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GameObjectType.platform,
      ),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );
  }

  GameObject copyWith({double? x, double? y}) {
    return GameObject(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
    );
  }
}

extension GameObjectTypeExt on GameObjectType {
  String get label {
    switch (this) {
      case GameObjectType.player:
        return 'Player';
      case GameObjectType.platform:
        return 'Platform';
      case GameObjectType.coin:
        return 'Coin';
      case GameObjectType.obstacle:
        return 'Obstacle';
      case GameObjectType.enemy:
        return 'Enemy';
      case GameObjectType.spring:
        return 'Spring';
      case GameObjectType.key:
        return 'Key';
      case GameObjectType.door:
        return 'Door';
    }
  }

  String get emoji {
    switch (this) {
      case GameObjectType.player:
        return '👤';
      case GameObjectType.platform:
        return '▬';
      case GameObjectType.coin:
        return '💰';
      case GameObjectType.obstacle:
        return '⚠️';
      case GameObjectType.enemy:
        return '👾';
      case GameObjectType.spring:
        return '🌀';
      case GameObjectType.key:
        return '🗝️';
      case GameObjectType.door:
        return '🚪';
    }
  }

  IconData get icon {
    switch (this) {
      case GameObjectType.player:
        return Icons.person;
      case GameObjectType.platform:
        return Icons.horizontal_rule;
      case GameObjectType.coin:
        return Icons.monetization_on;
      case GameObjectType.obstacle:
        return Icons.warning_rounded;
      case GameObjectType.enemy:
        return Icons.bug_report;
      case GameObjectType.spring:
        return Icons.arrow_upward;
      case GameObjectType.key:
        return Icons.vpn_key;
      case GameObjectType.door:
        return Icons.door_front_door;
    }
  }

  Color get color {
    switch (this) {
      case GameObjectType.player:
        return const Color(0xFFF05A28);
      case GameObjectType.platform:
        return const Color(0xFF6B7280);
      case GameObjectType.coin:
        return const Color(0xFFF5A623);
      case GameObjectType.obstacle:
        return const Color(0xFFE84040);
      case GameObjectType.enemy:
        return const Color(0xFFAF52DE);
      case GameObjectType.spring:
        return const Color(0xFF27C96A);
      case GameObjectType.key:
        return const Color(0xFFFFD700);
      case GameObjectType.door:
        return const Color(0xFF2563EB);
    }
  }

  double get defaultWidth {
    switch (this) {
      case GameObjectType.platform:
        return 80;
      case GameObjectType.door:
        return 40;
      default:
        return 40;
    }
  }

  double get defaultHeight {
    switch (this) {
      case GameObjectType.door:
        return 60;
      case GameObjectType.platform:
        return 20;
      default:
        return 40;
    }
  }
}
