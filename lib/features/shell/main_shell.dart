import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/features/arcade/presentation/arcade_screen.dart';
import 'package:game_forge/features/home/presentation/home_screen.dart';
import 'package:game_forge/features/multiplayer/presentation/multiplayer_screen.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';
import 'package:google_fonts/google_fonts.dart';

final shellTabProvider = StateProvider<int>((ref) => 1);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  RealtimeChannel? _inviteChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeToInvites());
  }

  void _subscribeToInvites() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    _inviteChannel = Supabase.instance.client
        .channel('invites:${user.id}')
        .onBroadcast(
          event: 'game-invite',
          callback: (payload) {
            if (!mounted) return;
            final data = payload['payload'] as Map<String, dynamic>? ?? {};
            _showInviteDialog(
              fromUsername: data['from_username'] as String? ?? 'Someone',
              roomCode: data['room_code'] as String? ?? '',
              gameType: data['game_type'] as String? ?? 'chess',
              data: data,
            );
          },
        )
        .subscribe();
  }

  void _showInviteDialog({
    required String fromUsername,
    required String roomCode,
    required String gameType,
    required Map<String, dynamic> data,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InviteDialog(
        fromUsername: fromUsername,
        roomCode: roomCode,
        gameType: gameType,
        data: data,
      ),
    );
  }

  @override
  void dispose() {
    _inviteChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: const [
          ArcadeScreen(),
          HomeScreen(),
          MultiplayerScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.border.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavSlot(
                  emoji: '🕹️',
                  label: 'Arcade',
                  selected: currentIndex == 0,
                  onTap: () =>
                      ref.read(shellTabProvider.notifier).state = 0,
                ),
                _BottomNavSlot(
                  emoji: '🌍',
                  label: 'Community',
                  selected: currentIndex == 1,
                  onTap: () =>
                      ref.read(shellTabProvider.notifier).state = 1,
                ),
                _BottomNavSlot(
                  emoji: '👥',
                  label: 'Multi',
                  selected: currentIndex == 2,
                  onTap: () =>
                      ref.read(shellTabProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavSlot extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavSlot({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 5,
              width: selected ? 5 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Invite Dialog ────────────────────────────────────────────────────────────
class _InviteDialog extends StatelessWidget {
  final String fromUsername;
  final String roomCode;
  final String gameType;
  final Map<String, dynamic> data;

  const _InviteDialog({
    required this.fromUsername,
    required this.roomCode,
    required this.gameType,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = gameType == 'chess' ? Icons.grid_4x4 : Icons.casino;
    final label = gameType == 'chess' ? 'Chess Match' : 'Ludo Game';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.card,
              AppColors.card2,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.55), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 46, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              '$fromUsername invited you to a $label!',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              roomCode,
              style: GoogleFonts.pressStart2p(
                color: AppColors.primary,
                fontSize: 18,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'DECLINE',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.fireGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (gameType == 'chess') {
                          context.push(
                              '/chess-waiting/$roomCode?creator=false');
                        } else {
                          final p = (data['players'] as num?)?.toInt() ?? 2;
                          final my = (data['my_idx'] as num?)?.toInt() ?? 1;
                          context.push(
                              '/ludo-waiting/$roomCode?creator=false&players=$p&myIdx=$my');
                        }
                      },
                      child: Text(
                        'ACCEPT',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
