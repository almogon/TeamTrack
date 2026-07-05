import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../teams/models/player.dart';
import '../../teams/models/team.dart';

/// Renders a team's active players as rows grouped by position, ordered
/// attack-line-first / defensive-line-last (see [SportType.formationOrder]).
/// This mirrors the shape of a tactical formation without pinning players to
/// fixed pitch coordinates.
class FormationView extends StatelessWidget {
  const FormationView({
    super.key,
    required this.team,
    required this.players,
    required this.onPlayerTap,
  });

  final Team team;
  final List<Player> players;
  final ValueChanged<Player> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final byPosition = <String, List<Player>>{};
    final unassigned = <Player>[];
    for (final player in players) {
      final position = player.position;
      if (position == null || position.isEmpty) {
        unassigned.add(player);
      } else {
        byPosition.putIfAbsent(position, () => []).add(player);
      }
    }

    final rows = <List<Player>>[
      for (final position in team.sportType.formationOrder)
        if (byPosition[position.code]?.isNotEmpty ?? false)
          byPosition[position.code]!,
      if (unassigned.isNotEmpty) unassigned,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows) ...[
            _FormationRow(players: row, onPlayerTap: onPlayerTap),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }
}

class _FormationRow extends StatelessWidget {
  const _FormationRow({required this.players, required this.onPlayerTap});

  final List<Player> players;
  final ValueChanged<Player> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final player in players)
          PlayerDiamond(player: player, onTap: () => onPlayerTap(player)),
      ],
    );
  }
}

/// A tappable rotated-square "diamond" token showing a player's shirt number.
class PlayerDiamond extends StatelessWidget {
  const PlayerDiamond({super.key, required this.player, required this.onTap});

  final Player player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            border: Border.all(color: cs.primary, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Text(
                player.number != null
                    ? '${player.number}'
                    : player.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
