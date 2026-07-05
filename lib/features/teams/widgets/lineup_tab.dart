import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/player_diamond.dart';
import '../models/lineup_formation.dart';
import '../models/player.dart';
import '../models/sport_type.dart';
import '../models/team.dart';
import '../providers/lineup_provider.dart';
import '../providers/team_provider.dart';
import '../providers/teams_provider.dart';
import 'lineup_grid_view.dart';

const _clearSlot = Object();

/// Line-Up tab: a formation combobox plus an interactive slot grid ([
/// LineupGridView] — the same grid the main menu renders read-only) and a
/// bench of players not currently in the formation. Everything here is
/// local, editable state; nothing reaches Supabase until "Save" is tapped
/// (see [_save]).
class LineupTab extends ConsumerStatefulWidget {
  const LineupTab({super.key, required this.team, required this.players});

  final Team team;
  final List<Player> players;

  @override
  ConsumerState<LineupTab> createState() => _LineupTabState();
}

class _LineupTabState extends ConsumerState<LineupTab> {
  late final List<LineupFormation> _formations =
      LineupFormation.forTeam(widget.team.sportType, widget.team.format);
  late final List<String> _roleOrder =
      widget.team.sportType.positions.map((p) => p.code).toList();

  bool _initialized = false;
  String? _formationKey;
  Map<int, Player> _slots = {};
  bool _dirty = false;
  bool _saving = false;

  void _initFrom(TeamLineup lineup) {
    if (_initialized) return;
    _initialized = true;
    _formationKey = lineup.formation ?? _formations.first.key;
    _slots = Map.of(lineup.slots);
    // Auto-picking a default formation is itself an unsaved change.
    _dirty = lineup.formation == null;
  }

  LineupFormation get _currentFormation => _formations.firstWhere(
        (f) => f.key == _formationKey,
        orElse: () => _formations.first,
      );

  void _onFormationChanged(String? newKey) {
    if (newKey == null || newKey == _formationKey) return;
    final to = _formations.firstWhere((f) => f.key == newKey);
    final remapped = LineupFormation.remapAssignments(
      from: _currentFormation,
      to: to,
      oldAssignments: _slots,
      roleOrder: _roleOrder,
    );
    setState(() {
      _formationKey = newKey;
      _slots = remapped;
      _dirty = true;
    });
  }

  Future<void> _openPicker(int slotIndex) async {
    final currentPlayer = _slots[slotIndex];
    final assignedPlayerIds = _slots.values.map((p) => p.id).toSet();

    final result = await showModalBottomSheet<Object?>(
      context: context,
      builder: (context) => _PlayerPickerSheet(
        players: widget.players,
        currentPlayerId: currentPlayer?.id,
        assignedPlayerIds: assignedPlayerIds,
        allowClear: currentPlayer != null,
        positions: widget.team.sportType.positions,
      ),
    );
    if (result == null) return;

    if (result == _clearSlot) {
      setState(() {
        _slots.remove(slotIndex);
        _dirty = true;
      });
    } else {
      _assignPlayerToSlot(slotIndex, result as String);
    }
  }

  void _assignPlayerToSlot(int slotIndex, String playerId) {
    setState(() {
      // A player only ever occupies one slot.
      _slots.removeWhere((_, p) => p.id == playerId);
      final player = widget.players.firstWhere((p) => p.id == playerId);
      _slots[slotIndex] = player;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('teams')
          .update({'lineup_formation': _formationKey}).eq('id', widget.team.id);
      await Supabase.instance.client
          .from('lineup_slots')
          .delete()
          .eq('team_id', widget.team.id);
      if (_slots.isNotEmpty) {
        await Supabase.instance.client.from('lineup_slots').insert([
          for (final entry in _slots.entries)
            {
              'team_id': widget.team.id,
              'slot_index': entry.key,
              'player_id': entry.value.id,
            },
        ]);
      }
      ref.invalidate(teamLineupProvider(widget.team.id));
      ref.invalidate(teamDetailProvider(widget.team.id));
      ref.invalidate(teamsProvider);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Line-up saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineupAsync = ref.watch(teamLineupProvider(widget.team.id));

    return lineupAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (lineup) {
        _initFrom(lineup);
        final assignedIds = _slots.values.map((p) => p.id).toSet();
        final bench =
            widget.players.where((p) => !assignedIds.contains(p.id)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _formationKey,
                decoration: const InputDecoration(
                  labelText: 'Formation',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final formation in _formations)
                    DropdownMenuItem(
                      value: formation.key,
                      child: Text(formation.key),
                    ),
                ],
                onChanged: _onFormationChanged,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LineupGridView(
                      team: widget.team,
                      formation: _currentFormation,
                      slots: _slots,
                      onSlotTap: _openPicker,
                      onSlotDrop: (slotIndex, player) =>
                          _assignPlayerToSlot(slotIndex, player.id),
                    ),
                    const Divider(height: 32, indent: 16, endIndent: 16),
                    _BenchList(players: bench),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: (_dirty && !_saving) ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BenchList extends StatelessWidget {
  const _BenchList({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bench (${players.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            const Text('Everyone is on the pitch')
          else
            for (final player in players)
              Draggable<Player>(
                data: player,
                feedback: Material(
                  color: Colors.transparent,
                  child: PlayerDiamond(player: player, onTap: () {}),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.4,
                  child: _BenchTile(player: player),
                ),
                child: _BenchTile(player: player),
              ),
        ],
      ),
    );
  }
}

class _BenchTile extends StatelessWidget {
  const _BenchTile({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(player.number?.toString() ?? '?'),
      ),
      title: Text(player.name),
      subtitle: player.position != null ? Text(player.position!) : null,
    );
  }
}

class _PlayerPickerSheet extends StatefulWidget {
  const _PlayerPickerSheet({
    required this.players,
    required this.currentPlayerId,
    required this.assignedPlayerIds,
    required this.allowClear,
    required this.positions,
  });

  final List<Player> players;
  final String? currentPlayerId;
  final Set<String> assignedPlayerIds;
  final bool allowClear;
  final List<Position> positions;

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  String? _positionFilter;

  bool _isElsewhere(Player player) =>
      player.id != widget.currentPlayerId &&
      widget.assignedPlayerIds.contains(player.id);

  @override
  Widget build(BuildContext context) {
    final filtered = _positionFilter == null
        ? widget.players
        : widget.players.where((p) => p.position == _positionFilter).toList();

    // Unassigned players first, already-assigned ones (elsewhere) after —
    // each group keeps the roster's original relative order.
    final unassigned = <Player>[];
    final elsewhere = <Player>[];
    for (final player in filtered) {
      (_isElsewhere(player) ? elsewhere : unassigned).add(player);
    }
    final sorted = [...unassigned, ...elsewhere];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _positionFilter == null,
                  onSelected: (_) => setState(() => _positionFilter = null),
                ),
                for (final position in widget.positions)
                  ChoiceChip(
                    label: Text(position.code),
                    selected: _positionFilter == position.code,
                    onSelected: (_) => setState(() {
                      _positionFilter =
                          _positionFilter == position.code
                              ? null
                              : position.code;
                    }),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (widget.allowClear)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text('Clear this slot'),
                    onTap: () => Navigator.pop(context, _clearSlot),
                  ),
                for (final player in sorted)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(player.number?.toString() ?? '?'),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (player.position != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            player.position!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: _isElsewhere(player)
                        ? const Text('Already in another slot')
                        : null,
                    trailing: player.id == widget.currentPlayerId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, player.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
