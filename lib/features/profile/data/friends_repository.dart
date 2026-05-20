import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(Supabase.instance.client);
});

class FriendsRepository {
  final SupabaseClient _supabase;

  FriendsRepository(this._supabase);

  /// Send a friend request by Friend ID (format: "Username#XXXX")
  Future<void> sendRequest(String friendIdRaw) async {
    final fromId = _supabase.auth.currentUser!.id;

    final parts = friendIdRaw.trim().split('#');
    if (parts.length != 2 || parts[1].isEmpty) {
      throw Exception('Invalid Friend ID. Format must be Username#XXXX');
    }
    final username = parts[0];
    final idPrefix = parts[1].toLowerCase(); // UUID is stored lowercase

    // 1. Find candidate users by username (all matches)
    final res = await _supabase
        .from('users')
        .select('id, username')
        .eq('username', username);

    final candidates = (res as List).where((row) {
      // 2. Filter by UUID prefix in Dart (avoids LIKE on uuid column → 42883)
      final id = (row['id'] as String).toLowerCase();
      return id.startsWith(idPrefix);
    }).toList();

    if (candidates.isEmpty) {
      throw Exception('User not found. Check the ID and try again.');
    }
    final toId = candidates.first['id'] as String;

    if (toId == fromId) throw Exception('You cannot add yourself');

    // Check for duplicate request
    final existing = await _supabase
        .from('friend_requests')
        .select('id')
        .or('and(from_user_id.eq.$fromId,to_user_id.eq.$toId),'
            'and(from_user_id.eq.$toId,to_user_id.eq.$fromId)');

    if ((existing as List).isNotEmpty) {
      throw Exception('Request already exists or you are already friends');
    }

    await _supabase.from('friend_requests').insert({
      'from_user_id': fromId,
      'to_user_id': toId,
      'status': 'pending',
    });
  }

  Future<void> acceptRequest(String requestId) async {
    await _supabase
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  Future<void> declineRequest(String requestId) async {
    await _supabase
        .from('friend_requests')
        .delete()
        .eq('id', requestId);
  }

  /// Outgoing requests you’ve sent that are still pending.
  Future<List<Map<String, dynamic>>> getOutgoingPending() async {
    final myId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('friend_requests')
        .select(
            'id, created_at, to_user:users!friend_requests_to_user_id_fkey(id, username)')
        .eq('from_user_id', myId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Incoming pending requests — now uses public FK hint so PostgREST
  /// can resolve the join (PGRST200 fix).
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final myId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('friend_requests')
        .select('id, created_at, from_user:users!friend_requests_from_user_id_fkey(id, username)')
        .eq('to_user_id', myId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Accepted friends list
  Future<List<Map<String, dynamic>>> getFriends() async {
    final myId = _supabase.auth.currentUser!.id;

    // Requests I sent that were accepted
    final sentRes = await _supabase
        .from('friend_requests')
        .select('id, to_user:users!friend_requests_to_user_id_fkey(id, username)')
        .eq('from_user_id', myId)
        .eq('status', 'accepted');

    // Requests I received that were accepted
    final recRes = await _supabase
        .from('friend_requests')
        .select('id, from_user:users!friend_requests_from_user_id_fkey(id, username)')
        .eq('to_user_id', myId)
        .eq('status', 'accepted');

    final friends = <Map<String, dynamic>>[];
    for (final row in (sentRes as List)) {
      if (row['to_user'] != null) friends.add(Map<String, dynamic>.from(row['to_user']));
    }
    for (final row in (recRes as List)) {
      if (row['from_user'] != null) friends.add(Map<String, dynamic>.from(row['from_user']));
    }
    return friends;
  }
}
