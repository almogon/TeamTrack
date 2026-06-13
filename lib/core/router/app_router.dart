import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/notifiers/auth_notifier.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/teams/screens/create_team_screen.dart';
import '../../features/teams/screens/team_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authNotifierProvider);
  return GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/home',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authNotifier.isLoggedIn;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/teams/new', builder: (_, __) => const CreateTeamScreen()),
      GoRoute(
        path: '/teams/:id',
        builder: (_, state) =>
            TeamDetailScreen(teamId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
