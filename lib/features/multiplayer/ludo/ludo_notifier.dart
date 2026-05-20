import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ludo_logic.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
final ludoRoomProvider = StateProvider<String>((ref) => '');
final ludoIsCreatorProvider = StateProvider<bool>((ref) => true);
final ludoNumPlayersProvider = StateProvider<int>((ref) => 2);
final ludoMyPlayerIdxProvider = StateProvider<int>((ref) => 0);

final ludoNotifierProvider =
    StateNotifierProvider.autoDispose<LudoNotifier, LudoState>((ref) {
  final roomCode = ref.watch(ludoRoomProvider);
  final numPlayers = ref.watch(ludoNumPlayersProvider);
  final myIdx = ref.watch(ludoMyPlayerIdxProvider);
  return LudoNotifier(
      roomCode: roomCode, numPlayers: numPlayers, myPlayerIdx: myIdx);
});

// ─── Notifier ─────────────────────────────────────────────────────────────────
class LudoNotifier extends StateNotifier<LudoState> {
  final String roomCode;
  final int numPlayers;
  final int myPlayerIdx;

  RealtimeChannel? _channel;

  /// Guard against applying the same broadcast event twice (race condition).
  String? _lastAppliedEventId;

  LudoNotifier({
    required this.roomCode,
    required this.numPlayers,
    required this.myPlayerIdx,
  }) : super(LudoState.initial(numPlayers)) {
    if (roomCode.isNotEmpty) _subscribe();
  }

  bool get isMyTurn =>
      state.currentPlayer == myPlayerIdx && !state.gameOver;

  // ─── Supabase channel setup ───────────────────────────────────────────────

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('ludo:$roomCode')
        // ── Dice broadcast ──────────────────────────────────────────────────
        .onBroadcast(
          event: 'dice',
          callback: (raw) {
            try {
              // Guard: ignore echoes of own rolls
              if (state.currentPlayer == myPlayerIdx) return;
              final data = _unwrap(raw);
              final eventId = data['eid'] as String?;
              if (eventId != null && eventId == _lastAppliedEventId) return;
              _lastAppliedEventId = eventId;

              final dice = data['value'] as int;
              state = state.copyWith(
                lastDice: dice,
                mustRollDice: false,
                statusMsg:
                    '${kPlayerNames[state.currentPlayer]} rolled $dice',
              );

              // Auto-pass if no movable tokens
              final movable = movableTokens(state, dice);
              if (movable.isEmpty) {
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (!mounted) return;
                  _advanceTurn(dice, bonus: false);
                });
              }
            } catch (_) {}
          },
        )
        // ── Move broadcast ──────────────────────────────────────────────────
        .onBroadcast(
          event: 'move',
          callback: (raw) {
            try {
              if (state.currentPlayer == myPlayerIdx) return;
              final data = _unwrap(raw);
              final eventId = data['eid'] as String?;
              if (eventId != null && eventId == _lastAppliedEventId) return;
              _lastAppliedEventId = eventId;

              final tokenIdx = data['token'] as int;
              final dice = data['dice'] as int;
              if (!state.gameOver) {
                state = applyMove(state, tokenIdx, dice);
              }
            } catch (_) {}
          },
        )
        // ── Presence sync — win-on-disconnect ───────────────────────────────
        .onPresenceSync((_) {
            if (state.gameOver) return;
            try {
              final rawPresence = _channel?.presenceState();
              final presence = (rawPresence as Map?)?.cast<String, dynamic>() ?? {};
              final onlinePlayerIndices = _parsePresencePlayers(presence);
              // Check which active players are no longer online
              for (final pi in List<int>.from(state.activePlayers)) {
                if (!onlinePlayerIndices.contains(pi)) {
                  state = removePlayer(state, pi);
                  if (state.gameOver) return;
                }
              }
            } catch (_) {}
          })
        .subscribe((status, [err]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Track own presence so others can detect our connection
            await _channel?.track({'player': myPlayerIdx});
          }
        });
  }

  // ─── Public actions ───────────────────────────────────────────────────────

  /// Called when local player rolls the dice.
  Future<int> rollDice() async {
    if (!isMyTurn || !state.mustRollDice) return 0;
    final dice = 1 + Random().nextInt(6);
    final eid = '${myPlayerIdx}_${DateTime.now().millisecondsSinceEpoch}';
    _lastAppliedEventId = eid;

    state = state.copyWith(
      lastDice: dice,
      mustRollDice: false,
      statusMsg: '${kPlayerNames[myPlayerIdx]} rolled $dice',
    );

    await _channel?.sendBroadcastMessage(
      event: 'dice',
      payload: {'value': dice, 'eid': eid},
    );

    // Auto-pass if no movable tokens
    final movable = movableTokens(state, dice);
    if (movable.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      _advanceTurn(dice, bonus: false);
      await _channel?.sendBroadcastMessage(
        event: 'pass',
        payload: {'from': myPlayerIdx, 'eid': eid},
      );
    }

    return dice;
  }

  /// Called when local player taps a token to move.
  Future<void> moveToken(int tokenIdx) async {
    final dice = state.lastDice;
    if (dice == null || state.mustRollDice || !isMyTurn) return;

    final eid = '${myPlayerIdx}_${DateTime.now().millisecondsSinceEpoch}';
    _lastAppliedEventId = eid;

    state = applyMove(state, tokenIdx, dice);

    await _channel?.sendBroadcastMessage(
      event: 'move',
      payload: {'token': tokenIdx, 'dice': dice, 'eid': eid},
    );
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Supabase wraps broadcast data under a nested 'payload' key.
  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    if (inner is Map<String, dynamic>) return inner;
    return raw;
  }

  /// Advance turn without a token move (pass turn).
  void _advanceTurn(int dice, {required bool bonus}) {
    if (state.gameOver) return;
    final currentSlot = state.currentTurnSlot;
    final nextSlot = bonus
        ? currentSlot
        : (currentSlot + 1) % state.activePlayers.length;
    final nextPlayer = state.activePlayers[nextSlot];
    state = state.copyWith(
      currentTurnSlot: nextSlot,
      mustRollDice: true,
      bonusTurn: false,
      statusMsg: '${kPlayerNames[nextPlayer]}\'s turn — Roll the dice!',
    );
  }

  /// Parse presence state to extract which player indices are online.
  Set<int> _parsePresencePlayers(Map<String, dynamic> presence) {
    final Set<int> online = {};
    for (final val in presence.values) {
      if (val is List) {
        for (final dynamic p in val) {
          try {
            final payload = p.payload as Map?;
            if (payload != null) {
              final playerIdx = payload['player'];
              if (playerIdx is int) online.add(playerIdx);
            }
          } catch (_) {
            if (p is Map) {
              final playerIdx = p['player'];
              if (playerIdx is int) online.add(playerIdx);
            }
          }
        }
      }
    }
    return online;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
