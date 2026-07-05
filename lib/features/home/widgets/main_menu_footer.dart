import 'package:flutter/material.dart';

/// Oval bottom bar with the main menu's 3 quick actions: scores (left),
/// start a match (middle, emphasized), edit roster (right).
class MainMenuFooter extends StatelessWidget {
  const MainMenuFooter({
    super.key,
    required this.onScores,
    required this.onStartMatch,
    required this.onEditRoster,
  });

  final VoidCallback onScores;
  final VoidCallback onStartMatch;
  final VoidCallback onEditRoster;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: const StadiumBorder(),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.leaderboard_outlined),
                tooltip: 'Scores',
                onPressed: onScores,
              ),
              FilledButton(
                onPressed: onStartMatch,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.sports_soccer),
              ),
              IconButton(
                icon: const Icon(Icons.groups_outlined),
                tooltip: 'Edit roster',
                onPressed: onEditRoster,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
