class Player {
  const Player({
    required this.id,
    required this.teamId,
    required this.name,
    this.alias,
    this.position,
    this.number,
    required this.active,
    this.photoUrl,
    this.userId,
  });

  final String id;
  final String teamId;
  final String name;
  final String? alias;
  final String? position;
  final int? number;
  final bool active;
  final String? photoUrl;
  final String? userId;

  String get displayName => alias?.isNotEmpty == true ? alias! : name;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        name: json['name'] as String,
        alias: json['alias'] as String?,
        position: json['position'] as String?,
        number: json['number'] as int?,
        active: json['active'] as bool? ?? true,
        photoUrl: json['photo_url'] as String?,
        userId: json['user_id'] as String?,
      );
}
