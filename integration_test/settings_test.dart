import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:team_track/features/auth/models/profile.dart';

import 'helpers/app_overrides.dart';
import 'helpers/fake_notifiers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  settingsTests();
}

void settingsTests() {
  group('Settings screen', () {
    Future<void> openSettings(WidgetTester tester, {Profile? profile}) async {
      await tester.pumpWidget(buildTestApp(profile: profile));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Settings title in app bar', (tester) async {
      await openSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows username with @ prefix in profile section',
        (tester) async {
      await openSettings(tester);

      expect(find.text('@testcoach'), findsOneWidget);
    });

    testWidgets('shows Create team list tile', (tester) async {
      await openSettings(tester);

      expect(find.text('Create team'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('shows Manage subscription list tile', (tester) async {
      await openSettings(tester);

      expect(find.text('Manage subscription'), findsOneWidget);
    });

    testWidgets('shows Sign out list tile', (tester) async {
      await openSettings(tester);

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('Manage subscription navigates to subscription screen',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();

      expect(find.text('Subscription'), findsOneWidget);
    });

    testWidgets('shows Limit reached chip for plus plan user at team limit',
        (tester) async {
      // Plus plan = 3 team limit; create 3 teams to hit the limit
      final plusProfile = Profile(
        id: 'user-1',
        username: 'testcoach',
        plan: 'plus',
        role: 'user',
        createdAt: DateTime(2026, 1, 1),
      );
      final fullTeams = List.generate(
        3,
        (i) => fakeTeam,
      );

      await tester.pumpWidget(
        buildTestApp(profile: plusProfile, teams: fullTeams),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Limit reached'), findsOneWidget);
    });
  });
}
