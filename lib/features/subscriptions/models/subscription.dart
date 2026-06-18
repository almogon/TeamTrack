class Subscription {
  const Subscription({
    required this.userId,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.plan,
    this.currentPeriodEnd,
  });

  final String userId;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String plan;
  final DateTime? currentPeriodEnd;

  bool get isActive =>
      stripeSubscriptionId != null &&
      (currentPeriodEnd == null ||
          currentPeriodEnd!.isAfter(DateTime.now()));

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        userId: json['user_id'] as String,
        stripeCustomerId: json['stripe_customer_id'] as String?,
        stripeSubscriptionId: json['stripe_subscription_id'] as String?,
        plan: json['plan'] as String? ?? 'free',
        currentPeriodEnd: json['current_period_end'] != null
            ? DateTime.parse(json['current_period_end'] as String)
            : null,
      );
}
