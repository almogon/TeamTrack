class StatRule {
  const StatRule({
    required this.sport,
    required this.statType,
    required this.points,
  });

  final String sport;
  final String statType;
  final int points;

  factory StatRule.fromJson(Map<String, dynamic> json) => StatRule(
        sport: json['sport'] as String,
        statType: json['stat_type'] as String,
        points: json['points'] as int,
      );
}
