class StatEvent {
  const StatEvent({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.statType,
    this.minute,
    required this.value,
    required this.recordedAt,
  });

  final String id;
  final String matchId;
  final String playerId;
  final String statType;
  final int? minute;
  final int value;
  final DateTime recordedAt;

  factory StatEvent.fromJson(Map<String, dynamic> json) => StatEvent(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        playerId: json['player_id'] as String,
        statType: json['stat_type'] as String,
        minute: json['minute'] as int?,
        value: json['value'] as int? ?? 1,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );
}
