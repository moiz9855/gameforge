import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/features/profile/presentation/friends_controller.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  String _friendTag(Map<String, dynamic> friend) {
    final id = friend['id'] as String? ?? '';
    final name = friend['username'] as String? ?? '?';
    final prefix =
        id.length >= 4 ? id.substring(0, 4).toUpperCase() : id.toUpperCase();
    return '$name#$prefix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(pendingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    final friends = ref.watch(friendsListProvider);
    final ctrl = ref.read(friendsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.refresh(pendingRequestsProvider.future),
            ref.refresh(outgoingRequestsProvider.future),
            ref.refresh(friendsListProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'FRIEND REQUESTS',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 22,
                  ),
                ),
              ),
            ),

            // Incoming
            incoming.when(
              data: (reqs) {
                if (reqs.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'INCOMING',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }
                        final req = reqs[index - 1];
                        final fromUser =
                            req['from_user'] as Map<String, dynamic>? ?? {};
                        final name =
                            fromUser['username'] as String? ?? 'Player';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_rounded),
                                  color: AppColors.success,
                                  onPressed: () =>
                                      ctrl.acceptRequest(req['id'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  color: AppColors.danger,
                                  onPressed: () =>
                                      ctrl.declineRequest(req['id'] as String),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: reqs.length + 1,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            outgoing.when(
              data: (outs) {
                if (outs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'OUTGOING',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 12,
                                color: AppColors.gold,
                              ),
                            ),
                          );
                        }
                        final row = outs[index - 1];
                        final to =
                            row['to_user'] as Map<String, dynamic>? ?? {};
                        final name = to['username'] as String? ?? 'Player';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(name,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.card2,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'PENDING',
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: outs.length + 1,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'FRIENDS',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            friends.when(
              data: (list) {
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No friends yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final f = list[index];
                        final name = f['username'] as String? ?? '?';
                        final tag = _friendTag(f);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
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
                            title: Text(name,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: list.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
