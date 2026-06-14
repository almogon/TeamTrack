import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/models/player.dart';
import '../../teams/providers/team_provider.dart';

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
          Row(
            children: [
              Icon(Icons.bar_chart_outlined, color: cs.outline),
              const SizedBox(width: 8),
              Text('Stats', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Stats will be available once match recording is enabled.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
