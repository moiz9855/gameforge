import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/multiplayer/shared/friend_invite_panel.dart';

/// Waits until white + black presence then navigates into [ChessScreen].
class ChessWaitingRoom extends StatefulWidget {
  final String roomCode;
  final bool isCreator;

  const ChessWaitingRoom({
    super.key,
    required this.roomCode,
    required this.isCreator,
  });

  @override
  State<ChessWaitingRoom> createState() => _ChessWaitingRoomState();
}

class _ChessWaitingRoomState extends State<ChessWaitingRoom>
    with SingleTickerProviderStateMixin {
  RealtimeChannel? _channel;

  // Track which roles are present using a local set
  final Set<String> _presentRoles = {};

  bool _wentToGame = false;
  late AnimationController _pulse;

  bool get _whiteHere => _presentRoles.contains('white');
  bool get _blackHere => _presentRoles.contains('black');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  Future<void> _subscribe() async {
    final myRole = widget.isCreator ? 'white' : 'black';
    final ch = Supabase.instance.client.channel('chess:${widget.roomCode}');
    _channel = ch;

    ch
        // When a new player joins
        .onPresenceJoin((payload) {
          if (!mounted) return;
          _extractRolesFromPresences(payload.newPresences);
          _checkAndStart();
        })
        // When a player leaves
        .onPresenceLeave((payload) {
          if (!mounted) return;
          for (final p in payload.leftPresences) {
            final role = _roleFromPresence(p);
            if (role != null) {
              setState(() => _presentRoles.remove(role));
            }
          }
        })
        // Full sync (initial state when we first connect)
        .onPresenceSync((_) {
          if (!mounted) return;
          _syncFromPresenceState();
          _checkAndStart();
        })
        .subscribe((status, [err]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Track our own presence
            await ch.track({'role': myRole});
          }
        });
  }

  /// Extract roles from a list of Presence objects (from join payload)
  void _extractRolesFromPresences(List<Presence> presences) {
    for (final p in presences) {
      final role = _roleFromPresence(p);
      if (role != null) {
        setState(() => _presentRoles.add(role));
      }
    }
  }

  /// Pull 'role' from a single Presence object
  String? _roleFromPresence(Presence p) {
    final role = p.payload['role'];
    if (role is String && role.isNotEmpty) return role;
    return null;
  }

  /// Called on presenceSync — rebuild the full set from scratch
  void _syncFromPresenceState() {
    final state = _channel?.presenceState();
    if (state is! Map) return;
    final Set<String> roles = {};
    for (final presenceList in (state as Map).values) {
      if (presenceList is List) {
        for (final p in presenceList) {
          if (p is Presence) {
            final role = _roleFromPresence(p);
            if (role != null) roles.add(role);
          }
        }
      }
    }
    setState(() {
      _presentRoles
        ..clear()
        ..addAll(roles);
    });
  }

  void _checkAndStart() {
    if (_wentToGame || !_whiteHere || !_blackHere) return;
    _wentToGame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/chess/${widget.roomCode}?creator=${widget.isCreator}');
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WAITING ROOM',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.roomCode,
              textAlign: TextAlign.center,
              style: GoogleFonts.pressStart2p(
                fontSize: 28,
                color: AppColors.primary,
                letterSpacing: 6,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _PlayerWaitCard(
                    label: 'White',
                    subtitle: 'Host',
                    joined: _whiteHere,
                    pulse: _pulse,
                    accent: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PlayerWaitCard(
                    label: 'Black',
                    subtitle: 'Guest',
                    joined: _blackHere,
                    pulse: _pulse,
                    accent: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Match starts automatically when both players are here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            if (widget.isCreator) ...[
              const SizedBox(height: 24),
              FriendInvitePanel(roomCode: widget.roomCode, gameType: 'chess'),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerWaitCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool joined;
  final AnimationController pulse;
  final Color accent;

  const _PlayerWaitCard({
    required this.label,
    required this.subtitle,
    required this.joined,
    required this.pulse,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final border = joined ? AppColors.success : AppColors.border;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: joined ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!joined)
                FadeTransition(
                  opacity: pulse.drive(Tween(begin: 0.35, end: 1)),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            joined ? 'Joined' : 'Waiting…',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: joined ? AppColors.success : accent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
