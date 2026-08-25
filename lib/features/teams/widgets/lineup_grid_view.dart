import 'package:flutter/material.dart';

import '../../../shared/widgets/player_diamond.dart';
import '../models/lineup_formation.dart';
import '../models/player.dart';
import '../models/sport_type.dart';
import '../models/team.dart';
import 'football_pitch_background.dart';

/// Renders a formation's slots as rows of diamonds (filled or placeholder),
/// grouped and ordered attack-line-first / defensive-line-last (see
/// [SportType.formationOrder]) — the shared visual between the read-only
/// main menu and the editable Line-Up tab, so both show the exact same
/// disposition.
class LineupGridView extends StatelessWidget {
  const LineupGridView({
    super.key,
    required this.team,
    required this.formation,
    required this.slots,
    required this.onSlotTap,
    this.onSlotDrop,
  });

  final Team team;
  final LineupFormation formation;
  final Map<int, Player> slots;
  final ValueChanged<int> onSlotTap;

  /// Called when a bench player is dropped onto a slot. Left `null` (e.g. on
  /// the read-only main menu) to disable drag-and-drop for this grid.
  final void Function(int slotIndex, Player player)? onSlotDrop;

  @override
  Widget build(BuildContext context) {
    final byRole = <String, List<int>>{};
    for (var i = 0; i < formation.slots.length; i++) {
      byRole.putIfAbsent(formation.slots[i], () => []).add(i);
    }
    final rows = <List<int>>[
      for (final position in team.sportType.formationOrder)
        if (byRole[position.code]?.isNotEmpty ?? false) byRole[position.code]!,
    ];

    final grid = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 32,
              runSpacing: 32,
              children: [
                for (final slotIndex in row)
                  _SlotDiamond(
                    player: slots[slotIndex],
                    onTap: () => onSlotTap(slotIndex),
                    onDrop: onSlotDrop == null
                        ? null
                        : (player) => onSlotDrop!(slotIndex, player),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );

    // Football only for now — the pitch SVG is stretched with BoxFit.fill
    // to exactly match the grid's own bounding box (Positioned.fill inside
    // this Stack), so the goal line always lines up under the GK row and
    // the halfway line always sits above the forward line, regardless of
    // how many rows the formation has.
    if (team.sportType != SportType.football) return grid;
    return Stack(
      children: [
        const Positioned.fill(child: FootballPitchBackground()),
        grid,
      ],
    );
  }
}

class _SlotDiamond extends StatelessWidget {
  const _SlotDiamond({required this.player, required this.onTap, this.onDrop});

  final Player? player;
  final VoidCallback onTap;
  final ValueChanged<Player>? onDrop;

  @override
  Widget build(BuildContext context) {
    final diamond = player != null
        ? PlayerDiamond(player: player!, onTap: onTap)
        : _placeholder(context);

    if (onDrop == null) return diamond;

    return DragTarget<Player>(
      onAcceptWithDetails: (details) => onDrop!(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isHovering
                ? Theme.of(context).colorScheme.primary.withAlpha(40)
                : null,
          ),
          child: diamond,
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Transform.rotate(
        angle: 0.7853981633974483, // pi / 4
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Transform.rotate(
              angle: -0.7853981633974483,
              child: Icon(Icons.add, size: 20, color: cs.outlineVariant),
            ),
          ),
        ),
      ),
    );
  }
}
