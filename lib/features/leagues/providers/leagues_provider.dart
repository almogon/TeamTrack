import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/league.dart';

/// Active leagues, optionally filtered by a city/zip search query.
final activeLeaguesProvider =
    FutureProvider.family<List<League>, String>((ref, query) async {
  final trimmed = query.trim();
  final data = trimmed.isEmpty
      ? await Supabase.instance.client
          .from('leagues')
          .select()
          .eq('status', 'active')
          .order('name')
      : await Supabase.instance.client
          .from('leagues')
          .select()
          .eq('status', 'active')
          .or('city.ilike.%$trimmed%,zip_code.ilike.%$trimmed%')
          .order('name');
  return (data as List<dynamic>)
      .map((e) => League.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// The league a team currently belongs to, if any.
final teamLeagueProvider =
    FutureProvider.family<League?, String>((ref, teamId) async {
  final data = await Supabase.instance.client
      .from('league_teams')
      .select('leagues(*)')
      .eq('team_id', teamId)
      .maybeSingle();
  final leagueJson = data?['leagues'] as Map<String, dynamic>?;
  if (leagueJson == null) return null;
  return League.fromJson(leagueJson);
});

final leagueDetailProvider =
    FutureProvider.family<League, String>((ref, leagueId) async {
  final data = await Supabase.instance.client
      .from('leagues')
      .select()
      .eq('id', leagueId)
      .single();
  return League.fromJson(data);
});

/// Leagues awaiting admin/manager approval. RLS returns an empty list for
/// anyone who isn't admin/manager, rather than an error.
final pendingLeaguesProvider = FutureProvider<List<League>>((ref) async {
  final data = await Supabase.instance.client
      .from('leagues')
      .select()
      .eq('status', 'pending')
      .order('created_at');
  return (data as List<dynamic>)
      .map((e) => League.fromJson(e as Map<String, dynamic>))
      .toList();
});
