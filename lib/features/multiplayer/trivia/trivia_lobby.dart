import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/room_code_boxes.dart';
import 'package:game_forge/core/services/sound_service.dart';

class TriviaLobby extends StatefulWidget {
  final String? roomCode;
  const TriviaLobby({super.key, this.roomCode});

  @override
  State<TriviaLobby> createState() => _TriviaLobbyState();
}

class _TriviaLobbyState extends State<TriviaLobby> {
  String _joinCode = '';
  String _selectedCategory = 'random';

  @override
  void initState() {
    super.initState();
    if (widget.roomCode != null) {
      _joinCode = widget.roomCode!;
    }
  }

  final List<Map<String, String>> _categories = [
    {'id': 'random', 'name': '🎲 Random Mix'},
    {'id': 'science', 'name': '🔬 Science'},
    {'id': 'sports', 'name': '🏆 Sports'},
    {'id': 'entertainment', 'name': '🎬 Entertainment'},
    {'id': 'geography', 'name': '🌍 Geography'},
    {'id': 'history', 'name': '📚 History'},
    {'id': 'gaming', 'name': '🎮 Gaming'},
    {'id': 'math', 'name': '🧮 Math'},
  ];

  String _newCode() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, 6);
  }

  void _createRoom() {
    SoundService.instance.play(SoundType.gameStart);
    final code = _newCode();
    context.push('/trivia-waiting/$code?creator=true&category=$_selectedCategory');
  }

  void _joinRoom() {
    if (_joinCode.length != 6) return;
    SoundService.instance.play(SoundType.buttonTap);
    context.push('/trivia-waiting/$_joinCode?creator=false');
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
                const Text('❓', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Text(
                  'TRIVIA QUIZ',
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
              'Test your speed and knowledge in a 1v1 quiz battle.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'SELECT CATEGORY',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: AppColors.card,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  isExpanded: true,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      SoundService.instance.play(SoundType.buttonTap);
                      setState(() => _selectedCategory = val);
                    }
                  },
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id'],
                      child: Text(cat['name']!),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                    'CREATE BATTLE ROOM',
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
