import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_logic.dart';
import 'package:game_forge/features/multiplayer/shared/friend_invite_panel.dart';

/// Cross-shaped lobby until `numPlayers` unique seat indices are present.
class LudoWaitingRoom extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int numPlayers;
  final int myPlayerIdx;

  const LudoWaitingRoom({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.numPlayers,
    required this.myPlayerIdx,
  });

  @override
  State<LudoWaitingRoom> createState() => _LudoWaitingRoomState();
}

class _LudoWaitingRoomState extends State<LudoWaitingRoom> {
  RealtimeChannel? _channel;
  final Set<int> _seen = {};
  bool _started = false;

  static const List<Color> _dots = [
    Color(0xFFE53935),
    Color(0xFF2563EB),
    Color(0xFFFFD54F),
    Color(0xFF27C96A),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  Future<void> _subscribe() async {
    final ch = Supabase.instance.client.channel('ludo:${widget.roomCode}');
    _channel = ch;

    ch.onPresenceSync((_) => _syncPresence()).subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({'player': widget.myPlayerIdx});
        _syncPresence();
      }
    });
  }

  void _syncPresence() {
    if (!mounted || _started) return;
    try {
      final raw = _channel?.presenceState();
      final presence = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final online = _parsePresencePlayers(presence);
      setState(() => _seen
        ..clear()
        ..addAll(online));

      if (online.length >= widget.numPlayers) {
        _started = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go(
            '/ludo/${widget.roomCode}?creator=${widget.isCreator}'
            '&players=${widget.numPlayers}&myIdx=${widget.myPlayerIdx}',
          );
        });
      }
    } catch (_) {}
  }

  Set<int> _parsePresencePlayers(Map<String, dynamic> presence) {
    final Set<int> indices = {};
    for (final val in presence.values) {
      if (val is List) {
        for (final dynamic p in val) {
          try {
            final payload = p.payload as Map?;
            if (payload != null) {
              final playerIdx = payload['player'];
              if (playerIdx is int) indices.add(playerIdx);
            }
          } catch (_) {
            if (p is Map) {
              final playerIdx = p['player'];
              if (playerIdx is int) indices.add(playerIdx);
            }
          }
        }
      }
    }
    return indices;
  }

  @override
  void dispose() {
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }

  /// Seat positions around cross for up to 4 players.
  List<(Alignment, int)> _slotsForCount(int n) {
    switch (n) {
      case 2:
        return [(Alignment.topCenter, 0), (Alignment.bottomCenter, 1)];
      case 3:
        return [
          (Alignment.topCenter, 0),
          (Alignment.centerLeft, 1),
          (Alignment.bottomCenter, 2),
        ];
      default:
        return [
          (Alignment.topCenter, 0),
          (Alignment.centerLeft, 1),
          (Alignment.bottomCenter, 2),
          (Alignment.centerRight, 3),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slotsForCount(widget.numPlayers);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.roomCode,
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                fontSize: 22,
                color: AppColors.primary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for players (${_seen.length}/${widget.numPlayers})',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...slots.map((s) {
                        final alignment = s.$1;
                        final idx = s.$2;
                        final filled = _seen.contains(idx);
                        return Align(
                          alignment: alignment,
                          child: _SeatOrb(
                            color: _dots[idx],
                            label: kPlayerNames[idx],
                            filled: filled,
                          ),
                        );
                      }),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.fireGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.casino, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.isCreator)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child:               FriendInvitePanel(
                  roomCode: widget.roomCode,
                  gameType: 'ludo',
                  ludoPlayerCount: widget.numPlayers,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeatOrb extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _SeatOrb({
    required this.color,
    required this.label,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: filled ? 1 : 0.35,
          child: Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: filled ? color : AppColors.border,
                width: filled ? 2 : 1,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 14,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.25),
                  child: Text(
                    label[0],
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
