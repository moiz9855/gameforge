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
  bool _whiteHere = false;
  bool _blackHere = false;
  bool _wentToGame = false;
  late AnimationController _pulse;

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
    final ch = Supabase.instance.client.channel('chess:${widget.roomCode}');
    _channel = ch;

    ch.onPresenceSync((_) => _syncPresence()).subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({'role': widget.isCreator ? 'white' : 'black'});
        _syncPresence();
      }
    });
  }

  void _syncPresence() {
    if (!mounted || _wentToGame) return;
    try {
      final raw = _channel?.presenceState();
      final presence = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final roles = _parsePresenceRoles(presence);
      final w = roles.contains('white');
      final b = roles.contains('black');
      setState(() {
        _whiteHere = w;
        _blackHere = b;
      });
      if (w && b) {
        _wentToGame = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go('/chess/${widget.roomCode}?creator=${widget.isCreator}');
        });
      }
    } catch (_) {}
  }

  Set<String> _parsePresenceRoles(Map<String, dynamic> presence) {
    final Set<String> roles = {};
    for (final val in presence.values) {
      if (val is List) {
        for (final dynamic p in val) {
          try {
            final payload = p.payload as Map?;
            if (payload != null) {
              final role = payload['role'];
              if (role is String) roles.add(role);
            }
          } catch (_) {
            if (p is Map) {
              final role = p['role'];
              if (role is String) roles.add(role);
            }
          }
        }
      }
    }
    return roles;
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
    final border =
        joined ? AppColors.success : AppColors.border;
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
              color: joined ? AppColors.success : accent.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
