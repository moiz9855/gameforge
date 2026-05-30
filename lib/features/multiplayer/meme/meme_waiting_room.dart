import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/multiplayer/shared/friend_invite_panel.dart';

class MemeWaitingRoom extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int maxPlayers;

  const MemeWaitingRoom({
    super.key,
    required this.roomCode,
    required this.isCreator,
    this.maxPlayers = 8,
  });

  @override
  State<MemeWaitingRoom> createState() => _MemeWaitingRoomState();
}

class _MemeWaitingRoomState extends State<MemeWaitingRoom> with SingleTickerProviderStateMixin {
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

    if (widget.isCreator) {
      // Room was already inserted in meme_lobby.dart, we just join it.
      // But we can update players list just in case.
      try {
        await client.from('meme_rooms').update({
          'players': [
            {'id': userId, 'name': name}
          ],
          'game_status': 'waiting',
        }).eq('room_code', widget.roomCode);
      } catch (_) {}
    } else {
      try {
        final res = await client
            .from('meme_rooms')
            .select('players, game_status')
            .eq('room_code', widget.roomCode)
            .single();
        
        if (res['game_status'] != 'waiting') {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game already started!')));
             context.pop();
           }
           return;
        }

        final currentPlayers = List.from(res['players'] as List);
        if (!currentPlayers.any((p) => p['id'] == userId)) {
          currentPlayers.add({'id': userId, 'name': name});
          await client
              .from('meme_rooms')
              .update({'players': currentPlayers})
              .eq('room_code', widget.roomCode);
        }
      } catch (_) {}
    }

    final ch = client.channel('meme:${widget.roomCode}');
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
              if (id != null && pName != null) {
                players.add({'id': id, 'name': pName});
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
          });
        }
      });
  }

  bool _amIHost() {
    if (_joinedPlayers.isEmpty) return widget.isCreator;
    final client = Supabase.instance.client;
    final myId = client.auth.currentUser?.id;
    // Sort players to consistently pick a host if the original creator leaves
    final sorted = _joinedPlayers.toList()..sort((a, b) => a['id']!.compareTo(b['id']!));
    return sorted.first['id'] == myId;
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
    
    // Update game_status so nobody else can join
    if (_amIHost()) {
       Supabase.instance.client.from('meme_rooms').update({'game_status': 'playing'}).eq('room_code', widget.roomCode);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/meme/${widget.roomCode}?creator=${widget.isCreator}');
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
    final isHost = _amIHost();

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
              'MEME BATTLE ROOM',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room code copied!')),
                );
              },
              child: Text(
                widget.roomCode,
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(
                  fontSize: 42,
                  letterSpacing: 8,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap code to copy',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 48),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PLAYERS JOINED',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_joinedPlayers.length} / ${widget.maxPlayers}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF05A28),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_joinedPlayers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(color: Color(0xFFF05A28)),
                    )
                  else
                    ..._joinedPlayers.map((p) => _buildPlayerRow(p)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (isHost)
              ElevatedButton(
                onPressed: canStart ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: canStart ? const Color(0xFFF05A28) : AppColors.border,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  canStart ? 'START GAME' : 'WAITING FOR 2+ PLAYERS',
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: canStart ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _pulse,
                      child: const Icon(Icons.circle, size: 12, color: Color(0xFFF05A28)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'WAITING FOR HOST...',
                      style: GoogleFonts.rajdhani(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            FriendInvitePanel(roomCode: widget.roomCode, gameType: 'meme'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, String> p) {
    // Determine if this player is technically the host
    final sorted = _joinedPlayers.toList()..sort((a, b) => a['id']!.compareTo(b['id']!));
    final isHostDisplay = sorted.first['id'] == p['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF05A28).withValues(alpha: 0.2),
            child: Text(
              p['name']![0],
              style: const TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              p['name']!,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (isHostDisplay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF05A28).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HOST',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF05A28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
