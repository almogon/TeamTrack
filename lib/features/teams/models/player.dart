class Player {
  const Player({
    required this.id,
    required this.teamId,
    required this.name,
    this.position,
    this.number,
    required this.active,
    this.photoUrl,
  });

  final String id;
  final String teamId;
  final String name;
  final String? position;
  final int? number;
  final bool active;
  final String? photoUrl;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        name: json['name'] as String,
        position: json['position'] as String?,
        number: json['number'] as int?,
        active: json['active'] as bool? ?? true,
        photoUrl: json['photo_url'] as String?,
      );
}
