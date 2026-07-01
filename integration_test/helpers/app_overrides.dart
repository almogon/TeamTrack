import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:team_track/features/auth/models/profile.dart';
import 'package:team_track/features/auth/notifiers/auth_notifier.dart';
import 'package:team_track/features/auth/providers/profile_provider.dart';
import 'package:team_track/features/matches/models/match.dart';
import 'package:team_track/features/matches/providers/match_list_provider.dart';
import 'package:team_track/features/players/models/player_score.dart';
import 'package:team_track/features/players/providers/player_stats_provider.dart';
import 'package:team_track/features/subscriptions/models/subscription.dart';
import 'package:team_track/features/subscriptions/providers/subscription_provider.dart';
import 'package:team_track/features/teams/models/player.dart';
import 'package:team_track/features/teams/models/team.dart';
import 'package:team_track/features/teams/providers/leaderboard_provider.dart';
import 'package:team_track/features/teams/providers/team_provider.dart';
import 'package:team_track/features/teams/providers/teams_provider.dart';
import 'package:team_track/main.dart';

import 'fake_auth_notifier.dart';
import 'fake_notifiers.dart';

final _defaultProfile = Profile(
  id: 'user-1',
  username: 'testcoach',
  plan: 'free',
  role: 'user',
  createdAt: DateTime(2026, 1, 1),
);

/// Builds the full app wrapped in [ProviderScope] with all Supabase-touching
/// providers replaced by in-memory fakes.
Widget buildTestApp({
  bool loggedIn = true,
  List<Team>? teams,
  Profile? profile,
  Subscription? subscription,
  ({Team team, List<Player> players})? teamDetail,
  List<Match>? matches,
  List<PlayerScore>? leaderboard,
}) {
  final resolvedTeams = teams ?? [fakeTeam];
  final resolvedProfile = profile ?? _defaultProfile;
  final resolvedTeamDetail =
      teamDetail ?? (team: fakeTeam, players: fakePlayers);
  final resolvedMatches = matches ?? [];
  final resolvedLeaderboard = leaderboard ?? [];

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(
        (ref) => FakeAuthNotifier(loggedIn: loggedIn),
      ),
      teamsProvider.overrideWith(
        () => FakeTeamsNotifier(resolvedTeams),
      ),
      profileProvider.overrideWith(
        (ref) async => resolvedProfile,
      ),
      subscriptionProvider.overrideWith(
        (ref) async => subscription,
      ),
      teamDetailProvider.overrideWith(
        (ref, teamId) async => resolvedTeamDetail,
      ),
      matchListProvider.overrideWith(
        () => FakeMatchListNotifier(resolvedMatches),
      ),
      teamLeaderboardProvider.overrideWith(
        (ref, teamId) async => resolvedLeaderboard,
      ),
      playerCareerProvider.overrideWith(
        (ref, args) async => null,
      ),
      playerMatchHistoryProvider.overrideWith(
        (ref, args) async => [],
      ),
    ],
    child: const TeamTrackApp(),
  );
}
