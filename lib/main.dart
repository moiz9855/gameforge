import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/utils/supabase_config.dart';
import 'core/services/update_service.dart';
import 'core/widgets/update_dialog.dart';
import 'core/services/achievement_service.dart';
import 'core/services/progress_sync_service.dart';
import 'core/services/chat_service.dart';
import 'features/auth/presentation/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // Initialize chat service (FCM, presence pings, auth listener)
  await ChatService.instance.init();

  runApp(
    const ProviderScope(
      child: GameForgeApp(),
    ),
  );
}

class GameForgeApp extends ConsumerStatefulWidget {
  const GameForgeApp({super.key});

  @override
  ConsumerState<GameForgeApp> createState() => _GameForgeAppState();
}

class _GameForgeAppState extends ConsumerState<GameForgeApp> {
  /// Run at most one update check per cold start after the user session exists.
  bool _updateCheckScheduled = false;
  StreamSubscription<Achievement>? _achievementSubscription;
  StreamSubscription<ChatMessage>? _inAppNotifSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize achievement listener
    _achievementSubscription = AchievementService.instance.onAchievementUnlocked.listen((achievement) {
      _showAchievementOverlay(achievement);
    });
    // Initialize in-app chat notification listener
    _inAppNotifSubscription = ChatService.instance.onInAppNotification.listen((msg) {
      _showChatNotificationBanner(msg);
    });
  }

  @override
  void dispose() {
    _achievementSubscription?.cancel();
    _inAppNotifSubscription?.cancel();
    super.dispose();
  }

  void _showAchievementOverlay(Achievement achievement) {
    final overlayState = appNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => AchievementToast(
        achievement: achievement,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlayState.insert(entry);
  }

  void _showChatNotificationBanner(ChatMessage msg) {
    final overlayState = appNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ChatNotificationBanner(
        message: msg,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          appNavigatorKey.currentContext?.push('/chat/${msg.senderId}');
        },
      ),
    );
    overlayState.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      next.whenData((authState) {
        final wasAuthed = prev?.valueOrNull?.session != null;
        final isAuthed = authState.session != null;
        if (isAuthed && !wasAuthed) {
          ProgressSyncService.instance.syncFromSupabase();
        }

        if (authState.session == null) return;
        if (_updateCheckScheduled) return;
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
          _updateCheckScheduled = true;
          return;
        }
        _updateCheckScheduled = true;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final navContext = appNavigatorKey.currentContext;
          if (navContext == null || !navContext.mounted) return;

          final info = await UpdateService.instance.checkForUpdate();
          if (!info.hasUpdate || !navContext.mounted) return;

          await showDialog<void>(
            context: navContext,
            barrierDismissible: !info.isForced,
            builder: (_) => UpdateDialog(info: info),
          );
        });
      });
    });

    return MaterialApp.router(
      title: 'GameForge',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class AchievementToast extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const AchievementToast({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF05A28),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF05A28).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1AF05A28),
                      ),
                      child: Center(
                        child: Text(
                          widget.achievement.badge,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACHIEVEMENT UNLOCKED!',
                          style: GoogleFonts.pressStart2p(
                            color: const Color(0xFFF05A28),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.achievement.title.toUpperCase(),
                          style: GoogleFonts.pressStart2p(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.achievement.description,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatNotificationBanner extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _ChatNotificationBanner({
    required this.message,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_ChatNotificationBanner> createState() => _ChatNotificationBannerState();
}

class _ChatNotificationBannerState extends State<_ChatNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.message.content.length > 60
        ? '${widget.message.content.substring(0, 57)}...'
        : widget.message.content;

    return SlideTransition(
      position: _offsetAnimation,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF05A28).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF05A28).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF05A28).withValues(alpha: 0.15),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chat_bubble_rounded,
                            color: Color(0xFFF05A28),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW MESSAGE',
                              style: GoogleFonts.pressStart2p(
                                color: const Color(0xFFF05A28),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
