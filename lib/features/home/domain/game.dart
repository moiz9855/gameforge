class Game {
  final String id;
  final String title;
  final String creatorName;
  final String? thumbnailUrl;
  final String? description;
  final String difficulty;
  final int playCount;
  final int likeCount;

  Game({
    required this.id,
    required this.title,
    required this.creatorName,
    this.thumbnailUrl,
    this.description,
    this.difficulty = 'medium',
    this.playCount = 0,
    this.likeCount = 0,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    // Supabase join returns the related table as a nested map or list depending on the relationship.
    // Assuming 'users' is a single object because it's a many-to-one relationship (creator_id -> id)
    String username = 'Unknown';
    if (json['users'] != null) {
      if (json['users'] is Map) {
        username = json['users']['username'] ?? 'Unknown';
      } else if (json['users'] is List && json['users'].isNotEmpty) {
        username = json['users'][0]['username'] ?? 'Unknown';
      }
    }

    return Game(
      id: json['id'] as String,
      title: json['title'] as String,
      creatorName: username,
      thumbnailUrl: json['thumbnail_url'] as String?,
      description: json['description'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      playCount: json['play_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
    );
  }
}
