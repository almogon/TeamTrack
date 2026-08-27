import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/models/player.dart';
import '../../teams/providers/lineup_provider.dart';

/// A match's own starting/current lineup — same shape as [TeamLineup], just
/// keyed by match instead of team. Independent of the team's persistent
/// Line-Up: substitutions during a match write here, never to `lineup_slots`.
final matchLineupProvider =
    FutureProvider.family<TeamLineup, String>((ref, matchId) async {
  final matchData = await Supabase.instance.client
      .from('matches')
      .select('lineup_formation')
      .eq('id', matchId)
      .single();
  final formation = matchData['lineup_formation'] as String?;
  final slotsData = await Supabase.instance.client
      .from('match_lineup_slots')
      .select('slot_index, players(*)')
      .eq('match_id', matchId);
  final slots = <int, Player>{};
  for (final row in slotsData as List<dynamic>) {
    final playerJson = (row as Map<String, dynamic>)['players'] as Map<String, dynamic>?;
    if (playerJson != null) slots[row['slot_index'] as int] = Player.fromJson(playerJson);
  }
  return (formation: formation, slots: slots);
});
