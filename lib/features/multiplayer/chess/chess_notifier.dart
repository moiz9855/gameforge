import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chess_logic.dart';

// ─── Providers ───────────────────────────────────────────────────────────────
final chessRoomProvider = StateProvider<String>((ref) => '');
final chessIsCreatorProvider = StateProvider<bool>((ref) => true);

final chessNotifierProvider =
    StateNotifierProvider.autoDispose<ChessNotifier, ChessState>((ref) {
  final roomCode = ref.watch(chessRoomProvider);
  final isCreator = ref.watch(chessIsCreatorProvider);
  return ChessNotifier(roomCode: roomCode, isCreator: isCreator);
});

// ─── White/Black timer providers (seconds remaining) ─────────────────────────
final whiteTimerProvider = StateProvider<int>((ref) => 600);
final blackTimerProvider = StateProvider<int>((ref) => 600);

// ─── Notifier ────────────────────────────────────────────────────────────────
class ChessNotifier extends StateNotifier<ChessState> {
  final String roomCode;
  final bool isCreator; // creator = white

  RealtimeChannel? _channel;

  /// Prevents replaying the same broadcast move twice (race guard).
  String? _lastAppliedMoveId;

  ChessNotifier({required this.roomCode, required this.isCreator})
      : super(ChessState.initial()) {
    if (roomCode.isNotEmpty) _subscribe();
  }

  PieceColor get myColor =>
      isCreator ? PieceColor.white : PieceColor.black;

  bool get isMyTurn => state.turn == myColor && !state.gameOver;

  // ─── Supabase channel setup ─────────────────────────────────────────────

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('chess:$roomCode')
        // ── Opponent move ───────────────────────────────────────────────────
        .onBroadcast(
          event: 'move',
          callback: (raw) {
            try {
              final data = _unwrap(raw);
              // Deduplication: ignore if we already applied this event
              final eid = data['eid'] as String?;
              if (eid != null && eid == _lastAppliedMoveId) return;
              _lastAppliedMoveId = eid;

              final from = Pos.fromJson(
                  Map<String, dynamic>.from(data['from'] as Map));
              final to = Pos.fromJson(
                  Map<String, dynamic>.from(data['to'] as Map));

              // Only apply if it is the opponent's turn
              if (state.turn != myColor && !state.gameOver) {
                state = applyMove(state, from, to);
              }
            } catch (_) {}
          },
        )
        .onPresenceSync((_) {
            if (state.gameOver) return;
            try {
              final presenceState = _channel?.presenceState();
              if (presenceState is! Map) return;
              final roles = <String>{};
              for (final list in (presenceState as Map).values) {
                if (list is List) {
                  for (final p in list) {
                    if (p is Presence) {
                      final role = p.payload['role'];
                      if (role is String) roles.add(role);
                    }
                  }
                }
              }
              // If we are the only player left, declare win by forfeit.
              if (roles.length == 1 && roles.contains(_myRole)) {
                state = state.copyWith(
                  gameOver: true,
                  winner: myColor,
                  statusMsg: 'Opponent left the game. You win by default!',
                );
              }
            } catch (_) {}
          })
        .subscribe((status, [err]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Announce our presence so the opponent can track our connection
            await _channel?.track({'role': _myRole});
          }
        });
  }

  // ─── Public actions ─────────────────────────────────────────────────────

  /// Called when the local player taps a valid move destination.
  Future<void> makeMove(Pos from, Pos to) async {
    if (!isMyTurn) return;
    final eid = '${_myRole}_${DateTime.now().millisecondsSinceEpoch}';
    _lastAppliedMoveId = eid;
    state = applyMove(state, from, to);
    await _channel?.sendBroadcastMessage(
      event: 'move',
      payload: {'from': from.toJson(), 'to': to.toJson(), 'eid': eid},
    );
  }

  /// Voluntary resignation.
  void forfeit() {
    state = state.copyWith(
      gameOver: true,
      winner: myColor == PieceColor.white ? PieceColor.black : PieceColor.white,
      statusMsg: '${myColor.name} resigned.',
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────

  String get _myRole => isCreator ? 'white' : 'black';

  /// Supabase wraps broadcast data under a nested 'payload' key.
  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    if (inner is Map<String, dynamic>) return inner;
    return raw;
  }




  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
