import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../matches/models/match.dart';
import '../../matches/providers/stat_rules_provider.dart';
import '../../teams/providers/team_provider.dart';
import '../models/player_score.dart';

/// Career totals for a single player on a specific team,
/// read from the `player_season_scores` DB view.
final playerCareerProvider =
    FutureProvider.family<PlayerScore?, PlayerKey>((ref, args) async {
  final data = await Supabase.instance.client
      .from('player_season_scores')
      .select()
      .eq('player_id', args.playerId)
      .eq('team_id', args.teamId)
      .maybeSingle();
  if (data == null) return null;
  return PlayerScore.fromJson(data);
});

/// Per-match stat breakdown for a player across all finished matches.
/// Returned list is sorted by match date descending (most recent first).
final playerMatchHistoryProvider =
    FutureProvider.family<List<PlayerMatchEntry>, PlayerKey>((ref, args) async {
  final teamDetail =
      await ref.watch(teamDetailProvider(args.teamId).future);
  final sport = teamDetail.team.sport;
  final rules = await ref.watch(statRulesProvider(sport).future);

  // Step 1: all stat events for this player
  final eventsData = await Supabase.instance.client
      .from('stat_events')
      .select('stat_type, value, match_id')
      .eq('player_id', args.playerId);

  final rows = eventsData as List<dynamic>;
  if (rows.isEmpty) return [];

  // Step 2: fetch the corresponding matches (finished only)
  final matchIds =
      rows.map((r) => (r as Map<String, dynamic>)['match_id'] as String).toSet().toList();

  final matchesData = await Supabase.instance.client
      .from('matches')
      .select()
      .inFilter('id', matchIds)
      .eq('status', 'finished')
      .order('match_date', ascending: false);

  final matches = (matchesData as List<dynamic>)
      .map((e) => Match.fromJson(e as Map<String, dynamic>))
      .toList();

  final finishedIds = {for (final m in matches) m.id};

  // Step 3: group stat counts by match
  final Map<String, Map<String, int>> statCountsById = {};
  for (final row in rows) {
    final r = row as Map<String, dynamic>;
    final matchId = r['match_id'] as String;
    if (!finishedIds.contains(matchId)) continue;
    final statType = r['stat_type'] as String;
    final value = r['value'] as int;
    final counts = statCountsById.putIfAbsent(matchId, () => {});
    counts[statType] = (counts[statType] ?? 0) + value;
  }

  // Step 4: build entries for matches where the player appeared
  return matches
      .where((m) => statCountsById.containsKey(m.id))
      .map((match) {
        final counts = statCountsById[match.id]!;
        int points = 0;
        for (final rule in rules) {
          points += (counts[rule.statType] ?? 0) * rule.points;
        }
        return PlayerMatchEntry(match: match, statCounts: counts, points: points);
      })
      .toList();
});
