import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player.dart';
import '../models/team.dart';

typedef TeamWithPlayers = ({Team team, List<Player> players});

final teamDetailProvider =
    FutureProvider.family<TeamWithPlayers, String>((ref, teamId) async {
  final data = await Supabase.instance.client
      .from('teams')
      .select('*, players(*)')
      .eq('id', teamId)
      .single();
  final team = Team.fromJson(data as Map<String, dynamic>);
  final players = ((data['players'] as List<dynamic>?) ?? [])
      .map((p) => Player.fromJson(p as Map<String, dynamic>))
      .where((p) => p.active)
      .toList();
  return (team: team, players: players);
});
