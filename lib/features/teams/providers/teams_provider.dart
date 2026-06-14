import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team.dart';

class TeamsNotifier extends AsyncNotifier<List<Team>> {
  @override
  Future<List<Team>> build() => _fetch();

  Future<List<Team>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final data = await Supabase.instance.client
        .from('teams')
        .select()
        .eq('owner_id', user.id)
        .order('name');
    return (data as List<dynamic>)
        .map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTeam({
    required String name,
    required String sport,
    required String format,
    required int minPlayers,
    required int maxPlayers,
    String? season,
  }) async {
    final user = Supabase.instance.client.auth.currentUser!;
    await Supabase.instance.client.from('teams').insert({
      'owner_id': user.id,
      'name': name.trim(),
      'sport': sport,
      'format': format,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      if (season != null && season.trim().isNotEmpty) 'season': season.trim(),
    });
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final teamsProvider =
    AsyncNotifierProvider<TeamsNotifier, List<Team>>(TeamsNotifier.new);
