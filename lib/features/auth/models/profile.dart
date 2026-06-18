class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.plan,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String plan;
  final String role;
  final DateTime createdAt;

  // null means unlimited (admin bypasses all limits; manager follows plan limits)
  // Plans: free = 1 team / 2 matches; pro = 1 team / unlimited; plus = 3 teams / unlimited
  int? get teamLimit => role == 'admin' ? null : (plan == 'plus' ? 3 : 1);
  int? get matchLimit => role == 'admin' ? null : (plan == 'free' ? 2 : null);

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
        role: json['role'] as String? ?? 'user',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
