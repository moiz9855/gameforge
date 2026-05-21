import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_forge/features/auth/presentation/auth_screen.dart';
import 'package:game_forge/features/shell/main_shell.dart';
import 'package:game_forge/features/auth/presentation/auth_controller.dart';
import 'package:game_forge/features/game_builder/presentation/builder_screen.dart';
import 'package:game_forge/features/game_player/presentation/player_screen.dart';
import 'package:game_forge/features/profile/presentation/profile_screen.dart';
import 'package:game_forge/features/profile/presentation/invite_friend_screen.dart';
import 'package:game_forge/features/profile/presentation/friend_requests_screen.dart';
import 'package:game_forge/features/arcade/games/snake/snake_screen.dart';
import 'package:game_forge/features/arcade/games/tetris/tetris_screen.dart';
import 'package:game_forge/features/arcade/games/flappy/flappy_screen.dart';
import 'package:game_forge/features/arcade/games/pong/pong_screen.dart';
import 'package:game_forge/features/arcade/presentation/retro_startup_screen.dart';
import 'package:game_forge/features/multiplayer/chess/chess_screen.dart';
import 'package:game_forge/features/multiplayer/chess/chess_lobby.dart';
import 'package:game_forge/features/multiplayer/chess/chess_waiting_room.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_screen.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_lobby.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_waiting_room.dart';

/// Root navigator key (used for global dialogs such as in-app updates).
final appNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isAuthenticated = authState.value?.session != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!isAuthenticated && !isAuthRoute) return '/auth';
      if (isAuthenticated && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
      GoRoute(path: '/', builder: (c, s) => const MainShell()),
      GoRoute(path: '/builder', builder: (c, s) => const BuilderScreen()),
      GoRoute(
        path: '/builder/:gameId',
        builder: (c, s) => BuilderScreen(gameId: s.pathParameters['gameId']),
      ),
      GoRoute(
        path: '/play/:gameId',
        builder: (c, s) => PlayerScreen(gameId: s.pathParameters['gameId']!),
      ),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/invite-friend', builder: (c, s) => const InviteFriendScreen()),
      GoRoute(path: '/friend-requests', builder: (c, s) => const FriendRequestsScreen()),
      GoRoute(
        path: '/arcade',
        redirect: (context, state) {
          ref.read(shellTabProvider.notifier).state = 0;
          return '/';
        },
      ),
      GoRoute(path: '/arcade/startup', builder: (c, s) => const RetroStartupScreen()),
      GoRoute(path: '/arcade/snake', builder: (c, s) => const SnakeScreen()),
      GoRoute(path: '/arcade/tetris', builder: (c, s) => const TetrisScreen()),
      GoRoute(path: '/arcade/flappy', builder: (c, s) => const FlappyScreen()),
      GoRoute(path: '/arcade/pong', builder: (c, s) => const PongScreen()),
      GoRoute(path: '/chess-lobby', builder: (c, s) => const ChessLobby()),
      GoRoute(
        path: '/chess-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          return ChessWaitingRoom(roomCode: roomCode, isCreator: creator);
        },
      ),
      GoRoute(
        path: '/chess/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          return ChessScreen(roomCode: roomCode, isCreator: isCreator);
        },
      ),
      GoRoute(path: '/ludo-lobby', builder: (c, s) => const LudoLobby()),
      GoRoute(
        path: '/ludo-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          final numPlayers =
              int.tryParse(s.uri.queryParameters['players'] ?? '2') ?? 2;
          final myIdx =
              int.tryParse(s.uri.queryParameters['myIdx'] ?? '0') ?? 0;
          return LudoWaitingRoom(
            roomCode: roomCode,
            isCreator: creator,
            numPlayers: numPlayers,
            myPlayerIdx: myIdx,
          );
        },
      ),
      GoRoute(
        path: '/ludo/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          final numPlayers =
              int.tryParse(s.uri.queryParameters['players'] ?? '2') ?? 2;
          final myIdx =
              int.tryParse(s.uri.queryParameters['myIdx'] ?? '0') ?? 0;
          return LudoScreen(
            roomCode: roomCode,
            isCreator: isCreator,
            numPlayers: numPlayers,
            myPlayerIdx: myIdx,
          );
        },
      ),
    ],
  );
});
