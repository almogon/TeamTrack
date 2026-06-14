enum SportType {
  football('football', 'Football'),
  basketball('basketball', 'Basketball'),
  volleyball('volleyball', 'Volleyball');

  const SportType(this.value, this.label);

  final String value;
  final String label;

  static SportType fromValue(String value) =>
      SportType.values.firstWhere((s) => s.value == value,
          orElse: () => SportType.football);

  List<TeamFormat> get formats => switch (this) {
        SportType.football => [
            TeamFormat.football5,
            TeamFormat.football7,
            TeamFormat.football11,
          ],
        SportType.basketball => [TeamFormat.basketball5],
        SportType.volleyball => [TeamFormat.volleyball6],
      };

  List<Position> get positions => switch (this) {
        SportType.football => Position.football,
        SportType.basketball => Position.basketball,
        SportType.volleyball => Position.volleyball,
      };
}

class TeamFormat {
  const TeamFormat({
    required this.sport,
    required this.size,
    required this.label,
    required this.minPlayers,
    required this.maxPlayers,
  });

  final SportType sport;
  final String size;
  final String label;
  final int minPlayers;
  final int maxPlayers;

  static const football5 = TeamFormat(
    sport: SportType.football,
    size: '5',
    label: 'Football 5',
    minPlayers: 5,
    maxPlayers: 8,
  );
  static const football7 = TeamFormat(
    sport: SportType.football,
    size: '7',
    label: 'Football 7',
    minPlayers: 7,
    maxPlayers: 12,
  );
  static const football11 = TeamFormat(
    sport: SportType.football,
    size: '11',
    label: 'Football 11',
    minPlayers: 11,
    maxPlayers: 18,
  );
  static const basketball5 = TeamFormat(
    sport: SportType.basketball,
    size: '5',
    label: 'Basketball 5',
    minPlayers: 5,
    maxPlayers: 12,
  );
  static const volleyball6 = TeamFormat(
    sport: SportType.volleyball,
    size: '6',
    label: 'Volleyball 6',
    minPlayers: 6,
    maxPlayers: 12,
  );
}

class Position {
  const Position({required this.code, required this.label});

  final String code;
  final String label;

  static const football = [
    Position(code: 'GK', label: 'Goalkeeper'),
    Position(code: 'DEF', label: 'Defender'),
    Position(code: 'MID', label: 'Midfielder'),
    Position(code: 'FWD', label: 'Forward'),
  ];

  static const basketball = [
    Position(code: 'PG', label: 'Point Guard'),
    Position(code: 'SG', label: 'Shooting Guard'),
    Position(code: 'SF', label: 'Small Forward'),
    Position(code: 'PF', label: 'Power Forward'),
    Position(code: 'C', label: 'Center'),
  ];

  static const volleyball = [
    Position(code: 'S', label: 'Setter'),
    Position(code: 'OH', label: 'Outside Hitter'),
    Position(code: 'MB', label: 'Middle Blocker'),
    Position(code: 'OPP', label: 'Opposite'),
    Position(code: 'L', label: 'Libero'),
  ];
}
