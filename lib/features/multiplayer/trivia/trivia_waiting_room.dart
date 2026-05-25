import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/multiplayer/shared/friend_invite_panel.dart';

import 'trivia_questions.dart';

class TriviaWaitingRoom extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final String category;

  const TriviaWaitingRoom({
    super.key,
    required this.roomCode,
    required this.isCreator,
    this.category = 'random',
  });

  @override
  State<TriviaWaitingRoom> createState() => _TriviaWaitingRoomState();
}

class _TriviaWaitingRoomState extends State<TriviaWaitingRoom> with SingleTickerProviderStateMixin {
  RealtimeChannel? _channel;
  final Set<String> _presentRoles = {};
  bool _wentToGame = false;
  late AnimationController _pulse;


  bool get _hostHere => _presentRoles.contains('host');
  bool get _guestHere => _presentRoles.contains('guest');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndSubscribe());
  }

  Future<void> _initAndSubscribe() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    try {
      if (widget.isCreator) {
        final qList = triviaQuestionsBank
            .where((q) => widget.category == 'random' || q.category == widget.category)
            .toList()
          ..shuffle();
        final selectedQs = qList.take(10).map((q) => q.toJson()).toList();

        await client.from('trivia_rooms').insert({
          'room_code': widget.roomCode,
          'player1_id': userId,
          'questions': selectedQs,
          'category': widget.category,
          'game_status': 'waiting',
        });
      } else {
        await client
            .from('trivia_rooms')
            .update({'player2_id': userId, 'game_status': 'playing'})
            .eq('room_code', widget.roomCode);
      }
      setState(() {});
    } catch (_) {
      // Offline fallback: continue using realtime channel even if DB fails
      setState(() {});
    }

    final myRole = widget.isCreator ? 'host' : 'guest';
    final ch = client.channel('trivia:${widget.roomCode}');
    _channel = ch;

    ch
      .onPresenceJoin((payload) {
        if (!mounted) return;
        for (final p in payload.newPresences) {
          final role = p.payload['role'];
          if (role is String) setState(() => _presentRoles.add(role));
        }
        _checkAndStart();
      })
      .onPresenceLeave((payload) {
        if (!mounted) return;
        for (final p in payload.leftPresences) {
          final role = p.payload['role'];
          if (role is String) setState(() => _presentRoles.remove(role));
        }
      })
      .onPresenceSync((_) {
        if (!mounted) return;
        final state = _channel?.presenceState();
        if (state != null) {
          final roles = <String>{};
          for (final singleState in state) {
            for (final p in singleState.presences) {
              final role = p.payload['role'];
              if (role is String) roles.add(role);
            }
          }
          setState(() {
            _presentRoles
              ..clear()
              ..addAll(roles);
          });
        }
        _checkAndStart();
      })
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({'role': myRole});
        }
      });
  }

  void _checkAndStart() {
    if (_wentToGame || !_hostHere || !_guestHere) return;
    _wentToGame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/trivia/${widget.roomCode}?creator=${widget.isCreator}&category=${widget.category}');
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _channel?.unsubscribe();
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
              'TRIVIA QUIZ BATTLE',
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
                    label: 'Host',
                    subtitle: 'Player 1',
                    joined: _hostHere,
                    pulse: _pulse,
                    accent: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PlayerWaitCard(
                    label: 'Guest',
                    subtitle: 'Player 2',
                    joined: _guestHere,
                    pulse: _pulse,
                    accent: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Game will start automatically when both players connect.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
            if (widget.isCreator) ...[
              const SizedBox(height: 24),
              FriendInvitePanel(roomCode: widget.roomCode, gameType: 'trivia'),
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
