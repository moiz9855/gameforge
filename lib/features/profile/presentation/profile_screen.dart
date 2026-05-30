import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';
import 'package:game_forge/features/home/presentation/widgets/game_card.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_games_controller.dart';
import 'friends_controller.dart';
import 'edit_profile_screen.dart';

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;
  final response = await Supabase.instance.client
      .from('users')
      .select()
      .eq('id', user.id)
      .maybeSingle();
  return response;
});

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
    final profileAsync = ref.watch(userProfileProvider);
    final friends = ref.watch(friendsListProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () {
            SoundService.instance.play(SoundType.buttonBack);
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.danger,
            onPressed: () {
              SoundService.instance.play(SoundType.buttonBack);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white)));
          }

          final username = profile['username'] as String? ?? 'Player';
          final avatar = profile['avatar_emoji'] as String? ?? '😈';
          final bio = profile['bio'] as String? ?? '';
          final gamerTypes = profile['gamer_types'] as List? ?? [];
          final friendId = profile['friend_id'] as String? ?? '$username#0000';
          
          final gamesPlayed = profile['games_played'] as int? ?? 0;
          final totalWins = profile['total_wins'] as int? ?? 0;
          final joinedAtStr = profile['joined_at'] as String?;
          
          String joinedDate = 'Joined recently';
          int daysActive = 1;
          if (joinedAtStr != null) {
            try {
              final date = DateTime.parse(joinedAtStr);
              joinedDate = '${date.day}/${date.month}/${date.year}';
              daysActive = max(1, DateTime.now().difference(date).inDays);
            } catch (_) {}
          }

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // Redesigned Profile Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F1218),
                    border: Border(
                      bottom: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar glowing circle
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF05A28), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF05A28).withValues(alpha: 0.35),
                              blurRadius: 18,
                            ),
                          ],
                          color: const Color(0xFF1E1E24),
                        ),
                        child: Center(
                          child: Text(
                            avatar,
                            style: const TextStyle(fontSize: 44),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Username (Rajdhani)
                      Text(
                        username.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Friend ID Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              friendId,
                              style: GoogleFonts.shareTechMono(
                                color: const Color(0xFFF05A28),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                SoundService.instance.play(SoundType.buttonTap);
                                Clipboard.setData(ClipboardData(text: friendId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend ID copied!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bio text
                      if (bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Gamer type horizontal row
                      if (gamerTypes.isNotEmpty)
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: gamerTypes.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final typeId = gamerTypes[index].toString();
                              final name = typeId.replaceAll('_', ' ').toUpperCase();
                              final emoji = _getGamerEmoji(typeId);
                              final color = _getGamerColor(typeId);
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: color, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: GoogleFonts.rajdhani(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 14),

                      // EDIT PROFILE button (outline orange)
                      OutlinedButton(
                        onPressed: () {
                          SoundService.instance.play(SoundType.buttonTap);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(currentProfile: profile),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF05A28), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: Text(
                          'EDIT PROFILE',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 8,
                            color: const Color(0xFFF05A28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHeaderStat('GAMES', '$gamesPlayed', '🎮'),
                          _buildHeaderStat('WINS', '$totalWins', '🏆'),
                          _buildHeaderStat('FRIENDS', '${friends.length}', '👥'),
                          _buildHeaderStat('SINCE', joinedDate, '📅'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                TabBar(
                  indicatorColor: const Color(0xFFF05A28),
                  indicatorWeight: 2,
                  labelColor: const Color(0xFFF05A28),
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: GoogleFonts.pressStart2p(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                  tabs: const [
                    Tab(text: 'MY GAMES'),
                    Tab(text: 'FRIENDS'),
                    Tab(text: 'STATS'),
                  ],
                ),

                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    children: [
                      // MY GAMES
                      myGamesAsync.when(
                        data: (games) {
                          if (games.isEmpty) {
                            return Center(
                              child: Text(
                                'You haven\'t built any games yet.',
                                style: GoogleFonts.inter(color: AppColors.textSecondary),
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
                                onEdit: () => context.push('/builder/${game.id}'),
                                onDelete: () => _confirmDelete(context, ref, game.id),
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Error: $err',
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),

                      // FRIENDS
                      _FriendsTabBody(buildFriendTag: _friendTag),

                      // STATS tab
                      _buildStatsTab(gamesPlayed, totalWins, daysActive, gamerTypes),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildHeaderStat(String title, String val, String emoji) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              val,
              style: GoogleFonts.shareTechMono(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.pressStart2p(
            fontSize: 6,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(int played, int wins, int days, List gamerTypes) {
    final winRate = played > 0 ? (wins / played * 100).toStringAsFixed(1) : '0';
    // Calculate a mock categories values for custom games
    final mockArcade = (played * 0.5).round();
    final mockMulti = (played * 0.3).round();
    final mockCustom = max(0, played - mockArcade - mockMulti);

    // Favorite game logic based on gamer types
    String favGame = 'Snake';
    if (gamerTypes.contains('competitive')) favGame = 'Pong';
    if (gamerTypes.contains('strategic')) favGame = 'Chess';
    if (gamerTypes.contains('casual')) favGame = 'Ludo';
    if (gamerTypes.contains('creative')) favGame = 'Custom Games';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('WIN RATE', '$winRate%', '📊')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('WIN STREAK', '${wins > 0 ? (wins / 3).ceil() : 0}', '🔥')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('FAVORITE', favGame, '⭐')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('ACTIVE DAYS', '$days', '📅')),
            ],
          ),
          const SizedBox(height: 24),
          CategoryBarChart(
            arcade: mockArcade,
            multiplayer: mockMulti,
            custom: mockCustom,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, String emoji) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: GoogleFonts.shareTechMono(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getGamerEmoji(String typeId) {
    switch (typeId) {
      case 'competitive': return '🏆';
      case 'casual': return '🎲';
      case 'strategic': return '🧠';
      case 'speedrunner': return '⚡';
      case 'creative': return '🎨';
      case 'social': return '👥';
      case 'night_owl': return '🌙';
      case 'hardcore': return '🔥';
      default: return '🎮';
    }
  }

  Color _getGamerColor(String typeId) {
    switch (typeId) {
      case 'competitive': return Colors.red;
      case 'casual': return Colors.blue;
      case 'strategic': return Colors.yellow;
      case 'speedrunner': return Colors.cyan;
      case 'creative': return Colors.purple;
      case 'social': return Colors.green;
      case 'night_owl': return Colors.indigo;
      case 'hardcore': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class CategoryBarChart extends StatelessWidget {
  final int arcade;
  final int multiplayer;
  final int custom;

  const CategoryBarChart({
    super.key,
    required this.arcade,
    required this.multiplayer,
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = [arcade, multiplayer, custom].reduce((a, b) => a > b ? a : b);
    final double scale = maxVal > 0 ? 100.0 / maxVal : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'GAMES PLAYED BY CATEGORY',
            style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white60),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar('ARCADE', arcade, const Color(0xFFF05A28), scale),
              _buildBar('MULTIPLAYER', multiplayer, Colors.blue, scale),
              _buildBar('CUSTOM', custom, Colors.purple, scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int count, Color color, double scale) {
    final double height = count > 0 ? (count * scale) : 4.0;
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.shareTechMono(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.pressStart2p(fontSize: 6, color: Colors.white54),
        ),
      ],
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
                    onPressed: () {
                      SoundService.instance.play(SoundType.buttonTap);
                      context.push('/invite-friend');
                    },
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
                onPressed: () {
                  SoundService.instance.play(SoundType.buttonTap);
                  context.push('/friend-requests');
                },
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
                              SoundService.instance.play(SoundType.buttonTap);
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
                              SoundService.instance.play(SoundType.buttonTap);
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
