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
  final team = Team.fromJson(data);
  final players = ((data['players'] as List<dynamic>?) ?? [])
      .map((p) => Player.fromJson(p as Map<String, dynamic>))
      .where((p) => p.active)
      .toList();
  return (team: team, players: players);
});

/// Every player on a team, including archived (`active: false`) ones —
/// unlike [teamDetailProvider]'s roster, which only ever returns active
/// players. Used where a removed player's name still needs to resolve for
/// historical data (e.g. a finished match's summary), rather than showing
/// "Unknown".
final teamAllPlayersProvider =
    FutureProvider.family<List<Player>, String>((ref, teamId) async {
  final data = await Supabase.instance.client
      .from('players')
      .select()
      .eq('team_id', teamId)
      .order('name');
  return (data as List<dynamic>)
      .map((e) => Player.fromJson(e as Map<String, dynamic>))
      .toList();
});
