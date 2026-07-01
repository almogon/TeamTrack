// Entry point for `flutter drive` and `flutter test integration_test/`.
// Each feature group is imported and called from here so a single command
// runs the full suite.
import 'package:integration_test/integration_test.dart';

import 'auth_test.dart' as auth;
import 'home_test.dart' as home;
import 'settings_test.dart' as settings;
import 'subscription_test.dart' as subscription;
import 'team_flow_test.dart' as team;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  auth.authTests();
  home.homeTests();
  team.teamFlowTests();
  settings.settingsTests();
  subscription.subscriptionTests();
}
