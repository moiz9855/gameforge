import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/features/auth/presentation/auth_screen.dart';
import 'package:game_forge/features/auth/presentation/onboarding_screen.dart';
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
import 'package:game_forge/features/arcade/games/rps/rps_screen.dart';
import 'package:game_forge/features/arcade/games/ttt/ttt_screen.dart';
import 'package:game_forge/features/arcade/games/tow/tow_screen.dart';
import 'package:game_forge/features/arcade/games/runner/runner_screen.dart';
import 'package:game_forge/features/arcade/games/archery/archery_screen.dart';

import 'package:game_forge/features/arcade/games/iq_puzzle/iq_puzzle_screen.dart';
import 'package:game_forge/features/arcade/games/memory_match/memory_match_screen.dart';
import 'package:game_forge/features/arcade/games/basketball/basketball_screen.dart';
import 'package:game_forge/features/arcade/games/slingshot/slingshot_screen.dart';
import 'package:game_forge/features/arcade/games/word_scramble/word_scramble_screen.dart';
import 'package:game_forge/features/arcade/games/color_rush/color_rush_screen.dart';
import 'package:game_forge/features/arcade/games/tower_stack/tower_stack_screen.dart';

import 'package:game_forge/features/arcade/presentation/retro_startup_screen.dart';
import 'package:game_forge/features/multiplayer/chess/chess_screen.dart';
import 'package:game_forge/features/multiplayer/chess/chess_lobby.dart';
import 'package:game_forge/features/multiplayer/chess/chess_waiting_room.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_screen.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_lobby.dart';
import 'package:game_forge/features/multiplayer/ludo/ludo_waiting_room.dart';
import 'package:game_forge/features/multiplayer/uno/uno_lobby.dart';
import 'package:game_forge/features/multiplayer/uno/uno_waiting_room.dart';
import 'package:game_forge/features/multiplayer/uno/uno_screen.dart';
import 'package:game_forge/features/multiplayer/draw/draw_lobby.dart';
import 'package:game_forge/features/multiplayer/draw/draw_waiting_room.dart';
import 'package:game_forge/features/multiplayer/draw/draw_screen.dart';
import 'package:game_forge/features/multiplayer/trivia/trivia_lobby.dart';
import 'package:game_forge/features/multiplayer/trivia/trivia_waiting_room.dart';
import 'package:game_forge/features/multiplayer/trivia/trivia_screen.dart';

