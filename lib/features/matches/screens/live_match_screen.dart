import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/bench_list.dart';
import '../../../shared/widgets/player_picker_sheet.dart';
import '../../teams/models/lineup_formation.dart';
import '../../teams/models/player.dart';
import '../../teams/models/team.dart';
import '../../teams/providers/team_provider.dart';
import '../../teams/widgets/lineup_grid_view.dart';
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

  /// Tapping an on-field slot means different things depending on the
  /// match: mid-match with a player already there, it's the primary
  /// stat-recording action (unchanged from before); everywhere else
  /// (pre-kickoff setup, an empty slot, or reassigning while paused) it
  /// opens the same player picker the team's Line-Up tab uses — picking a
  /// player there goes through [LiveMatchNotifier.assignSlot], so it's
  /// substitution-tracked exactly like a bench-to-pitch drag is.
  Future<void> _onSlotTap(
    BuildContext context,
    int slotIndex,
    LiveMatchState liveState,
    List<Player> activePlayers,
  ) async {
    if (liveState.matchStatus == 'finished') return;
    final player = liveState.slots[slotIndex];
    if (liveState.matchStatus == 'live' && player != null) {
      _showStatPicker(context, player.id);
      return;
    }

    final assignedIds = liveState.slots.values.map((p) => p.id).toSet();
    final result = await showModalBottomSheet<Object?>(
      context: context,
      builder: (_) => PlayerPickerSheet(
        players: activePlayers,
        currentPlayerId: player?.id,
        assignedPlayerIds: assignedIds,
        allowClear: player != null,
        positions: widget.team.sportType.positions,
      ),
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(liveMatchProvider(widget.match.id).notifier);
    if (result == clearSlotSentinel) {
      notifier.clearSlot(slotIndex);
    } else {
      final chosen = activePlayers.firstWhere((p) => p.id == result);
      notifier.assignSlot(slotIndex, chosen);
    }
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

          // Lineup: same pitch + bench design as the team's Line-Up tab —
          // tap/drag a bench player onto a slot to sub them on; tap an
          // on-field player during live play to record a stat instead.
          Expanded(
            child: teamAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (detail) {
                if (!liveState.isInitialized || liveState.formation == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final activePlayers =
                    detail.players.where((p) => p.active).toList();
                if (activePlayers.isEmpty) {
                  return const Center(child: Text('No active players'));
                }

                final formations = LineupFormation.forTeam(
                    widget.team.sportType, widget.team.format);
                final roleOrder = widget.team.sportType.positions
                    .map((p) => p.code)
                    .toList();
                final onFieldIds =
                    liveState.slots.values.map((p) => p.id).toSet();
                final bench = activePlayers
                    .where((p) => !onFieldIds.contains(p.id))
                    .toList();

                final formationDropdown = DropdownButtonFormField<String>(
                  initialValue: liveState.formation!.key,
                  decoration: const InputDecoration(
                    labelText: 'Formation',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final formation in formations)
                      DropdownMenuItem(
                        value: formation.key,
                        child: Text(formation.key),
                      ),
                  ],
                  onChanged: liveState.matchStatus == 'finished'
                      ? null
                      : (key) {
                          if (key == null) return;
                          final formation =
                              formations.firstWhere((f) => f.key == key);
                          notifier.setFormation(formation,
                              roleOrder: roleOrder);
                        },
                );

                final pitch = LineupGridView(
                  team: widget.team,
                  formation: liveState.formation!,
                  slots: liveState.slots,
                  onSlotTap: (slotIndex) => _onSlotTap(
                      context, slotIndex, liveState, activePlayers),
                  onSlotDrop: liveState.matchStatus == 'finished'
                      ? null
                      : (slotIndex, player) =>
                          notifier.assignSlot(slotIndex, player),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: formationDropdown,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: pitch,
                      ),
                      const Divider(height: 32, indent: 16, endIndent: 16),
                      BenchHorizontalList(players: bench),
                    ],
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
