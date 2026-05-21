import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_forge/core/services/sound_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String badge;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    this.isUnlocked = false,
  });

  Achievement copyWith({bool? isUnlocked}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      badge: badge,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class AchievementService {
  AchievementService._();
  static final AchievementService instance = AchievementService._();

  SharedPreferences? _prefs;
  final Set<String> _unlockedIds = {};
  
  final StreamController<Achievement> _unlockController = StreamController<Achievement>.broadcast();
  Stream<Achievement> get onAchievementUnlocked => _unlockController.stream;

  final List<Achievement> _definitions = [
    Achievement(
      id: 'first_coin',
      title: 'First Coin',
      description: 'Insert a coin to boot the Solo Arcade system.',
      badge: '🪙',
    ),
    Achievement(
      id: 'snake_apprentice',
      title: 'Snake Apprentice',
      description: 'Reach a score of 10 in Snake.',
      badge: '🐍',
    ),
    Achievement(
      id: 'snake_master',
      title: 'Snake Master',
      description: 'Reach a score of 30 in Snake.',
      badge: '👑',
    ),
    Achievement(
      id: 'block_stacker',
      title: 'Block Stacker',
      description: 'Score 500 points in Tetris.',
      badge: '🧱',
    ),
    Achievement(
      id: 'tetris_survivor',
      title: 'Tetris Survivor',
      description: 'Score 1,500 points in Tetris.',
      badge: '👾',
    ),
    Achievement(
      id: 'pong_champion',
      title: 'Pong Champion',
      description: 'Win a Pong match against the AI opponent.',
      badge: '🏓',
    ),
    Achievement(
      id: 'paddle_master',
      title: 'Paddle Master',
      description: 'Win Pong against AI, conceding 1 point or less.',
      badge: '⚡',
    ),
    Achievement(
      id: 'first_flight',
      title: 'First Flight',
      description: 'Score 5 points in Flappy Bird.',
      badge: '🐤',
    ),
    Achievement(
      id: 'sky_legend',
      title: 'Sky Legend',
      description: 'Score 20 points in Flappy Bird.',
      badge: '🦅',
    ),
  ];

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final unlocked = _prefs?.getStringList('unlocked_achievements') ?? [];
    _unlockedIds.addAll(unlocked);
  }

  /// Returns the list of all achievement definitions with updated unlock states.
  List<Achievement> getAchievements() {
    return _definitions.map((def) {
      return def.copyWith(isUnlocked: _unlockedIds.contains(def.id));
    }).toList();
  }

  /// Unlocks an achievement by ID, triggers sound and stream event.
  Future<void> unlock(String id) async {
    await init();
    if (_unlockedIds.contains(id)) return;

    _unlockedIds.add(id);
    await _prefs?.setStringList('unlocked_achievements', _unlockedIds.toList());

    final def = _definitions.firstWhere((element) => element.id == id);
    final unlockedAchievement = def.copyWith(isUnlocked: true);

    // Play retro achievement chime
    SoundService.instance.play(SoundType.achievement);

    // Emit event
    _unlockController.add(unlockedAchievement);
  }

  /// Resets all achievements and high scores (useful for testing or full reset).
  Future<void> resetAll() async {
    await init();
    _unlockedIds.clear();
    await _prefs?.remove('unlocked_achievements');
    await _prefs?.remove('retro_coin_inserted');
    await _prefs?.remove('snake_hs');
    await _prefs?.remove('tetris_hs');
    await _prefs?.remove('pong_hs');
    await _prefs?.remove('flappy_hs');
  }

  /// High score helper functions
  Future<int> getHighScore(String gameId) async {
    await init();
    return _prefs?.getInt('${gameId}_hs') ?? 0;
  }

  Future<void> saveHighScore(String gameId, int score) async {
    await init();
    final currentHigh = await getHighScore(gameId);
    if (score > currentHigh) {
      await _prefs?.setInt('${gameId}_hs', score);
      
      // Auto-check achievement thresholds based on high score updates
      if (gameId == 'snake') {
        if (score >= 10) await unlock('snake_apprentice');
        if (score >= 30) await unlock('snake_master');
      } else if (gameId == 'tetris') {
        if (score >= 500) await unlock('block_stacker');
        if (score >= 1500) await unlock('tetris_survivor');
      } else if (gameId == 'flappy') {
        if (score >= 5) await unlock('first_flight');
        if (score >= 20) await unlock('sky_legend');
      }
    }
  }

  /// Check if coin has been inserted this session or historically
  Future<bool> isCoinInserted() async {
    await init();
    return _prefs?.getBool('retro_coin_inserted') ?? false;
  }

  Future<void> insertCoin() async {
    await init();
    await _prefs?.setBool('retro_coin_inserted', true);
    await unlock('first_coin');
  }
}
