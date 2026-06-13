class Team {
  const Team({
    required this.id,
    required this.ownerId,
    required this.name,
    this.season,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? season;
  final DateTime createdAt;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        season: json['season'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
