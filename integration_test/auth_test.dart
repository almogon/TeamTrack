import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  authTests();
}

void authTests() {
  group('Auth screens', () {
    testWidgets('login screen shows app title, fields and sign-in button',
        (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      expect(find.text('TeamTrack'), findsWidgets);
      expect(find.text('Sign in to manage your team'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email or username'),
          findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(
          find.text("Don't have an account? Register"), findsOneWidget);
    });

    testWidgets('login form shows validation errors on empty submit',
        (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Both required-field validators fire
      expect(find.text('This field is required'), findsWidgets);
    });

    testWidgets('tapping Register button navigates to register screen',
        (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('register screen shows all required fields', (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('register form validates password too short', (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'), 'testcoach');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('register screen has back navigation to login', (tester) async {
      await tester.pumpWidget(buildTestApp(loggedIn: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });
  });
}
