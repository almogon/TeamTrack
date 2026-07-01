import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../teams/providers/team_provider.dart';
import '../models/stat_event.dart';
import '../models/stat_rule.dart';
import '../providers/match_provider.dart';
import '../providers/stat_rules_provider.dart';

class MatchSummaryScreen extends ConsumerWidget {
  const MatchSummaryScreen({
    super.key,
    required this.matchId,
    required this.teamId,
  });

  final String matchId;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    final eventsAsync = ref.watch(matchEventsProvider(matchId));

    final anyLoading =
        matchAsync.isLoading || teamAsync.isLoading || eventsAsync.isLoading;
    if (anyLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final anyError =
        matchAsync.hasError || teamAsync.hasError || eventsAsync.hasError;
    if (anyError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match Summary')),
        body: Center(
            child: Text(
                '${matchAsync.error ?? teamAsync.error ?? eventsAsync.error}')),
      );
    }

    final match = matchAsync.value!;
    final teamDetail = teamAsync.value!;
    final events = eventsAsync.value!;

    return ref.watch(statRulesProvider(teamDetail.team.sport)).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
              appBar: AppBar(), body: Center(child: Text('$e'))),
          data: (rules) {
            // Group events by player
            final byPlayer = <String, List<StatEvent>>{};
            for (final ev in events) {
              byPlayer.putIfAbsent(ev.playerId, () => []).add(ev);
            }

            // Build stat counts per player
            final playerStats = byPlayer.map((playerId, playerEvents) {
              final counts = <String, int>{};
              for (final ev in playerEvents) {
                counts[ev.statType] =
                    (counts[ev.statType] ?? 0) + ev.value;
              }
              final points = _computePoints(counts, rules);
              return MapEntry(playerId, (counts: counts, points: points));
            });

            // Sort by points descending
            final sorted = playerStats.entries.toList()
              ..sort((a, b) => b.value.points.compareTo(a.value.points));

            final playerById = {
              for (final p in teamDetail.players) p.id: p,
            };

            final d = match.matchDate;
            final dateLabel =
                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

            return Scaffold(
              appBar: AppBar(title: Text('vs ${match.opponentName}')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Match header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(dateLabel),
                            const SizedBox(width: 16),
                            Icon(Icons.location_on_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(match.isHome ? 'Home' : 'Away'),
                          ]),
                          if (match.competition != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.emoji_events_outlined,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(match.competition!),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (sorted.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No stats recorded for this match.'),
                      ),
                    )
                  else ...[
                    // MVP badge — top scorer with at least 1 point
                    if (sorted.first.value.points > 0) ...[
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: ListTile(
                          leading: const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFFFD700),
                            size: 28,
                          ),
                          title: const Text('MVP'),
                          subtitle: Text(
                            playerById[sorted.first.key]?.displayName ??
                                'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            '${sorted.first.value.points} pts',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Player stats',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...sorted.map((entry) {
                      final player = playerById[entry.key];
                      final name = player?.displayName ?? 'Unknown';
                      final counts = entry.value.counts;
                      final points = entry.value.points;
                      final sport = teamDetail.team.sport;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(_statSummary(sport, counts)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$points',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: points >= 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .error,
                                    ),
                              ),
                              Text('pts',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
  }

  int _computePoints(Map<String, int> counts, List<StatRule> rules) {
    int total = 0;
    for (final rule in rules) {
      total += (counts[rule.statType] ?? 0) * rule.points;
    }
    return total;
  }

  String _statSummary(String sport, Map<String, int> counts) {
    switch (sport) {
      case 'basketball':
        final parts = <String>[];
        if ((counts['point'] ?? 0) > 0) {
          parts.add('${counts['point']}pts');
        }
        if ((counts['rebound'] ?? 0) > 0) {
          parts.add('${counts['rebound']}reb');
        }
        if ((counts['assist'] ?? 0) > 0) {
          parts.add('${counts['assist']}ast');
        }
        if ((counts['foul'] ?? 0) > 0) {
          parts.add('${counts['foul']}f');
        }
        return parts.isEmpty ? '—' : parts.join(' · ');
      case 'volleyball':
        final parts = <String>[];
        if ((counts['serve'] ?? 0) > 0) {
          parts.add('${counts['serve']}srv');
        }
        if ((counts['block'] ?? 0) > 0) {
          parts.add('${counts['block']}blk');
        }
        if ((counts['error'] ?? 0) > 0) {
          parts.add('${counts['error']}err');
        }
        return parts.isEmpty ? '—' : parts.join(' · ');
      default: // football
        final parts = <String>[];
        if ((counts['goal'] ?? 0) > 0) parts.add('${counts['goal']}G');
        if ((counts['assist'] ?? 0) > 0) parts.add('${counts['assist']}A');
        if ((counts['shot'] ?? 0) > 0) parts.add('${counts['shot']}S');
        if ((counts['save'] ?? 0) > 0) parts.add('${counts['save']}Sv');
        if ((counts['yellow'] ?? 0) > 0) parts.add('${counts['yellow']}Y');
        if ((counts['red'] ?? 0) > 0) parts.add('${counts['red']}R');
        return parts.isEmpty ? '—' : parts.join(' · ');
    }
  }
}
