import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/league.dart';
import '../providers/leagues_provider.dart';

class DiscoverLeaguesScreen extends ConsumerStatefulWidget {
  const DiscoverLeaguesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<DiscoverLeaguesScreen> createState() =>
      _DiscoverLeaguesScreenState();
}

class _DiscoverLeaguesScreenState extends ConsumerState<DiscoverLeaguesScreen> {
  String _query = '';
  bool _joining = false;

  Future<void> _confirmAndJoin(League league) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join this league?'),
        content: Text(
          'Once your team joins "${league.name}", it cannot leave. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _join(league);
  }

  Future<void> _join(League league) async {
    setState(() => _joining = true);
    try {
      await Supabase.instance.client.from('league_teams').insert({
        'league_id': league.id,
        'team_id': widget.teamId,
      });
      ref.invalidate(teamLeagueProvider(widget.teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${league.name}')),
        );
        context.pop();
      }
    } on PostgrestException catch (e) {
      final message = e.code == '23505'
          ? 'Your team is already in a league.'
          : e.message;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaguesAsync = ref.watch(activeLeaguesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover leagues'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by city or zip code',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (leagues) {
          if (leagues.isEmpty) {
            return const Center(child: Text('No leagues found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: leagues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final league = leagues[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(league.name),
                  subtitle: Text(
                    '${league.city} · ${league.zipCode} · ${league.season}',
                  ),
                  trailing: FilledButton(
                    onPressed: _joining ? null : () => _confirmAndJoin(league),
                    child: const Text('Join'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
