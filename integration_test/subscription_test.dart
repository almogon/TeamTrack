import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:team_track/features/auth/models/profile.dart';
import 'package:team_track/features/subscriptions/models/subscription.dart';

import 'helpers/app_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  subscriptionTests();
}

void subscriptionTests() {
  group('Subscription screen', () {
    Future<void> openSubscription(
      WidgetTester tester, {
      Profile? profile,
      Subscription? subscription,
    }) async {
      await tester.pumpWidget(
        buildTestApp(profile: profile, subscription: subscription),
      );
      await tester.pumpAndSettle();
      // Navigate via settings → Manage subscription
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Subscription title', (tester) async {
      await openSubscription(tester);

      expect(find.text('Subscription'), findsOneWidget);
    });

    testWidgets('shows Current plan card with plan name', (tester) async {
      await openSubscription(tester);

      expect(find.text('Current plan'), findsOneWidget);
      expect(find.text('Free'), findsWidgets);
    });

    testWidgets('shows plan comparison table with Teams row', (tester) async {
      await openSubscription(tester);

      expect(find.text('Teams'), findsOneWidget);
    });

    testWidgets('shows plan comparison table with Matches / team row',
        (tester) async {
      await openSubscription(tester);

      expect(find.text('Matches / team'), findsOneWidget);
    });

    testWidgets('free user sees upgrade to Pro button', (tester) async {
      await openSubscription(tester);

      expect(find.text('Upgrade to Pro — \$9 / mo'), findsOneWidget);
    });

    testWidgets('free user sees upgrade to Plus button', (tester) async {
      await openSubscription(tester);

      expect(find.text('Upgrade to Plus — \$19 / mo'), findsOneWidget);
    });

    testWidgets('pro user sees only upgrade to Plus button', (tester) async {
      final proProfile = Profile(
        id: 'user-1',
        username: 'testcoach',
        plan: 'pro',
        role: 'user',
        createdAt: DateTime(2026, 1, 1),
      );
      await openSubscription(tester, profile: proProfile);

      expect(find.text('Upgrade to Plus — \$19 / mo'), findsOneWidget);
      expect(find.text('Upgrade to Pro — \$9 / mo'), findsNothing);
    });

    testWidgets('plus user sees You are on the Plus plan chip', (tester) async {
      final plusProfile = Profile(
        id: 'user-1',
        username: 'testcoach',
        plan: 'plus',
        role: 'user',
        createdAt: DateTime(2026, 1, 1),
      );
      await openSubscription(tester, profile: plusProfile);

      expect(find.text('You are on the Plus plan'), findsOneWidget);
    });
  });
}
