import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/league_standing.dart';

/// Ranked standings for a league, read via the `league_standings` RPC (a
/// SECURITY DEFINER function — see the v6_leagues migration for why this
/// isn't a plain RLS-backed view: standings need to aggregate match results
/// across every member team, not just ones the caller owns).
final leagueStandingsProvider =
    FutureProvider.family<List<LeagueStanding>, String>((ref, leagueId) async {
  final data = await Supabase.instance.client
      .rpc('league_standings', params: {'p_league_id': leagueId});
  return (data as List<dynamic>)
      .map((e) => LeagueStanding.fromJson(e as Map<String, dynamic>))
      .toList();
});
