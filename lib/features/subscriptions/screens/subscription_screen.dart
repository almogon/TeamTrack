import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/profile_provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _loadingPlan;

  Future<void> _upgrade(String plan) async {
    setState(() => _loadingPlan = plan);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-checkout-session',
        body: {'plan': plan},
      );
      final url = (response.data as Map<String, dynamic>)['url'] as String;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open checkout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlan = null);
    }
  }

  void _refresh() {
    ref.invalidate(profileProvider);
    ref.invalidate(subscriptionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh plan',
            onPressed: _refresh,
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text('Could not load profile',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          final currentPlan = profile?.plan ?? 'free';
          final periodEnd = subAsync.value?.currentPeriodEnd;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PlanCard(plan: currentPlan, periodEnd: periodEnd),
              const SizedBox(height: 24),
              Text('Plans',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ComparisonTable(currentPlan: currentPlan),
              const SizedBox(height: 24),
              if (currentPlan == 'free') ...[
                _UpgradeButton(
                  plan: 'pro',
                  label: 'Upgrade to Pro — \$9 / mo',
                  loading: _loadingPlan == 'pro',
                  onTap: () => _upgrade('pro'),
                ),
                const SizedBox(height: 12),
                _UpgradeButton(
                  plan: 'plus',
                  label: 'Upgrade to Plus — \$19 / mo',
                  loading: _loadingPlan == 'plus',
                  onTap: () => _upgrade('plus'),
                ),
              ] else if (currentPlan == 'pro') ...[
                _UpgradeButton(
                  plan: 'plus',
                  label: 'Upgrade to Plus — \$19 / mo',
                  loading: _loadingPlan == 'plus',
                  onTap: () => _upgrade('plus'),
                ),
              ] else
                Center(
                  child: Chip(
                    avatar:
                        const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('You are on the Plus plan'),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'After payment, tap the refresh button above to update your plan.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.periodEnd});

  final String plan;
  final DateTime? periodEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (plan) {
      'plus' => 'Plus',
      'pro' => 'Pro',
      _ => 'Free',
    };
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, size: 40, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current plan',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                              )),
                  Text(label,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              )),
                  if (periodEnd != null)
                    Text(
                      'Renews ${periodEnd!.day}/${periodEnd!.month}/${periodEnd!.year}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onPrimaryContainer,
                              ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.currentPlan});

  final String currentPlan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget cell(String text, bool highlight) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlight ? cs.primary : null,
              fontWeight: highlight ? FontWeight.bold : null,
            ),
          ),
        );

    Widget headerCell(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge),
        );

    Widget tableRow(
        String feature, String free, String pro, String plus) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
                flex: 3,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(feature))),
            Expanded(flex: 2, child: cell(free, currentPlan == 'free')),
            Expanded(flex: 2, child: cell(pro, currentPlan == 'pro')),
            Expanded(flex: 2, child: cell(plus, currentPlan == 'plus')),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(flex: 2, child: headerCell('Free')),
                Expanded(flex: 2, child: headerCell('Pro')),
                Expanded(flex: 2, child: headerCell('Plus')),
              ],
            ),
            const Divider(height: 1),
            tableRow('Teams', '1', '1', '3'),
            tableRow('Matches / team', '2', '∞', '∞'),
            tableRow('Price / mo', 'Free', '\$9', '\$19'),
          ],
        ),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.plan,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String plan;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
