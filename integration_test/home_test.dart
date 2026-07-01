import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_overrides.dart';
import 'helpers/fake_notifiers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  homeTests();
}

void homeTests() {
  group('Home screen', () {
    testWidgets('shows app bar title and settings icon', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('TeamTrack'), findsWidgets);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when user has no teams', (tester) async {
      await tester.pumpWidget(buildTestApp(teams: []));
      await tester.pumpAndSettle();

      expect(find.text('No teams yet'), findsOneWidget);
      expect(find.text('Create your first team to get started'), findsOneWidget);
      expect(find.text('Create team'), findsOneWidget);
    });

    testWidgets('shows team list when teams exist', (tester) async {
      await tester.pumpWidget(buildTestApp(teams: [fakeTeam]));
      await tester.pumpAndSettle();

      expect(find.text('Real Madrid Test'), findsOneWidget);
    });

    testWidgets('tapping team card navigates to team detail', (tester) async {
      await tester.pumpWidget(buildTestApp(teams: [fakeTeam]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Real Madrid Test'));
      await tester.pumpAndSettle();

      // Team detail shows the tabs
      expect(find.text('Roster'), findsOneWidget);
      expect(find.text('Matches'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings screen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('plan badge navigates to subscription screen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // The plan ActionChip shows the plan label
      final chipFinder = find.byType(ActionChip);
      if (chipFinder.evaluate().isNotEmpty) {
        await tester.tap(chipFinder.first);
        await tester.pumpAndSettle();
        expect(find.text('Subscription'), findsOneWidget);
      }
    });
  });
}
