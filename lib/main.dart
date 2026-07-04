import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/web/url_strategy.dart';
import 'features/matches/services/match_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path-based (not hash-based) web routing: Supabase auth redirects (e.g.
  // password recovery) put session tokens in the URL fragment, which
  // collides with GoRouter's default "#/route" hash strategy and silently
  // breaks session detection. No-op on non-web platforms.
  configureUrlStrategy();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await MatchNotificationService.initialize();
  runApp(const ProviderScope(child: TeamTrackApp()));
}

class TeamTrackApp extends ConsumerWidget {
  const TeamTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'TeamTrack',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
