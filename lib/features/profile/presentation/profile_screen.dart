import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';
import 'package:game_forge/features/home/presentation/widgets/game_card.dart';
import 'my_games_controller.dart';
import 'friends_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _confirmDelete(BuildContext context, WidgetRef ref, String gameId) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteDialog(gameId: gameId, ref: ref),
    );
  }

  String _friendTag(Map<String, dynamic> friend) {
    final id = friend['id'] as String? ?? '';
    final name = friend['username'] as String? ?? '?';
    final prefix =
        id.length >= 4 ? id.substring(0, 4).toUpperCase() : id.toUpperCase();
    return '$name#$prefix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myGamesAsync = ref.watch(myGamesProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;

    final username = user?.userMetadata?['username'] ?? 'Player';
    final shortId = user?.id.substring(0, 4).toUpperCase() ?? '0000';
    final friendId = '$username#$shortId';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.danger,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                      color: AppColors.card,
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 52, color: AppColors.fire2),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    username,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          friendId,
                          style: GoogleFonts.inter(
                            color: AppColors.fire2,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: friendId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Friend ID copied'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          child: const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'MY GAMES'),
                Tab(text: 'FRIENDS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  myGamesAsync.when(
                    data: (games) {
                      if (games.isEmpty) {
                        return Center(
                          child: Text(
                            'You haven\'t built any games yet.',
                            style:
                                GoogleFonts.inter(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final game = games[index];
                          return GameCard(
                            game: game,
                            onTap: () => context.push('/play/${game.id}'),
                            onEdit: () =>
                                context.push('/builder/${game.id}'),
                            onDelete: () =>
                                _confirmDelete(context, ref, game.id),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Error: $err',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                  _FriendsTabBody(buildFriendTag: _friendTag),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsTabBody extends ConsumerWidget {
  final String Function(Map<String, dynamic>) buildFriendTag;

  const _FriendsTabBody({required this.buildFriendTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.fireGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => context.push('/invite-friend'),
                    icon: const Text('＋',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    label: Text(
                      'Invite Friend',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push('/friend-requests'),
                child: Text(
                  'Friend Requests',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return Center(
                  child: Text(
                    'No friends yet.\nInvite someone from the button above.',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final f = friends[index];
                  final name = f['username'] as String? ?? '?';
                  final tag = buildFriendTag(f);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.18),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.card,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  tag,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.sports_esports_rounded,
                                color: AppColors.fire2.withValues(alpha: 0.95)),
                            tooltip: 'Challenge',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Challenge $name — invite them from Multiplayer!',
                                    style: GoogleFonts.inter(),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.card2,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            color: AppColors.textSecondary,
                            tooltip: 'Chat',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Chat coming soon.',
                                    style: GoogleFonts.inter(),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.card2,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.danger)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends ConsumerStatefulWidget {
  final String gameId;
  final WidgetRef ref;

  const _DeleteDialog({required this.gameId, required this.ref});

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      await widget.ref.read(profileControllerProvider).deleteGame(widget.gameId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete game: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Delete Game?',
        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to delete this game? This action cannot be undone.',
        style: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: GoogleFonts.rajdhani(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _isDeleting ? null : _delete,
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'DELETE',
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
