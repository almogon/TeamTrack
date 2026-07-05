/// One row of `league_standings(p_league_id)` — a team's aggregated
/// win/draw/loss record within a league.
class LeagueStanding {
  const LeagueStanding({
    required this.teamId,
    required this.teamName,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });

  final String teamId;
  final String teamName;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  int get played => wins + draws + losses;
  int get goalDifference => goalsFor - goalsAgainst;

  factory LeagueStanding.fromJson(Map<String, dynamic> json) => LeagueStanding(
        teamId: json['team_id'] as String,
        teamName: json['team_name'] as String,
        wins: json['wins'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        goalsFor: json['goals_for'] as int? ?? 0,
        goalsAgainst: json['goals_against'] as int? ?? 0,
        points: json['points'] as int? ?? 0,
      );
}
