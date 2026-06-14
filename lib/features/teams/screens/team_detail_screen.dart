import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/player.dart';
import '../providers/team_provider.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailProvider(teamId));

    return detailAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (detail) => Scaffold(
        appBar: AppBar(
          title: Text(detail.team.name),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  detail.team.sportFormatLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              context.push('/teams/$teamId/players/new'),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add player'),
        ),
        body: detail.players.isEmpty
            ? const _EmptyRoster()
            : _PlayerList(players: detail.players, teamId: teamId),
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text('No players yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Tap "Add player" to build your roster'),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.players, required this.teamId});

  final List<Player> players;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96, top: 8),
      itemCount: players.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final player = players[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              player.number != null ? '${player.number}' : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Text(player.name),
          subtitle: Row(
            children: [
              if (player.alias != null && player.alias!.isNotEmpty)
                Text('"${player.alias}"  '),
              if (player.position != null)
                Text(
                  player.position!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.push('/teams/$teamId/players/${player.id}'),
        );
      },
    );
  }
}
