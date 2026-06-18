import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/notifiers/auth_notifier.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/matches/models/match.dart';
import '../../features/matches/screens/create_match_screen.dart';
import '../../features/matches/screens/live_match_screen.dart';
import '../../features/matches/screens/match_summary_screen.dart';
import '../../features/players/screens/add_player_screen.dart';
import '../../features/players/screens/player_detail_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/teams/models/player.dart';
import '../../features/teams/models/team.dart';
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
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/teams/new', builder: (_, _) => const CreateTeamScreen()),
      GoRoute(
        path: '/teams/:teamId',
        builder: (_, state) =>
            TeamDetailScreen(teamId: state.pathParameters['teamId']!),
      ),
      GoRoute(
        path: '/teams/:teamId/players/new',
        builder: (_, state) =>
            AddPlayerScreen(teamId: state.pathParameters['teamId']!),
      ),
      GoRoute(
        path: '/teams/:teamId/players/:playerId',
        builder: (_, state) => PlayerDetailScreen(
          teamId: state.pathParameters['teamId']!,
          playerId: state.pathParameters['playerId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/players/:playerId/edit',
        builder: (_, state) => AddPlayerScreen(
          teamId: state.pathParameters['teamId']!,
          player: state.extra as Player?,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/matches/new',
        builder: (_, state) =>
            CreateMatchScreen(teamId: state.pathParameters['teamId']!),
      ),
      GoRoute(
        path: '/teams/:teamId/matches/:matchId/live',
        builder: (_, state) {
          final args = state.extra! as ({Match match, Team team});
          return LiveMatchScreen(match: args.match, team: args.team);
        },
      ),
      GoRoute(
        path: '/teams/:teamId/matches/:matchId/summary',
        builder: (_, state) => MatchSummaryScreen(
          matchId: state.pathParameters['matchId']!,
          teamId: state.pathParameters['teamId']!,
        ),
      ),
    ],
  );
});
