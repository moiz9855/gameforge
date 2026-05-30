import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/room_code_boxes.dart';

/// Cyber Ludo lobby — orange/fire accents, 6-slot join code, seat picker.
class LudoLobby extends StatefulWidget {
  final String? roomCode;
  const LudoLobby({super.key, this.roomCode});

  @override
  State<LudoLobby> createState() => _LudoLobbyState();
}

class _LudoLobbyState extends State<LudoLobby> {
  int _numPlayers = 2;
  String _joinCode = '';

  @override
  void initState() {
    super.initState();
    if (widget.roomCode != null) {
      _joinCode = widget.roomCode!;
    }
  }

  static const _dots = [
    Color(0xFFE53935),
    Color(0xFF2563EB),
    Color(0xFFFFD54F),
    Color(0xFF27C96A),
  ];

  String _newCode() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, 6);
  }

  void _createRoom() {
    final code = _newCode();
    context.push(
      '/ludo-waiting/$code?creator=true&players=$_numPlayers&myIdx=0',
    );
  }

  void _joinRoom() {
    if (_joinCode.length != 6) return;
    context.push(
      '/ludo-waiting/$_joinCode?creator=false&players=$_numPlayers&myIdx=1',
    );
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
            Text(
              'CYBER LUDO',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick seats, forge a room, and sprint the neon cross.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'NUMBER OF PLAYERS',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [2, 3, 4].map((n) {
                final selected = _numPlayers == n;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _numPlayers = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.14)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$n',
                              style: GoogleFonts.rajdhani(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                n,
                                (i) => Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _dots[i],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.fireGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _createRoom,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    'CREATE ROOM',
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
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            RoomCodeBoxes(
              initialCode: widget.roomCode,
              onChanged: (code) => setState(() => _joinCode = code),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: joinReady ? _joinRoom : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      joinReady ? AppColors.primary : AppColors.card2,
                  foregroundColor:
                      joinReady ? Colors.white : AppColors.muted,
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
