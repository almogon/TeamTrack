import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';

class MatchListNotifier extends FamilyAsyncNotifier<List<Match>, String> {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  Future<List<Match>> build(String teamId) => _fetch(teamId);

  Future<List<Match>> _fetch(String teamId) async {
    final data = await Supabase.instance.client
        .from('matches')
        .select()
        .eq('team_id', teamId)
        .order('match_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => Match.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Match> createMatch({
    required String teamId,
    required DateTime matchDate,
    required String opponent,
    required String homeAway,
    String? competition,
  }) async {
    final data = await Supabase.instance.client
        .from('matches')
        .insert({
          'team_id': teamId,
          'match_date': _dateFmt.format(matchDate),
          'opponent': opponent.trim(),
          'home_away': homeAway,
          if (competition != null && competition.trim().isNotEmpty)
            'competition': competition.trim(),
          'status': 'scheduled',
        })
        .select()
        .single();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(teamId));
    return Match.fromJson(data);
  }
}

final matchListProvider =
    AsyncNotifierProvider.family<MatchListNotifier, List<Match>, String>(
  MatchListNotifier.new,
);
