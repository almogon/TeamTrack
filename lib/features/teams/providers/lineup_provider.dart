import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player.dart';

typedef TeamLineup = ({String? formation, Map<int, Player> slots});

final teamLineupProvider =
    FutureProvider.family<TeamLineup, String>((ref, teamId) async {
  final teamData = await Supabase.instance.client
      .from('teams')
      .select('lineup_formation')
      .eq('id', teamId)
      .single();
  final formation = teamData['lineup_formation'] as String?;

  final slotsData = await Supabase.instance.client
      .from('lineup_slots')
      .select('slot_index, players(*)')
      .eq('team_id', teamId);

  final slots = <int, Player>{};
  for (final row in slotsData as List<dynamic>) {
    final playerJson =
        (row as Map<String, dynamic>)['players'] as Map<String, dynamic>?;
    if (playerJson != null) {
      slots[row['slot_index'] as int] = Player.fromJson(playerJson);
    }
  }
  return (formation: formation, slots: slots);
});
