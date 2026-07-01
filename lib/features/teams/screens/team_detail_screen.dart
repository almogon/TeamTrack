import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../matches/models/match.dart';
import '../../matches/providers/match_list_provider.dart';
import '../../players/models/player_score.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/team_provider.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailProvider(teamId));

    return detailAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (detail) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(detail.team.name),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Text(
                        detail.team.sportFormatLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Roster'),
                      Tab(text: 'Matches'),
                      Tab(text: 'Leaderboard'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: Builder(
            builder: (ctx) {
              final tab = DefaultTabController.of(ctx);
              return AnimatedBuilder(
                animation: tab,
                builder: (_, _) {
                  if (tab.index == 0) {
                    return FloatingActionButton.extended(
                      onPressed: () =>
                          context.push('/teams/$teamId/players/new'),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add player'),
                    );
                  }
                  if (tab.index == 1) {
                    return FloatingActionButton.extended(
                      onPressed: () =>
                          context.push('/teams/$teamId/matches/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('New match'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
          body: TabBarView(
            children: [
              detail.players.isEmpty
                  ? const _EmptyRoster()
                  : _PlayerList(players: detail.players, teamId: teamId),
              _MatchListTab(teamId: teamId, team: detail.team),
              _LeaderboardTab(teamId: teamId),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Roster tab ────────────────────────────────────────────────────────────────

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off,
              size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No players yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Tap "Add player" to build your roster'),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.players, required this.teamId});

  final List<Player> players;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96, top: 8),
      itemCount: players.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final player = players[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              player.number != null ? '${player.number}' : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Text(player.name),
          subtitle: Row(
            children: [
              if (player.alias != null && player.alias!.isNotEmpty)
                Text('"${player.alias}"  '),
              if (player.position != null)
                Text(
                  player.position!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/teams/$teamId/players/${player.id}'),
        );
      },
    );
  }
}

// ── Matches tab ───────────────────────────────────────────────────────────────

class _MatchListTab extends ConsumerWidget {
  const _MatchListTab({required this.teamId, required this.team});

  final String teamId;
  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchListProvider(teamId));
    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (matches) {
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text('No matches yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Tap "New match" to schedule one'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96, top: 8),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) => _MatchTile(match: matches[i], team: team),
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.team});

  final Match match;
  final Team team;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _statusIcon(context),
      title: Text(match.opponentName),
      subtitle: Text(_subtitle()),
      trailing: _action(context),
    );
  }

  Widget _statusIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (match.status) {
      'live' => Icon(Icons.radio_button_checked, color: Colors.green),
      'paused' => Icon(Icons.pause_circle_outline, color: cs.primary),
      'finished' => Icon(Icons.check_circle_outline, color: cs.primary),
      _ => Icon(Icons.schedule, color: cs.outline),
    };
  }

  String _subtitle() {
    final d = match.matchDate;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final ha = match.isHome ? 'H' : 'A';
    final comp = match.competition != null ? ' · ${match.competition}' : '';
    return '$date · $ha$comp';
  }

  Widget _action(BuildContext context) {
    if (match.isFinished) {
      return TextButton(
        onPressed: () => context.push(
          '/teams/${team.id}/matches/${match.id}/summary',
        ),
        child: const Text('Summary'),
      );
    }
    return TextButton(
      onPressed: () => context.push(
        '/teams/${team.id}/matches/${match.id}/live',
        extra: (match: match, team: team),
      ),
      child: Text(match.isActive ? 'Continue' : 'Start'),
    );
  }
}

// ── Leaderboard tab ───────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(teamLeaderboardProvider(teamId));
    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (scores) {
        if (scores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text('No scores yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Complete a match to see rankings'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 8),
          itemCount: scores.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) => _LeaderboardTile(score: scores[i], rank: i + 1),
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.score, required this.rank});

  final PlayerScore score;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final medalColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => cs.outlineVariant,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank <= 3 ? medalColor.withAlpha(40) : cs.surfaceContainerHighest,
        child: Text(
          '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: rank <= 3 ? medalColor : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(score.displayName),
      subtitle: Text(
        '${score.matchesPlayed} match${score.matchesPlayed == 1 ? '' : 'es'}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${score.totalPoints}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: score.totalPoints >= 0 ? cs.primary : cs.error,
                ),
          ),
          Text('pts', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
