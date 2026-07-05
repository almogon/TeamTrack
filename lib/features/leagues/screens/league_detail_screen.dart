import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_standing.dart';
import '../providers/league_standings_provider.dart';
import '../providers/leagues_provider.dart';

class LeagueDetailScreen extends ConsumerWidget {
  const LeagueDetailScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagueAsync = ref.watch(leagueDetailProvider(leagueId));
    final standingsAsync = ref.watch(leagueStandingsProvider(leagueId));

    return Scaffold(
      appBar: AppBar(
        title: Text(leagueAsync.value?.name ?? 'League'),
      ),
      body: leagueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (league) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${league.city} · ${league.zipCode} · Season ${league.season}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Standings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: standingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (standings) {
                  if (standings.isEmpty) {
                    return const Center(child: Text('No teams have joined yet'));
                  }
                  return _StandingsTable(standings: standings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.standings});

  final List<LeagueStanding> standings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Team')),
          DataColumn(label: Text('P'), numeric: true),
          DataColumn(label: Text('W'), numeric: true),
          DataColumn(label: Text('D'), numeric: true),
          DataColumn(label: Text('L'), numeric: true),
          DataColumn(label: Text('GD'), numeric: true),
          DataColumn(label: Text('Pts'), numeric: true),
        ],
        rows: [
          for (var i = 0; i < standings.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}. ${standings[i].teamName}')),
              DataCell(Text('${standings[i].played}')),
              DataCell(Text('${standings[i].wins}')),
              DataCell(Text('${standings[i].draws}')),
              DataCell(Text('${standings[i].losses}')),
              DataCell(Text('${standings[i].goalDifference}')),
              DataCell(Text(
                '${standings[i].points}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
            ]),
        ],
      ),
    );
  }
}
