class PlanLimitException implements Exception {
  const PlanLimitException({
    required this.plan,
    required this.limit,
    required this.resource,
  });

  final String plan;
  final int limit;
  final String resource;

  String get planLabel => switch (plan) {
        'pro' => 'Pro',
        'plus' => 'Plus',
        _ => 'Free',
      };

  String get message =>
      "You've reached the $planLabel plan limit of $limit "
      "${resource == 'match' ? 'match(es)' : 'team(s)'}. "
      'Upgrade your plan to continue.';
}
