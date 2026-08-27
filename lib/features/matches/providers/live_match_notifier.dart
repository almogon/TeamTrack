import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/models/lineup_formation.dart';
import '../../teams/models/player.dart';
import '../../teams/models/sport_type.dart';
import '../../teams/providers/leaderboard_provider.dart';
import '../../teams/providers/lineup_provider.dart';
import '../models/match.dart';
import '../models/stat_event.dart';
import '../services/match_notification_service.dart';
import 'match_list_provider.dart';
import 'match_lineup_provider.dart';

class LiveMatchState {
  const LiveMatchState({
    this.match,
    required this.sport,
    required this.format,
    required this.matchStatus,
    required this.events,
    required this.elapsedSeconds,
    required this.isRunning,
    this.formation,
    this.slots = const {},
  });

  final Match? match;
  final String sport;
  final String format;
  final String matchStatus;
  final List<StatEvent> events;
  final int elapsedSeconds;
  final bool isRunning;

  /// This match's own starting/current lineup — independent of the team's
  /// persistent Line-Up (see [matchLineupProvider]).
  final LineupFormation? formation;
  final Map<int, Player> slots;

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
    LineupFormation? formation,
    Map<int, Player>? slots,
  }) =>
      LiveMatchState(
        match: match ?? this.match,
        sport: sport ?? this.sport,
        format: format ?? this.format,
        matchStatus: matchStatus ?? this.matchStatus,
        events: events ?? this.events,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        isRunning: isRunning ?? this.isRunning,
        formation: formation ?? this.formation,
        slots: slots ?? this.slots,
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

  Future<void> initialize(Match match, {required String sport, required String format}) async {
    final formations = LineupFormation.forTeam(SportType.fromValue(sport), format);

    // This match's own lineup takes priority (it already started, or a
    // starting XI was set up for it earlier) — only fall back to the
    // team's current saved Line-Up as a sensible default for a fresh match
    // nobody has touched yet.
    var lineup = await ref.read(matchLineupProvider(match.id).future);
    if (lineup.slots.isEmpty && lineup.formation == null) {
      lineup = await ref.read(teamLineupProvider(match.teamId).future);
    }
    final formation = formations.firstWhere(
      (f) => f.key == lineup.formation,
      orElse: () => formations.first,
    );

    state = state.copyWith(
      match: match,
      sport: sport,
      format: format,
      matchStatus: match.status,
      formation: formation,
      slots: lineup.slots,
    );
  }

  /// Changes the formation, remapping current slot assignments onto it (same
  /// smart-remap rule as the team's Line-Up tab) rather than resetting them.
  void setFormation(LineupFormation formation, {required List<String> roleOrder}) {
    final remapped = LineupFormation.remapAssignments(
      from: state.formation!,
      to: formation,
      oldAssignments: state.slots,
      roleOrder: roleOrder,
    );
    state = state.copyWith(formation: formation);
    _applySlotsChange(remapped);
  }

  void assignSlot(int slotIndex, Player player) {
    final newSlots = Map<int, Player>.from(state.slots)
      ..removeWhere((_, p) => p.id == player.id) // a player only ever occupies one slot
      ..[slotIndex] = player;
    _applySlotsChange(newSlots);
  }

  void clearSlot(int slotIndex) {
    final newSlots = Map<int, Player>.from(state.slots)..remove(slotIndex);
    _applySlotsChange(newSlots);
  }

  /// Serializes the DB writes below — every drag/tap during a live match
  /// writes immediately (there's no batched "Save" here, unlike the Line-Up
  /// tab), so two substitutions made in quick succession could otherwise
  /// interleave their delete-then-insert of `match_lineup_slots` and lose
  /// one of them.
  Future<void> _writeQueue = Future.value();

  /// Applies a new slot assignment (formation change, tap-to-assign, or a
  /// bench-to-pitch drag): updates local state immediately for a responsive
  /// UI, then persists it and — once the match has actually kicked off —
  /// records the substitution: whoever left the pitch gets their open stint
  /// closed off, whoever's newly on it gets a new one opened, both at the
  /// current match minute. A player who just moved slots (still present in
  /// both the old and new lineup) isn't a substitution, so gets neither.
  void _applySlotsChange(Map<int, Player> newSlots) {
    final oldSlots = state.slots;
    final formationKey = state.formation!.key;
    final matchStatus = state.matchStatus;
    final minute = state.currentMinute;
    final matchId = state.match!.id;
    state = state.copyWith(slots: newSlots);

    _writeQueue = _writeQueue.then((_) => _persistSlotsChange(
          matchId: matchId,
          formationKey: formationKey,
          oldSlots: oldSlots,
          newSlots: newSlots,
          matchStatus: matchStatus,
          minute: minute,
        ));
  }

  Future<void> _persistSlotsChange({
    required String matchId,
    required String formationKey,
    required Map<int, Player> oldSlots,
    required Map<int, Player> newSlots,
    required String matchStatus,
    required int minute,
  }) async {
    await Supabase.instance.client
        .from('matches')
        .update({'lineup_formation': formationKey}).eq('id', matchId);
    await Supabase.instance.client
        .from('match_lineup_slots')
        .delete()
        .eq('match_id', matchId);
    if (newSlots.isNotEmpty) {
      await Supabase.instance.client.from('match_lineup_slots').insert([
        for (final entry in newSlots.entries)
          {
            'match_id': matchId,
            'slot_index': entry.key,
            'player_id': entry.value.id,
          },
      ]);
    }

    // Before kickoff this is just pre-match lineup editing — nobody's
    // "playing" yet, so there's nothing to open/close a stint for.
    if (matchStatus == 'scheduled') return;

    final oldIds = oldSlots.values.map((p) => p.id).toSet();
    final newIds = newSlots.values.map((p) => p.id).toSet();
    final subbedOut = oldIds.difference(newIds);
    final subbedIn = newIds.difference(oldIds);
    if (subbedOut.isEmpty && subbedIn.isEmpty) return;

    if (subbedOut.isNotEmpty) {
      await Supabase.instance.client
          .from('match_substitutions')
          .update({'minute_out': minute})
          .eq('match_id', matchId)
          .inFilter('player_id', subbedOut.toList())
          .isFilter('minute_out', null);
    }
    if (subbedIn.isNotEmpty) {
      await Supabase.instance.client.from('match_substitutions').insert([
        for (final playerId in subbedIn)
          {'match_id': matchId, 'player_id': playerId, 'minute_in': minute},
      ]);
    }
  }

  Future<void> start() async {
    final matchId = state.match!.id;
    // Make sure this match's lineup is actually persisted before kickoff —
    // if the trainer never touched it, state.slots only ever came from the
    // team's current Line-Up as a fallback default (see initialize()) and
    // was never written for this match specifically. Reusing
    // _applySlotsChange (old == new slots, status still 'scheduled' at
    // this point) persists it without any spurious substitution bookkeeping.
    _applySlotsChange(state.slots);
    await _writeQueue;

    await Supabase.instance.client.from('matches').update({
      'status': 'live',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', matchId);
    // Kickoff: open a stint for everyone currently in the starting lineup.
    if (state.slots.isNotEmpty) {
      await Supabase.instance.client.from('match_substitutions').insert([
        for (final player in state.slots.values)
          {'match_id': matchId, 'player_id': player.id, 'minute_in': 0},
      ]);
    }
    state = state.copyWith(matchStatus: 'live', isRunning: true);
    ref.invalidate(matchListProvider(state.match!.teamId));
    _startTimer();
  }

  Future<void> pause() async {
    _timer?.cancel();
    await Supabase.instance.client.from('matches').update({
      'status': 'paused',
      'paused_at': DateTime.now().toIso8601String(),
    }).eq('id', state.match!.id);
    state = state.copyWith(matchStatus: 'paused', isRunning: false);
    ref.invalidate(matchListProvider(state.match!.teamId));
  }

  Future<void> resume() async {
    await Supabase.instance.client.from('matches').update({
      'status': 'live',
      'paused_at': null,
    }).eq('id', state.match!.id);
    state = state.copyWith(matchStatus: 'live', isRunning: true);
    ref.invalidate(matchListProvider(state.match!.teamId));
    _startTimer();
  }

  Future<void> endMatch() async {
    _timer?.cancel();
    final matchId = state.match!.id;
    final teamId = state.match!.teamId;
    await Supabase.instance.client.from('matches').update({
      'status': 'finished',
      'finished_at': DateTime.now().toIso8601String(),
    }).eq('id', matchId);
    // Close out anyone still on the pitch so their playing time is complete.
    await Supabase.instance.client
        .from('match_substitutions')
        .update({'minute_out': state.currentMinute})
        .eq('match_id', matchId)
        .isFilter('minute_out', null);
    await Supabase.instance.client
        .rpc('rebuild_match_player_stats', params: {'p_match_id': matchId});
    state = state.copyWith(matchStatus: 'finished', isRunning: false);
    // The DB is correct the instant the calls above return, but the
    // Matches list and Leaderboard each hold their own cached provider
    // state — without this, they keep showing the pre-finish match
    // (wrong "Start" action instead of "Summary") and pre-finish points
    // until something unrelated happens to refetch them.
    ref.invalidate(matchListProvider(teamId));
    ref.invalidate(teamLeaderboardProvider(teamId));
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
    final opponent = state.match?.opponentName ?? '';
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
