import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/room_code_boxes.dart';
import 'package:game_forge/core/services/sound_service.dart';

class UnoLobby extends StatefulWidget {
  final String? roomCode;
  const UnoLobby({super.key, this.roomCode});

  @override
  State<UnoLobby> createState() => _UnoLobbyState();
}

class _UnoLobbyState extends State<UnoLobby> {
  String _joinCode = '';
  int _playersCount = 2;

  @override
  void initState() {
    super.initState();
    if (widget.roomCode != null) {
      _joinCode = widget.roomCode!;
    }
  }

  String _newCode() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, 6);
  }

  void _createRoom() {
    SoundService.instance.play(SoundType.gameStart);
    final code = _newCode();
    context.push('/uno-waiting/$code?creator=true&players=$_playersCount');
  }

  void _joinRoom() {
    if (_joinCode.length != 6) return;
    SoundService.instance.play(SoundType.buttonTap);
    context.push('/uno-waiting/$_joinCode?creator=false');
  }

  @override
  Widget build(BuildContext context) {
    final joinReady = _joinCode.length == 6;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () {
            SoundService.instance.play(SoundType.buttonBack);
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🃏', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Text(
                  'UNO ONLINE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Play classic UNO card battle online with up to 4 players.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'NUMBER OF PLAYERS: $_playersCount',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [2, 3, 4].map((count) {
                final isSelected = _playersCount == count;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        SoundService.instance.play(SoundType.buttonTap);
                        setState(() => _playersCount = count);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? AppColors.primary : AppColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                      ),
                      child: Text(
                        '$count PLAYERS',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.fireGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _createRoom,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'CREATE GAME ROOM',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'JOIN ROOM',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            RoomCodeBoxes(
              initialCode: widget.roomCode,
              onChanged: (code) => setState(() => _joinCode = code),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: joinReady ? _joinRoom : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: joinReady ? AppColors.primary : AppColors.card2,
                  foregroundColor: joinReady ? Colors.white : AppColors.muted,
                  disabledBackgroundColor: AppColors.card2,
                  disabledForegroundColor: AppColors.muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'JOIN',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
