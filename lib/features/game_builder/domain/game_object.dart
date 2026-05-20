enum GameObjectType { player, platform, coin, obstacle }

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
    this.width = 40,
    this.height = 40,
  });

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
      type: GameObjectType.values.firstWhere((e) => e.name == json['type']),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}