import 'package:game_forge/features/multiplayer/meme/meme_lobby.dart';
import 'package:game_forge/features/multiplayer/meme/meme_waiting_room.dart';
import 'package:game_forge/features/multiplayer/meme/meme_screen.dart';

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider).valueOrNull;
  final user = authState?.session?.user;
  if (user == null) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    final localVal = prefs.getBool('onboarding_completed_${user.id}');
    if (localVal == true) return true;

    final response = await Supabase.instance.client
        .from('users')
        .select('onboarding_completed')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      final completed = response['onboarding_completed'] as bool? ?? false;
      if (completed) {
        await prefs.setBool('onboarding_completed_${user.id}', true);
        return true;
      }
    }
  } catch (e) {
    debugPrint('Onboarding check error: $e');
  }
  return false;
});

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

      if (isAuthenticated) {
        final onboardingAsync = ref.watch(onboardingCompletedProvider);
        if (onboardingAsync.isLoading) return null;

        final isCompleted = onboardingAsync.value ?? false;
        final isOnboardingRoute = state.matchedLocation == '/onboarding';

        if (!isCompleted) {
          return '/onboarding';
        }
        if (isCompleted && isOnboardingRoute) {
          return '/';
        }
      }

      final gameType = state.uri.queryParameters['game_type'];
      if (gameType != null) {
        final roomCode = state.uri.queryParameters['room_code'] ?? state.uri.queryParameters['roomCode'] ?? '';
        switch (gameType) {
          case 'chess': return '/chess-lobby?roomCode=$roomCode';
          case 'ludo': return '/ludo-lobby?roomCode=$roomCode';
          case 'uno': return '/uno-lobby?roomCode=$roomCode';
          case 'draw': return '/draw-lobby?roomCode=$roomCode';
          case 'trivia': return '/trivia-lobby?roomCode=$roomCode';
          case 'meme': return '/meme-lobby?roomCode=$roomCode';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
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
      GoRoute(path: '/arcade/rps', builder: (c, s) => const RpsScreen()),
      GoRoute(path: '/arcade/ttt', builder: (c, s) => const TttScreen()),
      GoRoute(path: '/arcade/tow', builder: (c, s) => const TowScreen()),
      GoRoute(path: '/arcade/runner', builder: (c, s) => const RunnerScreen()),
      GoRoute(path: '/arcade/archery', builder: (c, s) => const ArcheryScreen()),

      GoRoute(path: '/arcade/iq_puzzle', builder: (c, s) => const IqPuzzleScreen()),
      GoRoute(path: '/arcade/memory_match', builder: (c, s) => const MemoryMatchScreen()),
      GoRoute(path: '/arcade/basketball', builder: (c, s) => const BasketballScreen()),
      GoRoute(path: '/arcade/slingshot', builder: (c, s) => const SlingshotScreen()),
      GoRoute(path: '/arcade/word_scramble', builder: (c, s) => const WordScrambleScreen()),
      GoRoute(path: '/arcade/color_rush', builder: (c, s) => const ColorRushScreen()),
      GoRoute(path: '/arcade/tower_stack', builder: (c, s) => const TowerStackScreen()),

      GoRoute(
        path: '/chess-lobby',
        builder: (c, s) => ChessLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
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
      GoRoute(
        path: '/ludo-lobby',
        builder: (c, s) => LudoLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
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
      GoRoute(
        path: '/uno-lobby',
        builder: (c, s) => UnoLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
      GoRoute(
        path: '/uno-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          final numPlayers = int.tryParse(s.uri.queryParameters['players'] ?? '2') ?? 2;
          return UnoWaitingRoom(roomCode: roomCode, isCreator: creator, numPlayers: numPlayers);
        },
      ),
      GoRoute(
        path: '/uno/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          final numPlayers = int.tryParse(s.uri.queryParameters['players'] ?? '2') ?? 2;
          return UnoScreen(roomCode: roomCode, isCreator: isCreator, numPlayers: numPlayers);
        },
      ),
      GoRoute(
        path: '/draw-lobby',
        builder: (c, s) => DrawLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
      GoRoute(
        path: '/draw-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          final maxPlayers = int.tryParse(s.uri.queryParameters['players'] ?? '4') ?? 4;
          return DrawWaitingRoom(roomCode: roomCode, isCreator: creator, maxPlayers: maxPlayers);
        },
      ),
      GoRoute(
        path: '/draw/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          final maxPlayers = int.tryParse(s.uri.queryParameters['players'] ?? '4') ?? 4;
          return DrawScreen(roomCode: roomCode, isCreator: isCreator, maxPlayers: maxPlayers);
        },
      ),
      GoRoute(
        path: '/trivia-lobby',
        builder: (c, s) => TriviaLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
      GoRoute(
        path: '/trivia-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          final category = s.uri.queryParameters['category'] ?? 'random';
          return TriviaWaitingRoom(roomCode: roomCode, isCreator: creator, category: category);
        },
      ),
      GoRoute(
        path: '/trivia/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          final category = s.uri.queryParameters['category'] ?? 'random';
          return TriviaScreen(roomCode: roomCode, isCreator: isCreator, category: category);
        },
      ),
      GoRoute(
        path: '/meme-lobby',
        builder: (c, s) => MemeLobby(roomCode: s.uri.queryParameters['roomCode']),
      ),
      GoRoute(
        path: '/meme-waiting/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final creator = s.uri.queryParameters['creator'] == 'true';
          final maxP = int.tryParse(s.uri.queryParameters['players'] ?? '8') ?? 8;
          return MemeWaitingRoom(
            roomCode: roomCode,
            isCreator: creator,
            maxPlayers: maxP,
          );
        },
      ),
      GoRoute(
        path: '/meme/:roomCode',
        builder: (c, s) {
          final roomCode = s.pathParameters['roomCode']!;
          final isCreator = s.uri.queryParameters['creator'] == 'true';
          return MemeScreen(
            roomCode: roomCode,
            isCreator: isCreator,
          );
        },
      ),
    ],
  );
});
