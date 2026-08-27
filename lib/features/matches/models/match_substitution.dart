/// One stint a player spent on the pitch during a match — from [minuteIn]
/// until [minuteOut] (still on the pitch if null). A starting player has
/// `minuteIn == 0`; a player subbed on mid-match has `minuteIn` set to the
/// clock at that moment. Total minutes played in a match = the sum of
/// `minuteOut - minuteIn` across a player's rows for that match.
class MatchSubstitution {
  const MatchSubstitution({
    required this.id,
    required this.matchId,
    required this.playerId,
    required this.minuteIn,
    this.minuteOut,
  });

  final String id;
  final String matchId;
  final String playerId;
  final int minuteIn;
  final int? minuteOut;

  factory MatchSubstitution.fromJson(Map<String, dynamic> json) => MatchSubstitution(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        playerId: json['player_id'] as String,
        minuteIn: json['minute_in'] as int? ?? 0,
        minuteOut: json['minute_out'] as int?,
      );
}
