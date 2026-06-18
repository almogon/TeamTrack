class Match {
  const Match({
    required this.id,
    required this.teamId,
    required this.matchDate,
    required this.opponent,
    required this.homeAway,
    this.competition,
    this.notes,
    this.scoreFor,
    this.scoreAgainst,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.pausedAt,
    required this.period,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final DateTime matchDate;
  final String opponent;
  final String homeAway;
  final String? competition;
  final String? notes;
  final int? scoreFor;
  final int? scoreAgainst;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? pausedAt;
  final int period;
  final DateTime createdAt;

  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live';
  bool get isPaused => status == 'paused';
  bool get isFinished => status == 'finished';
  bool get isActive => isLive || isPaused;

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        matchDate: DateTime.parse(json['match_date'] as String),
        opponent: json['opponent'] as String,
        homeAway: json['home_away'] as String,
        competition: json['competition'] as String?,
        notes: json['notes'] as String?,
        scoreFor: json['score_for'] as int?,
        scoreAgainst: json['score_against'] as int?,
        status: json['status'] as String? ?? 'scheduled',
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        finishedAt: json['finished_at'] != null
            ? DateTime.parse(json['finished_at'] as String)
            : null,
        pausedAt: json['paused_at'] != null
            ? DateTime.parse(json['paused_at'] as String)
            : null,
        period: json['period'] as int? ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
