import 'sport_type.dart';

class Team {
  const Team({
    required this.id,
    required this.ownerId,
    required this.name,
    this.season,
    required this.sport,
    required this.format,
    this.minPlayers,
    this.maxPlayers,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? season;
  final String sport;
  final String format;
  final int? minPlayers;
  final int? maxPlayers;
  final DateTime createdAt;

  SportType get sportType => SportType.fromValue(sport);

  String get sportFormatLabel => '${sportType.label} $format';

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        season: json['season'] as String?,
        sport: json['sport'] as String? ?? 'football',
        format: json['format'] as String? ?? '11',
        minPlayers: json['min_players'] as int?,
        maxPlayers: json['max_players'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
