import 'package:flutter/material.dart';

import '../../features/teams/models/player.dart';
import 'player_diamond.dart';

/// Wide-layout bench: a vertically scrollable list (sized by whatever
/// `Expanded`/width the caller gives it), names ellipsized so a long name
/// never forces the panel wider. Each row is draggable — dropping it on a
/// [LineupGridView] slot assigns/substitutes that player there.
///
/// Shared between the team's Line-Up tab and the live-match screen, so both
/// present the same bench UI and drag behavior.
class BenchPanel extends StatelessWidget {
  const BenchPanel({super.key, required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bench (${players.length})',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: players.isEmpty
              ? const Text('Everyone is on the pitch')
              : ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, i) {
                    final player = players[i];
                    return Draggable<Player>(
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
                    );
                  },
                ),
        ),
      ],
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
        child: Text(player.number?.toString() ?? player.initials),
      ),
      title: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: player.position != null
          ? Text(player.position!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
    );
  }
}

/// Compact-layout bench: a horizontal scroll of number-only avatars —
/// there's no room for names next to the pitch on a phone screen.
class BenchHorizontalList extends StatelessWidget {
  const BenchHorizontalList({super.key, required this.players});

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
            SizedBox(
              height: 64,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: players.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final player = players[i];
                    return Draggable<Player>(
                      data: player,
                      feedback: Material(
                        color: Colors.transparent,
                        child: PlayerDiamond(player: player, onTap: () {}),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _BenchNumberAvatar(player: player),
                      ),
                      child: _BenchNumberAvatar(player: player),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BenchNumberAvatar extends StatelessWidget {
  const _BenchNumberAvatar({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 24,
      backgroundColor: cs.secondaryContainer,
      child: Text(
        player.number?.toString() ?? player.initials,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
