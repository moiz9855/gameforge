import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/utils/supabase_config.dart';
import 'core/services/update_service.dart';
import 'core/widgets/update_dialog.dart';
import 'features/auth/presentation/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  // Note: This will throw an error with placeholder values if you run it.
  // Replace placeholders in supabase_config.dart before running.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      next.whenData((authState) {
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
