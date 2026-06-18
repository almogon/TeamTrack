import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';
import '../models/stat_event.dart';
import '../services/match_notification_service.dart';

class LiveMatchState {
  const LiveMatchState({
    this.match,
    required this.sport,
    required this.format,
    required this.matchStatus,
    required this.events,
    required this.elapsedSeconds,
    required this.isRunning,
  });

  final Match? match;
  final String sport;
  final String format;
  final String matchStatus;
  final List<StatEvent> events;
  final int elapsedSeconds;
  final bool isRunning;

  bool get isInitialized => match != null;

  String get timerDisplay {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get currentMinute => elapsedSeconds ~/ 60;

  String get periodLabel {
    if (sport == 'basketball') {
      final q = (elapsedSeconds ~/ (10 * 60) + 1).clamp(1, 4);
      return 'Q$q';
    }
    if (sport == 'volleyball') return 'Set 1';
    final halftime = (format == '11' ? 45 : 25) * 60;
    return elapsedSeconds < halftime ? '1st Half' : '2nd Half';
  }

  int get scoreFor {
    final type = sport == 'basketball' ? 'point' : 'goal';
    if (sport == 'volleyball') return 0;
    return events
        .where((e) => e.statType == type)
        .fold(0, (sum, e) => sum + e.value);
  }

  LiveMatchState copyWith({
    Match? match,
    String? sport,
    String? format,
    String? matchStatus,
    List<StatEvent>? events,
    int? elapsedSeconds,
    bool? isRunning,
  }) =>
      LiveMatchState(
        match: match ?? this.match,
        sport: sport ?? this.sport,
        format: format ?? this.format,
        matchStatus: matchStatus ?? this.matchStatus,
        events: events ?? this.events,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        isRunning: isRunning ?? this.isRunning,
      );
}

class LiveMatchNotifier extends FamilyNotifier<LiveMatchState, String> {
  Timer? _timer;

  @override
  LiveMatchState build(String matchId) {
    ref.onDispose(() => _timer?.cancel());
    return const LiveMatchState(
      sport: 'football',
      format: '11',
      matchStatus: 'scheduled',
      events: [],
      elapsedSeconds: 0,
      isRunning: false,
    );
  }

  void initialize(Match match, {required String sport, required String format}) {
    state = state.copyWith(
      match: match,
      sport: sport,
      format: format,
      matchStatus: match.status,
    );
  }

  Future<void> start() async {
    await Supabase.instance.client.from('matches').update({
      'status': 'live',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', state.match!.id);
    state = state.copyWith(matchStatus: 'live', isRunning: true);
    _startTimer();
  }

  Future<void> pause() async {
    _timer?.cancel();
    await Supabase.instance.client.from('matches').update({
      'status': 'paused',
      'paused_at': DateTime.now().toIso8601String(),
    }).eq('id', state.match!.id);
    state = state.copyWith(matchStatus: 'paused', isRunning: false);
  }

  Future<void> resume() async {
    await Supabase.instance.client.from('matches').update({
      'status': 'live',
      'paused_at': null,
    }).eq('id', state.match!.id);
    state = state.copyWith(matchStatus: 'live', isRunning: true);
    _startTimer();
  }

  Future<void> endMatch() async {
    _timer?.cancel();
    final matchId = state.match!.id;
    await Supabase.instance.client.from('matches').update({
      'status': 'finished',
      'finished_at': DateTime.now().toIso8601String(),
    }).eq('id', matchId);
    await Supabase.instance.client
        .rpc('rebuild_match_player_stats', params: {'p_match_id': matchId});
    state = state.copyWith(matchStatus: 'finished', isRunning: false);
  }

  Future<void> recordStat(String playerId, String statType, {int value = 1}) async {
    final data = await Supabase.instance.client.from('stat_events').insert({
      'match_id': state.match!.id,
      'player_id': playerId,
      'stat_type': statType,
      'minute': state.currentMinute,
      'value': value,
    }).select().single();
    final event = StatEvent.fromJson(data);
    state = state.copyWith(events: [...state.events, event]);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: next);
      _checkBreakPoint(next);
    });
  }

  void _checkBreakPoint(int seconds) {
    final opponent = state.match?.opponent ?? '';
    if (state.sport == 'football') {
      final half = (state.format == '11' ? 45 : 25) * 60;
      if (seconds == half) {
        MatchNotificationService.showHalftimeAlert(opponent);
      } else if (seconds == half * 2) {
        MatchNotificationService.showMatchEnd(opponent);
      }
    } else if (state.sport == 'basketball') {
      const quarterSeconds = 10 * 60;
      for (var q = 1; q <= 3; q++) {
        if (seconds == quarterSeconds * q) {
          MatchNotificationService.showQuarterBreak(opponent, q);
          return;
        }
      }
      if (seconds == 4 * quarterSeconds) {
        MatchNotificationService.showMatchEnd(opponent);
      }
    }
  }
}

final liveMatchProvider =
    NotifierProvider.family<LiveMatchNotifier, LiveMatchState, String>(
  LiveMatchNotifier.new,
);
