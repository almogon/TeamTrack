import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../teams/models/player.dart';
import '../../teams/models/team.dart';
import '../../teams/providers/team_provider.dart';
import '../models/match.dart';
import '../providers/live_match_notifier.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  const LiveMatchScreen({super.key, required this.match, required this.team});

  final Match match;
  final Team team;

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref
            .read(liveMatchProvider(widget.match.id).notifier)
            .initialize(widget.match,
                sport: widget.team.sport, format: widget.team.format);
      }
    });
  }

  // ── stat catalogue per sport ──────────────────────────────────────────────

  static const _stats = {
    'football': [
      ('goal', 'Goal', Icons.sports_soccer, null),
      ('assist', 'Assist', Icons.trending_up, null),
      ('shot', 'Shot', Icons.adjust, null),
      ('save', 'Save', Icons.back_hand, null),
      ('yellow', 'Yellow card', Icons.square, Colors.amber),
      ('red', 'Red card', Icons.square, Colors.red),
    ],
    'basketball': [
      ('point', 'Point', Icons.sports_basketball, null),
      ('rebound', 'Rebound', Icons.refresh, null),
      ('assist', 'Assist', Icons.trending_up, null),
      ('foul', 'Foul', Icons.front_hand, null),
    ],
    'volleyball': [
      ('serve', 'Serve', Icons.sports_volleyball, null),
      ('block', 'Block', Icons.block_flipped, null),
      ('error', 'Error', Icons.close, Colors.red),
    ],
  };

  void _showStatPicker(BuildContext context, String playerId) {
    final sport = ref.read(liveMatchProvider(widget.match.id)).sport;
    final entries =
        _stats[sport] ?? _stats['football']!;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Record stat',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...entries.map((e) {
              final (type, label, icon, color) = e;
              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ref
                      .read(liveMatchProvider(widget.match.id).notifier)
                      .recordStat(playerId, type);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End match?'),
        content: const Text(
            'This will mark the match as finished and calculate final stats.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End match')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(liveMatchProvider(widget.match.id).notifier).endMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(liveMatchProvider(widget.match.id));
    final teamAsync = ref.watch(teamDetailProvider(widget.team.id));
    final notifier = ref.read(liveMatchProvider(widget.match.id).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('vs ${widget.match.opponentName}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Timer + score header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Text(
                  liveState.timerDisplay,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                Text(
                  liveState.periodLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                if (liveState.sport != 'volleyball') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Goals: ${liveState.scoreFor}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                  ),
                ],
              ],
            ),
          ),

          // Match controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: _ControlRow(
              status: liveState.matchStatus,
              onStart: notifier.start,
              onPause: notifier.pause,
              onResume: notifier.resume,
              onEnd: () => _confirmEnd(context),
              onSummary: () => context.push(
                '/teams/${widget.team.id}/matches/${widget.match.id}/summary',
              ),
            ),
          ),

          // Player grid
          Expanded(
            child: teamAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (detail) {
                final players =
                    detail.players.where((p) => p.active).toList();
                if (players.isEmpty) {
                  return const Center(child: Text('No active players'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: players.length,
                  itemBuilder: (_, i) => _PlayerCard(
                    player: players[i],
                    enabled: liveState.matchStatus == 'live',
                    onTap: () => _showStatPicker(context, players[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
    required this.onSummary,
  });

  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: switch (status) {
        'scheduled' => [
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ],
        'live' => [
            IconButton.outlined(
              onPressed: onPause,
              icon: const Icon(Icons.pause),
              tooltip: 'Pause',
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop),
              label: const Text('End match'),
            ),
          ],
        'paused' => [
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop),
              label: const Text('End match'),
            ),
          ],
        'finished' => [
            FilledButton.icon(
              onPressed: onSummary,
              icon: const Icon(Icons.bar_chart),
              label: const Text('View summary'),
            ),
          ],
        _ => const [],
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.enabled,
    required this.onTap,
  });

  final Player player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = player.displayName.isNotEmpty
        ? player.displayName[0].toUpperCase()
        : '?';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (player.number != null)
                Text(
                  '#${player.number}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              Text(
                player.displayName,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
