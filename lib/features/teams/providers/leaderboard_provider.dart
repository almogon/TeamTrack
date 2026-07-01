import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../players/models/player_score.dart';

/// Ranked list of players by total points for a team,
/// read from the `player_season_scores` DB view.
final teamLeaderboardProvider =
    FutureProvider.family<List<PlayerScore>, String>((ref, teamId) async {
  final data = await Supabase.instance.client
      .from('player_season_scores')
      .select()
      .eq('team_id', teamId)
      .order('total_points', ascending: false);
  return (data as List<dynamic>)
      .map((e) => PlayerScore.fromJson(e as Map<String, dynamic>))
      .toList();
});
