import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';

final gameInviteServiceProvider = Provider<GameInviteService>((ref) {
  final user = ref.watch(authRepositoryProvider).currentUser;
  return GameInviteService(
    supabase: Supabase.instance.client,
    myUsername: user?.userMetadata?['username'] ?? 'Unknown',
    myUserId: user?.id ?? '',
  );
});

class GameInviteService {
  final SupabaseClient supabase;
  final String myUsername;
  final String myUserId;

  GameInviteService({
    required this.supabase,
    required this.myUsername,
    required this.myUserId,
  });

  /// Sends a real-time game invite to a specific friend via Broadcast.
  Future<void> sendInvite({
    required String friendId,
    required String roomCode,
    required String gameType, // 'chess' or 'ludo'
    int? ludoPlayers,
  }) async {
    final channel = supabase.channel('invites:$friendId');
    channel.subscribe();
    final payload = {
      'from_username': myUsername,
      'from_user_id': myUserId,
      'room_code': roomCode,
      'game_type': gameType,
      if (ludoPlayers != null) 'players': ludoPlayers,
      if (gameType == 'ludo') 'my_idx': 1,
    };
    await channel.sendBroadcastMessage(
      event: 'game-invite',
      payload: payload,
    );
    await channel.unsubscribe();
  }
}
