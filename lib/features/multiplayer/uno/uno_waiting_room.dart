import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/multiplayer/shared/friend_invite_panel.dart';


class UnoWaitingRoom extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int numPlayers;

  const UnoWaitingRoom({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.numPlayers,
  });

  @override
  State<UnoWaitingRoom> createState() => _UnoWaitingRoomState();
}

class _UnoWaitingRoomState extends State<UnoWaitingRoom> with SingleTickerProviderStateMixin {
  RealtimeChannel? _channel;
  final Set<Map<String, String>> _joinedPlayers = {};
  bool _wentToGame = false;
  late AnimationController _pulse;


  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndSubscribe());
  }

  Future<void> _initAndSubscribe() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final email = client.auth.currentUser?.email ?? 'Player';
    final name = email.split('@')[0].toUpperCase();

    try {
      if (widget.isCreator) {
        await client.from('uno_rooms').insert({
          'room_code': widget.roomCode,
          'host_id': userId,
          'players': [
            {'id': userId, 'name': name, 'role': 'host'}
          ],
          'game_status': 'waiting',
        });
      } else {
        final res = await client
            .from('uno_rooms')
            .select('players')
            .eq('room_code', widget.roomCode)
            .single();
        final currentPlayers = List.from(res['players'] as List);
        
        if (!currentPlayers.any((p) => p['id'] == userId)) {
          currentPlayers.add({'id': userId, 'name': name, 'role': 'guest'});
          await client
              .from('uno_rooms')
              .update({
                'players': currentPlayers,
              })
              .eq('room_code', widget.roomCode);
        }
      }
      setState(() {});
    } catch (_) {
      setState(() {});
    }

    final ch = client.channel('uno:${widget.roomCode}');
    _channel = ch;

    ch
      .onPresenceSync((_) {
        if (!mounted) return;
        final presenceState = _channel?.presenceState();
        if (presenceState != null) {
          final Set<Map<String, String>> players = {};
          for (final singleState in presenceState) {
            for (final p in singleState.presences) {
              final id = p.payload['id'] as String?;
              final pName = p.payload['name'] as String?;
              final role = p.payload['role'] as String?;
              if (id != null && pName != null && role != null) {
                players.add({'id': id, 'name': pName, 'role': role});
              }
            }
          }
          setState(() {
            _joinedPlayers
              ..clear()
              ..addAll(players);
          });
        }
      })
      .onBroadcast(
        event: 'start_game',
        callback: (_) {
          _navigateToGame();
        },
      )
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({
            'id': userId,
            'name': name,
            'role': widget.isCreator ? 'host' : 'guest',
          });
        }
      });
  }

  void _startGame() {
    if (_joinedPlayers.length < 2) return;
    _channel?.sendBroadcastMessage(
      event: 'start_game',
      payload: {},
    );
    _navigateToGame();
  }

  void _navigateToGame() {
    if (_wentToGame) return;
    _wentToGame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/uno/${widget.roomCode}?creator=${widget.isCreator}&players=${widget.numPlayers}');
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
    final canStart = _joinedPlayers.length >= 2;

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
              'UNO WAITING ROOM',
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

            Text(
              'PLAYERS (${_joinedPlayers.length}/${widget.numPlayers})',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _joinedPlayers.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 20),
                itemBuilder: (context, index) {
                  final player = _joinedPlayers.elementAt(index);
                  final isHost = player['role'] == 'host';
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isHost ? AppColors.primary.withValues(alpha: 0.2) : Colors.white10,
                        child: Text(
                          isHost ? '👑' : '🃏',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        player['name']!,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 9,
                          color: isHost ? AppColors.primary : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isHost ? 'HOST' : 'READY',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          color: isHost ? AppColors.primary : AppColors.success,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            if (widget.isCreator) ...[
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canStart ? _startGame : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canStart ? AppColors.primary : AppColors.card2,
                    foregroundColor: canStart ? Colors.white : AppColors.muted,
                  ),
                  child: Text(
                    'START MATCH',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!canStart) ...[
                const SizedBox(height: 12),
                Text(
                  'Waiting for other players to connect...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                )
              ]
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _pulse.drive(Tween(begin: 0.35, end: 1.0)),
                      child: const Icon(Icons.hourglass_empty_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'WAITING FOR HOST TO START...',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (widget.isCreator)
              FriendInvitePanel(roomCode: widget.roomCode, gameType: 'uno'),
          ],
        ),
      ),
    );
  }
}
