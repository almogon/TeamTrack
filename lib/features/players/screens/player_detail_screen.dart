import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/models/player.dart';
import '../../teams/providers/team_provider.dart';
import '../models/player_score.dart';
import '../providers/player_stats_provider.dart';

class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({
    super.key,
    required this.teamId,
    required this.playerId,
  });

  final String teamId;
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailProvider(teamId));

    return detailAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (detail) {
        final player = detail.players
            .cast<Player?>()
            .firstWhere((p) => p?.id == playerId, orElse: () => null);

        if (player == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Player not found')),
          );
        }

        return _PlayerDetailView(
          player: player,
          teamId: teamId,
          sport: detail.team.sport,
        );
      },
    );
  }
}

class _PlayerDetailView extends ConsumerWidget {
  const _PlayerDetailView({
    required this.player,
    required this.teamId,
    required this.sport,
  });

  final Player player;
  final String teamId;
  final String sport;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove player'),
        content: Text(
            'Remove ${player.displayName} from the roster? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await Supabase.instance.client
        .from('players')
        .update({'active': false}).eq('id', player.id);

    ref.invalidate(teamDetailProvider(teamId));
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final key = (playerId: player.id, teamId: teamId);

    final careerAsync = ref.watch(playerCareerProvider(key));
    final historyAsync = ref.watch(playerMatchHistoryProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text(player.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push(
              '/teams/$teamId/players/${player.id}/edit',
              extra: player,
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_remove_outlined, color: cs.error),
            tooltip: 'Remove',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────────
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: cs.primaryContainer,
              child: Text(
                player.number != null ? '${player.number}' : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              player.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (player.alias != null && player.alias!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '"${player.alias}"',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: cs.secondary),
              ),
            ),
          ],
          if (player.position != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Chip(
                label: Text(player.position!),
                backgroundColor: cs.secondaryContainer,
                labelStyle: TextStyle(color: cs.onSecondaryContainer),
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ── Career stats ─────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.bar_chart_outlined, color: cs.outline),
              const SizedBox(width: 8),
              Text('Season stats',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),

          careerAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load stats: $e',
                style: TextStyle(color: cs.error)),
            data: (career) {
              if (career == null || career.matchesPlayed == 0) {
                return Center(
                  child: Text(
                    'No stats recorded yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.outline),
                  ),
                );
              }
              return _CareerCard(career: career, cs: cs);
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── Match history ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.history_outlined, color: cs.outline),
              const SizedBox(width: 8),
              Text('Match history',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),

          historyAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load history: $e',
                style: TextStyle(color: cs.error)),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'No finished matches yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.outline),
                  ),
                );
              }
              return Column(
                children: entries
                    .map((e) => _MatchHistoryTile(entry: e, sport: sport))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Career card ───────────────────────────────────────────────────────────────

class _CareerCard extends StatelessWidget {
  const _CareerCard({required this.career, required this.cs});

  final PlayerScore career;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              label: 'Points',
              value: '${career.totalPoints}',
              color: career.totalPoints >= 0 ? cs.primary : cs.error,
            ),
            SizedBox(
              height: 40,
              child: VerticalDivider(width: 32, color: cs.outlineVariant),
            ),
            _Stat(
              label: 'Matches',
              value: '${career.matchesPlayed}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

// ── Match history tile ────────────────────────────────────────────────────────

class _MatchHistoryTile extends StatelessWidget {
  const _MatchHistoryTile({required this.entry, required this.sport});

  final PlayerMatchEntry entry;
  final String sport;

  String _statSummary() {
    final c = entry.statCounts;
    switch (sport) {
      case 'basketball':
        final parts = <String>[];
        if ((c['point'] ?? 0) > 0) parts.add('${c['point']}pts');
        if ((c['rebound'] ?? 0) > 0) parts.add('${c['rebound']}reb');
        if ((c['assist'] ?? 0) > 0) parts.add('${c['assist']}ast');
        if ((c['foul'] ?? 0) > 0) parts.add('${c['foul']}f');
        return parts.isEmpty ? '—' : parts.join(' · ');
      case 'volleyball':
        final parts = <String>[];
        if ((c['serve'] ?? 0) > 0) parts.add('${c['serve']}srv');
        if ((c['block'] ?? 0) > 0) parts.add('${c['block']}blk');
        if ((c['error'] ?? 0) > 0) parts.add('${c['error']}err');
        return parts.isEmpty ? '—' : parts.join(' · ');
      default: // football
        final parts = <String>[];
        if ((c['goal'] ?? 0) > 0) parts.add('${c['goal']}G');
        if ((c['assist'] ?? 0) > 0) parts.add('${c['assist']}A');
        if ((c['shot'] ?? 0) > 0) parts.add('${c['shot']}S');
        if ((c['save'] ?? 0) > 0) parts.add('${c['save']}Sv');
        if ((c['yellow'] ?? 0) > 0) parts.add('${c['yellow']}Y');
        if ((c['red'] ?? 0) > 0) parts.add('${c['red']}R');
        return parts.isEmpty ? '—' : parts.join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final match = entry.match;
    final d = match.matchDate;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final ha = match.isHome ? 'H' : 'A';
    final score = (match.scoreFor != null && match.scoreAgainst != null)
        ? '${match.scoreFor}–${match.scoreAgainst}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('vs ${match.opponentName}'),
        subtitle: Text(
          '$dateLabel · $ha${score != null ? ' · $score' : ''}\n${_statSummary()}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.points >= 0 ? '+' : ''}${entry.points}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: entry.points >= 0 ? cs.primary : cs.error,
                  ),
            ),
            Text('pts', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
