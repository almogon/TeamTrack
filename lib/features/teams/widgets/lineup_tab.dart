import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/bench_list.dart';
import '../../../shared/widgets/player_picker_sheet.dart';
import '../models/lineup_formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../providers/lineup_provider.dart';
import '../providers/team_provider.dart';
import '../providers/teams_provider.dart';
import 'lineup_grid_view.dart';

/// Below this width the Line-Up tab uses the single-column phone layout;
/// at or above it, the two-column tablet/desktop layout.
const _tabletBreakpoint = 700.0;

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
      builder: (context) => PlayerPickerSheet(
        players: widget.players,
        currentPlayerId: currentPlayer?.id,
        assignedPlayerIds: assignedPlayerIds,
        allowClear: currentPlayer != null,
        positions: widget.team.sportType.positions,
      ),
    );
    if (result == null) return;

    if (result == clearSlotSentinel) {
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

        final formationDropdown = DropdownButtonFormField<String>(
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
        );

        final pitch = LineupGridView(
          team: widget.team,
          formation: _currentFormation,
          slots: _slots,
          onSlotTap: _openPicker,
          onSlotDrop: (slotIndex, player) =>
              _assignPlayerToSlot(slotIndex, player.id),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _tabletBreakpoint;
            return Column(
              children: [
                Expanded(
                  child: isWide
                      ? _WideLayout(
                          teamId: widget.team.id,
                          formationDropdown: formationDropdown,
                          pitch: pitch,
                          bench: bench,
                        )
                      : _CompactLayout(
                          teamId: widget.team.id,
                          formationDropdown: formationDropdown,
                          pitch: pitch,
                          bench: bench,
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
      },
    );
  }
}

// ── Responsive layouts ──────────────────────────────────────────────────────

/// Tablet/desktop: a league-actions row, then a bench panel (left, narrower,
/// vertically scrollable, ellipsized names) beside the formation + pitch
/// (right, wider — the pitch needs the room to stay readable).
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.teamId,
    required this.formationDropdown,
    required this.pitch,
    required this.bench,
  });

  final String teamId;
  final Widget formationDropdown;
  final Widget pitch;
  final List<Player> bench;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: BenchPanel(players: bench),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: Column(
              children: [
                formationDropdown,
                const SizedBox(height: 16),
                pitch,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone: formation dropdown above the pitch and a horizontally scrolling,
/// number-only bench. League actions live in the team's Settings tab, not
/// here.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.teamId,
    required this.formationDropdown,
    required this.pitch,
    required this.bench,
  });

  final String teamId;
  final Widget formationDropdown;
  final Widget pitch;
  final List<Player> bench;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The dropdown is capped/centered with the exact same formula
        // LineupGridView uses for the pitch (LineupGridView.pitchWidth),
        // computed from the same 16px-inset width — matching only the
        // *outer* padding still left them apart, because the pitch also
        // centers itself a second time inside that padding.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: SizedBox(
                width: LineupGridView.pitchWidth(constraints.maxWidth),
                child: formationDropdown,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: pitch,
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),
                BenchHorizontalList(players: bench),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
