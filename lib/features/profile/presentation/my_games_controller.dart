import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/features/home/domain/game.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';

final myGamesProvider = FutureProvider<List<Game>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('games')
      .select('*, users(username)')
      .eq('creator_id', user.id)
      .order('created_at', ascending: false);
      
  return (response as List).map((json) => Game.fromJson(json)).toList();
});

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref);
});

class ProfileController {
  final Ref _ref;

  ProfileController(this._ref);

  Future<void> deleteGame(String gameId) async {
    await Supabase.instance.client
        .from('games')
        .delete()
        .eq('id', gameId);

    // Invalidate so the FutureProvider re-fetches immediately
    _ref.invalidate(myGamesProvider);
  }
}
