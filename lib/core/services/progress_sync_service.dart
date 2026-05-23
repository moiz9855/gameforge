import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressSyncService {
  ProgressSyncService._();
  static final ProgressSyncService instance = ProgressSyncService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if the user is authenticated with Supabase.
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Get the current user's ID, if authenticated.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Saves progress offline first, then attempts to sync to Supabase.
  Future<void> saveProgress(
    String gameId, {
    int highScore = 0,
    int levelsCompleted = 0,
    Map<String, dynamic>? extraData,
  }) async {
    await init();
    
    // 1. Save locally to SharedPreferences first
    final currentHigh = _prefs?.getInt('${gameId}_hs') ?? 0;
    if (highScore > currentHigh) {
      await _prefs?.setInt('${gameId}_hs', highScore);
    }
    
    final currentLevels = _prefs?.getInt('${gameId}_levels_completed') ?? 0;
    if (levelsCompleted > currentLevels) {
      await _prefs?.setInt('${gameId}_levels_completed', levelsCompleted);
    }

    if (extraData != null) {
      final String extraKey = '${gameId}_extra_data';
      final existingStr = _prefs?.getString(extraKey);
      Map<String, dynamic> existing = {};
      if (existingStr != null) {
        try {
          existing = jsonDecode(existingStr) as Map<String, dynamic>;
        } catch (_) {}
      }
      
      // Merge maps (e.g. merging level stars)
      existing.addAll(extraData);
      await _prefs?.setString(extraKey, jsonEncode(existing));
    }

    // 2. Queue for upload or upload immediately if online
    if (isAuthenticated) {
      try {
        final userId = currentUserId;
        if (userId != null) {
          final localHigh = _prefs?.getInt('${gameId}_hs') ?? highScore;
          final localLevels = _prefs?.getInt('${gameId}_levels_completed') ?? levelsCompleted;
          
          final String extraKey = '${gameId}_extra_data';
          final localExtraStr = _prefs?.getString(extraKey);
          final localExtra = localExtraStr != null ? jsonDecode(localExtraStr) : (extraData ?? {});

          await _supabase.from('user_game_progress').upsert({
            'user_id': userId,
            'game_id': gameId,
            'high_score': localHigh,
            'levels_completed': localLevels,
            'extra_data': localExtra,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id, game_id');
          
          debugPrint('Successfully synced progress online for $gameId');
        }
      } catch (e) {
        debugPrint('Offline mode or failed to sync progress online for $gameId: $e');
        // Silent fail: progress is cached locally and will retry or load upon next sync
      }
    }
  }

  /// Pulls the latest progress from Supabase and merges it into local SharedPreferences.
  Future<void> syncFromSupabase() async {
    await init();
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('Sync skipped: No authenticated user.');
      return;
    }

    try {
      debugPrint('Syncing game progress from Supabase for user $userId...');
      final List<dynamic> response = await _supabase
          .from('user_game_progress')
          .select()
          .eq('user_id', userId);

      for (final row in response) {
        final gameId = row['game_id'] as String;
        final remoteHigh = row['high_score'] as int? ?? 0;
        final remoteLevels = row['levels_completed'] as int? ?? 0;
        final remoteExtra = row['extra_data'] as Map<String, dynamic>? ?? {};

        // Merge high score
        final localHigh = _prefs?.getInt('${gameId}_hs') ?? 0;
        if (remoteHigh > localHigh) {
          await _prefs?.setInt('${gameId}_hs', remoteHigh);
        }

        // Merge levels completed
        final localLevels = _prefs?.getInt('${gameId}_levels_completed') ?? 0;
        if (remoteLevels > localLevels) {
          await _prefs?.setInt('${gameId}_levels_completed', remoteLevels);
        }

        // Merge extra_data
        final String extraKey = '${gameId}_extra_data';
        final localExtraStr = _prefs?.getString(extraKey);
        Map<String, dynamic> localExtra = {};
        if (localExtraStr != null) {
          try {
            localExtra = jsonDecode(localExtraStr) as Map<String, dynamic>;
          } catch (_) {}
        }
        
        // Merge remote keys that are newer or not present locally
        remoteExtra.forEach((key, val) {
          // If local has it, let's keep the maximum or just merge them
          if (localExtra.containsKey(key)) {
            // Check if values are comparable (like star ratings)
            final localVal = localExtra[key];
            if (localVal is num && val is num) {
              if (val > localVal) localExtra[key] = val;
            } else {
              localExtra[key] = val;
            }
          } else {
            localExtra[key] = val;
          }
        });
        
        await _prefs?.setString(extraKey, jsonEncode(localExtra));
      }
      debugPrint('Sync from Supabase completed successfully!');
    } catch (e) {
      debugPrint('Error syncing from Supabase: $e');
    }
  }

  /// Retrieve the locally stored stats for a game.
  Future<Map<String, dynamic>> getLocalStats(String gameId) async {
    await init();
    final hs = _prefs?.getInt('${gameId}_hs') ?? 0;
    final lc = _prefs?.getInt('${gameId}_levels_completed') ?? 0;
    final extraStr = _prefs?.getString('${gameId}_extra_data');
    Map<String, dynamic> extra = {};
    if (extraStr != null) {
      try {
        extra = jsonDecode(extraStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {
      'high_score': hs,
      'levels_completed': lc,
      'extra_data': extra,
    };
  }
}
