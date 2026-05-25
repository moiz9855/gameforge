import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/auth/presentation/auth_controller.dart';
import 'dart:math';

class MemeLobby extends ConsumerStatefulWidget {
  const MemeLobby({super.key});

  @override
  ConsumerState<MemeLobby> createState() => _MemeLobbyState();
}

class _MemeLobbyState extends ConsumerState<MemeLobby> {
  final TextEditingController _codeController = TextEditingController();
  int _selectedPlayers = 4;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> _createRoom() async {
    final user = ref.read(authStateProvider).value?.session?.user;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be logged in')));
      return;
    }

    setState(() => _isLoading = true);
    final roomCode = _generateRoomCode();
    try {
      await _supabase.from('meme_rooms').insert({
        'room_code': roomCode,
        'host_id': user.id,
      });
      if (mounted) {
        context.push('/meme-waiting/$roomCode?creator=true&players=$_selectedPlayers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating room: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _joinRoom() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code must be 6 characters')));
      return;
    }
    context.push('/meme-waiting/$code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GameForgeAppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😂', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text(
                'MEME BATTLE',
                style: GoogleFonts.pressStart2p(
                  fontSize: 20,
                  color: const Color(0xFFF05A28),
                ),
              ),
              const SizedBox(height: 48),

              // Create Room Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'CREATE NEW GAME',
                      style: GoogleFonts.rajdhani(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Players: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        DropdownButton<int>(
                          value: _selectedPlayers,
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          items: [2,3,4,5,6,7,8].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                          onChanged: (v) => setState(() => _selectedPlayers = v ?? 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: const Color(0xFFF05A28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'CREATE ROOM',
                              style: GoogleFonts.rajdhani(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text('— OR —', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 32),

              // Join Room Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'JOIN GAME',
                      style: GoogleFonts.rajdhani(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pressStart2p(fontSize: 20, color: Colors.white, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '......',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _joinRoom,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        side: const BorderSide(color: Color(0xFFF05A28)),
                      ),
                      child: Text(
                        'JOIN ROOM',
                        style: GoogleFonts.rajdhani(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF05A28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
