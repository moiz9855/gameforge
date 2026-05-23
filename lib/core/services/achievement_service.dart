import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/progress_sync_service.dart';


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
    Achievement(
      id: 'rps_streak',
      title: 'Predictor',
      description: 'Get a win streak of 5 in Rock Paper Scissors.',
      badge: '🧠',
    ),
    Achievement(
      id: 'ttt_hard',
      title: 'Unbeatable Draw',
      description: 'Draw or win against the Hard AI in Tic Tac Toe.',
      badge: '🛡️',
    ),
    Achievement(
      id: 'tow_speedrun',
      title: 'Rope Master',
      description: 'Win a Tug of War round in under 8 seconds.',
      badge: '💪',
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
    await _prefs?.remove('rps_wins');
    await _prefs?.remove('rps_best_streak');
    await _prefs?.remove('rps_current_streak');
    await _prefs?.remove('ttt_wins');
    await _prefs?.remove('ttt_losses');
    await _prefs?.remove('ttt_draws');
    await _prefs?.remove('tow_wins');
    await _prefs?.remove('tow_best_time');
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
    // Sync to Supabase in all cases
    await ProgressSyncService.instance.saveProgress(gameId, highScore: score);
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

  /// Rock Paper Scissors Stats
  Future<Map<String, int>> getRpsStats() async {
    await init();
    return {
      'wins': _prefs?.getInt('rps_wins') ?? 0,
      'best_streak': _prefs?.getInt('rps_best_streak') ?? 0,
    };
  }

  Future<void> saveRpsMatchResult({required bool won, required int currentStreak}) async {
    await init();
    final wins = (_prefs?.getInt('rps_wins') ?? 0) + (won ? 1 : 0);
    await _prefs?.setInt('rps_wins', wins);

    final bestStreak = _prefs?.getInt('rps_best_streak') ?? 0;
    if (currentStreak > bestStreak) {
      await _prefs?.setInt('rps_best_streak', currentStreak);
    }

    if (currentStreak >= 5) {
      await unlock('rps_streak');
    }

    final finalBest = _prefs?.getInt('rps_best_streak') ?? 0;
    await ProgressSyncService.instance.saveProgress(
      'rps',
      highScore: wins,
      extraData: {'wins': wins, 'best_streak': finalBest},
    );
  }

  Future<int> getRpsCurrentStreak() async {
    await init();
    return _prefs?.getInt('rps_current_streak') ?? 0;
  }

  Future<void> setRpsCurrentStreak(int streak) async {
    await init();
    await _prefs?.setInt('rps_current_streak', streak);
  }

  /// Tic Tac Toe Stats
  Future<Map<String, int>> getTttStats() async {
    await init();
    return {
      'wins': _prefs?.getInt('ttt_wins') ?? 0,
      'losses': _prefs?.getInt('ttt_losses') ?? 0,
      'draws': _prefs?.getInt('ttt_draws') ?? 0,
    };
  }

  Future<void> saveTttResult({required String result, required String difficulty}) async {
    await init();
    int wins = _prefs?.getInt('ttt_wins') ?? 0;
    int losses = _prefs?.getInt('ttt_losses') ?? 0;
    int draws = _prefs?.getInt('ttt_draws') ?? 0;

    if (result == 'win') {
      wins++;
      await _prefs?.setInt('ttt_wins', wins);
    } else if (result == 'loss') {
      losses++;
      await _prefs?.setInt('ttt_losses', losses);
    } else {
      draws++;
      await _prefs?.setInt('ttt_draws', draws);
    }

    if (difficulty == 'hard' && (result == 'win' || result == 'draw')) {
      await unlock('ttt_hard');
    }

    await ProgressSyncService.instance.saveProgress(
      'ttt',
      highScore: wins,
      extraData: {'wins': wins, 'losses': losses, 'draws': draws},
    );
  }

  /// Tug of War Stats
  Future<Map<String, dynamic>> getTowStats() async {
    await init();
    return {
      'wins': _prefs?.getInt('tow_wins') ?? 0,
      'best_time': _prefs?.getDouble('tow_best_time') ?? 999.9,
    };
  }

  Future<void> saveTowResult({required bool won, double? timeInSeconds}) async {
    await init();
    final wins = (_prefs?.getInt('tow_wins') ?? 0) + (won ? 1 : 0);
    if (won) {
      await _prefs?.setInt('tow_wins', wins);

      if (timeInSeconds != null) {
        final currentBest = _prefs?.getDouble('tow_best_time') ?? 999.9;
        if (timeInSeconds < currentBest) {
          await _prefs?.setDouble('tow_best_time', timeInSeconds);
        }
        if (timeInSeconds <= 8.0) {
          await unlock('tow_speedrun');
        }
      }
    }

    final finalBestTime = _prefs?.getDouble('tow_best_time') ?? 999.9;
    await ProgressSyncService.instance.saveProgress(
      'tow',
      highScore: wins,
      extraData: {'wins': wins, 'best_time': finalBestTime},
    );
  }
}
