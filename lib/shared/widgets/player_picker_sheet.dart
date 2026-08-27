import 'package:flutter/material.dart';

import '../../features/teams/models/player.dart';
import '../../features/teams/models/sport_type.dart';

/// Sentinel result from [PlayerPickerSheet] meaning "empty this slot",
/// distinct from any real player id (which are always non-null strings).
const clearSlotSentinel = Object();

/// A bottom sheet listing a team's players, filterable by position, for
/// assigning one to a formation slot — used by both the Line-Up tab and the
/// live-match screen (tapping a slot there opens this same picker to set
/// the starting lineup, reassign pre-kickoff, or substitute mid-match).
///
/// Pops with a player id (`String`) on selection, [clearSlotSentinel] if
/// "Clear this slot" was tapped, or `null` if dismissed without a choice.
class PlayerPickerSheet extends StatefulWidget {
  const PlayerPickerSheet({
    super.key,
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
  State<PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<PlayerPickerSheet> {
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
                    onTap: () => Navigator.pop(context, clearSlotSentinel),
                  ),
                for (final player in sorted)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(player.number?.toString() ?? player.initials),
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
