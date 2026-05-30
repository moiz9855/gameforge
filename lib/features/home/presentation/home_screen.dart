import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';
import 'package:game_forge/features/home/domain/game.dart';
import 'package:game_forge/core/services/chat_service.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _feed(BuildContext context, AsyncValue<List<Game>> asyncGames) {
    return asyncGames.when(
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Text(
              'No games yet — build one!',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          );
        }
        final featured = games.first;
        final tail =
            games.length > 1 ? games.sublist(1) : <Game>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _FeaturedGameCard(
              game: featured,
              onTap: () => context.push('/play/${featured.id}'),
            ),
            const SizedBox(height: 22),
            Text(
              'DISCOVER',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...tail.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HorizontalGameTile(
                  game: g,
                  onTap: () => context.push('/play/${g.id}'),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error loading games: $error',
          style: GoogleFonts.inter(color: AppColors.danger),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trendingGames = ref.watch(trendingGamesProvider);
    final newGames = ref.watch(newGamesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        actions: [
          // Messages icon with unread badge
          _MessagesIconButton(),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            color: AppColors.fire2,
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.danger,
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'TRENDING'),
            Tab(text: 'NEW'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _feed(context, trendingGames),
          _feed(context, newGames),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.fireGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          onPressed: () => context.push('/builder'),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            '＋ Build a Game',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesIconButton extends StatefulWidget {
  @override
  State<_MessagesIconButton> createState() => _MessagesIconButtonState();
}

class _MessagesIconButtonState extends State<_MessagesIconButton> {
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    // Listen for new messages to update badge
    ChatService.instance.onMessageReceived.listen((_) {
      if (mounted) _refreshUnread();
    });
  }

  Future<void> _refreshUnread() async {
    try {
      final convs = await ChatService.instance.loadConversations();
      if (mounted) {
        int total = 0;
        for (final c in convs) {
          total += (c['unread_count'] as int? ?? 0);
        }
        setState(() => _totalUnread = total);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_rounded),
          color: AppColors.textSecondary,
          onPressed: () async {
            await context.push('/conversations');
            _refreshUnread();
          },
        ),
        if (_totalUnread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                _totalUnread > 99 ? '99+' : '$_totalUnread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const _FeaturedGameCard({
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.featuredCardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(21)),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      if (game.thumbnailUrl != null)
                        Image.network(
                          game.thumbnailUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.gamepad_rounded,
                            size: 56,
                            color: AppColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'FEATURED',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'by ${game.creatorName}',
                      style: GoogleFonts.inter(
                        color: AppColors.fire2,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.play_circle_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${game.playCount}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Icon(Icons.favorite_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${game.likeCount}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
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

class _HorizontalGameTile extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const _HorizontalGameTile({
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: game.thumbnailUrl != null
                        ? Image.network(
                            game.thumbnailUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.card2,
                            child: Icon(
                              Icons.gamepad_outlined,
                              color: AppColors.primary.withValues(alpha: 0.7),
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.creatorName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              size: 15, color: AppColors.success),
                          Text(
                            ' ${game.playCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.favorite_rounded,
                              size: 14, color: AppColors.primary),
                          Text(
                            ' ${game.likeCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppColors.primary.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
