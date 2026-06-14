class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.plan,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String plan;
  final DateTime createdAt;

  int get teamLimit => switch (plan) {
        'plus' => 3,
        'pro' => 5,
        _ => 1,
      };

  String get planLabel => switch (plan) {
        'plus' => 'Plus',
        'pro' => 'Pro',
        _ => 'Free',
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        plan: json['plan'] as String? ?? 'free',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
