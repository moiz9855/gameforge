import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/features/profile/presentation/friends_controller.dart';
import 'package:game_forge/features/multiplayer/shared/game_invite_service.dart';

class FriendInvitePanel extends ConsumerWidget {
  final String roomCode;
  final String gameType; // 'chess' or 'ludo'
  final int? ludoPlayerCount;

  const FriendInvitePanel({
    super.key,
    required this.roomCode,
    required this.gameType,
    this.ludoPlayerCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final inviteService = ref.read(gameInviteServiceProvider);

    return friendsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();
        
        final color =
            gameType == 'ludo' ? AppColors.ludoTint : AppColors.chessTint;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INVITE FRIENDS',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...friends.map((f) {
                final friendId = f['id'] as String;
                final username = f['username'] as String? ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Text(username[0].toUpperCase(),
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(username,
                              style: const TextStyle(
                                  color: AppColors.textPrimary))),
                      _InviteButton(
                        color: color,
                        onTap: () async {
                          await inviteService.sendInvite(
                            friendId: friendId,
                            roomCode: roomCode,
                            gameType: gameType,
                            ludoPlayers: ludoPlayerCount,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invite sent to $username!'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _InviteButton extends StatefulWidget {
  final Future<void> Function() onTap;
  final Color color;
  
  const _InviteButton({required this.onTap, required this.color});

  @override
  State<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<_InviteButton> {
  bool _sent = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _sent
          ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : _loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.color))
              : TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: widget.color.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  onPressed: () async {
                    setState(() => _loading = true);
                    await widget.onTap();
                    if (mounted) {
                      setState(() { _loading = false; _sent = true; });
                    }
                  },
                  child: Text('INVITE',
                      style: TextStyle(
                          color: widget.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
    );
  }
}
