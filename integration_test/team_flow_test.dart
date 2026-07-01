import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_overrides.dart';
import 'helpers/fake_notifiers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  teamFlowTests();
}

void teamFlowTests() {
  group('Team creation wizard', () {
    Future<void> openCreateTeam(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(teams: []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create team'));
      await tester.pumpAndSettle();
    }

    testWidgets('step 0 shows sport selection', (tester) async {
      await openCreateTeam(tester);

      expect(find.text('New team'), findsOneWidget);
      expect(find.text('Football'), findsOneWidget);
      expect(find.text('Basketball'), findsOneWidget);
      expect(find.text('Volleyball'), findsOneWidget);
    });

    testWidgets('selecting a sport advances to format step', (tester) async {
      await openCreateTeam(tester);

      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();

      expect(find.text('Choose format'), findsOneWidget);
    });

    testWidgets('selecting a format advances to details step', (tester) async {
      await openCreateTeam(tester);

      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();

      // Tap the first format card available
      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      expect(find.text('Team details'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Team name'), findsOneWidget);
    });

    testWidgets('details step validates that team name is required',
        (tester) async {
      await openCreateTeam(tester);

      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      // Submit without entering a name
      await tester.tap(find.text('Create team'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('back button returns from format step to sport step',
        (tester) async {
      await openCreateTeam(tester);

      await tester.tap(find.text('Football'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('New team'), findsOneWidget);
      expect(find.text('Football'), findsOneWidget);
    });
  });

  group('Team detail screen', () {
    Future<void> openTeamDetail(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(teams: [fakeTeam]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Real Madrid Test'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows team name in app bar and two tabs', (tester) async {
      await openTeamDetail(tester);

      expect(find.text('Real Madrid Test'), findsWidgets);
      expect(find.text('Roster'), findsOneWidget);
      expect(find.text('Matches'), findsOneWidget);
    });

    testWidgets('roster tab lists player names', (tester) async {
      await openTeamDetail(tester);

      expect(find.text('Toni Kroos'), findsOneWidget);
      expect(find.text('Luka Modrić'), findsOneWidget);
    });

    testWidgets('roster tab FAB says Add player', (tester) async {
      await openTeamDetail(tester);

      expect(find.text('Add player'), findsOneWidget);
    });

    testWidgets('switching to matches tab shows FAB New match', (tester) async {
      await openTeamDetail(tester);

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('matches tab shows empty state when no matches', (tester) async {
      await openTeamDetail(tester);

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.text('No matches yet'), findsOneWidget);
    });
  });
}
