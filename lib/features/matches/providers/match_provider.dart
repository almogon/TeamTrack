import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';
import '../models/match_player_stat.dart';
import '../models/stat_event.dart';

final matchProvider = FutureProvider.family<Match, String>((ref, matchId) async {
  final data = await Supabase.instance.client
      .from('matches')
      .select()
      .eq('id', matchId)
      .single();
  return Match.fromJson(data);
});

final matchStatsProvider =
    FutureProvider.family<List<MatchPlayerStat>, String>((ref, matchId) async {
  final data = await Supabase.instance.client
      .from('match_player_stats')
      .select()
      .eq('match_id', matchId);
  return (data as List<dynamic>)
      .map((e) => MatchPlayerStat.fromJson(e as Map<String, dynamic>))
      .toList();
});

// Used by the summary screen — sport-agnostic, works for all sports.
final matchEventsProvider =
    FutureProvider.family<List<StatEvent>, String>((ref, matchId) async {
  final data = await Supabase.instance.client
      .from('stat_events')
      .select()
      .eq('match_id', matchId)
      .order('minute', ascending: true);
  return (data as List<dynamic>)
      .map((e) => StatEvent.fromJson(e as Map<String, dynamic>))
      .toList();
});
