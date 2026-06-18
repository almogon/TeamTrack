import 'stat_rule.dart';

class MatchPlayerStat {
  const MatchPlayerStat({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.minutes,
    required this.goals,
    required this.assists,
    required this.yellow,
    required this.red,
    required this.shots,
    required this.saves,
  });

  final String id;
  final String matchId;
  final String playerId;
  final int minutes;
  final int goals;
  final int assists;
  final int yellow;
  final int red;
  final int shots;
  final int saves;

  int computePoints(List<StatRule> rules) {
    int total = 0;
    for (final rule in rules) {
      final count = switch (rule.statType) {
        'goal' => goals,
        'assist' => assists,
        'yellow' => yellow,
        'red' => red,
        'shot' => shots,
        'save' => saves,
        _ => 0,
      };
      total += count * rule.points;
    }
    return total;
  }

  factory MatchPlayerStat.fromJson(Map<String, dynamic> json) => MatchPlayerStat(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        playerId: json['player_id'] as String,
        minutes: json['minutes'] as int? ?? 0,
        goals: json['goals'] as int? ?? 0,
        assists: json['assists'] as int? ?? 0,
        yellow: json['yellow'] as int? ?? 0,
        red: json['red'] as int? ?? 0,
        shots: json['shots'] as int? ?? 0,
        saves: json['saves'] as int? ?? 0,
      );
}
