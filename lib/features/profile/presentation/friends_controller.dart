import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_forge/features/profile/data/friends_repository.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';

final pendingRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return ref.watch(friendsRepositoryProvider).getPendingRequests();
});

final outgoingRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return ref.watch(friendsRepositoryProvider).getOutgoingPending();
});

final friendsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return ref.watch(friendsRepositoryProvider).getFriends();
});

final friendsControllerProvider = Provider<FriendsController>((ref) {
  return FriendsController(ref);
});

class FriendsController {
  final Ref _ref;
  
  FriendsController(this._ref);
  
  Future<void> sendRequest(String friendIdRaw) async {
    await _ref.read(friendsRepositoryProvider).sendRequest(friendIdRaw);
  }
  
  Future<void> acceptRequest(String requestId) async {
    await _ref.read(friendsRepositoryProvider).acceptRequest(requestId);
    _ref.invalidate(pendingRequestsProvider);
    _ref.invalidate(outgoingRequestsProvider);
    _ref.invalidate(friendsListProvider);
  }
  
  Future<void> declineRequest(String requestId) async {
    await _ref.read(friendsRepositoryProvider).declineRequest(requestId);
    _ref.invalidate(pendingRequestsProvider);
    _ref.invalidate(outgoingRequestsProvider);
  }

  Future<void> sendRequestAndRefresh(String raw) async {
    await sendRequest(raw);
    _ref.invalidate(outgoingRequestsProvider);
    _ref.invalidate(pendingRequestsProvider);
  }
}
