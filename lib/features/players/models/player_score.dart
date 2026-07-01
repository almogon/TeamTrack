import '../../../features/matches/models/match.dart';

/// Career totals for one player on one team, from the `player_season_scores` view.
class PlayerScore {
  const PlayerScore({
    required this.playerId,
    required this.teamId,
    required this.playerName,
    this.playerAlias,
    this.playerNumber,
    this.playerPosition,
    this.season,
    required this.sport,
    required this.totalPoints,
    required this.matchesPlayed,
  });

  final String playerId;
  final String teamId;
  final String playerName;
  final String? playerAlias;
  final int? playerNumber;
  final String? playerPosition;
  final String? season;
  final String sport;
  final int totalPoints;
  final int matchesPlayed;

  String get displayName =>
      (playerAlias != null && playerAlias!.isNotEmpty) ? playerAlias! : playerName;

  factory PlayerScore.fromJson(Map<String, dynamic> json) => PlayerScore(
        playerId: json['player_id'] as String,
        teamId: json['team_id'] as String,
        playerName: json['player_name'] as String,
        playerAlias: json['player_alias'] as String?,
        playerNumber: json['player_number'] as int?,
        playerPosition: json['player_position'] as String?,
        season: json['season'] as String?,
        sport: json['sport'] as String,
        totalPoints: json['total_points'] as int? ?? 0,
        matchesPlayed: json['matches_played'] as int? ?? 0,
      );
}

/// One match's worth of stats for a player, used in match history.
class PlayerMatchEntry {
  const PlayerMatchEntry({
    required this.match,
    required this.statCounts,
    required this.points,
  });

  final Match match;

  /// stat_type → total count for this match (e.g. {'goal': 2, 'assist': 1}).
  final Map<String, int> statCounts;

  final int points;
}

/// Key for player-scoped providers that also need team context.
typedef PlayerKey = ({String playerId, String teamId});
