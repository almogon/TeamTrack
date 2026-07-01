import 'package:team_track/features/auth/notifiers/auth_notifier.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier({this.loggedIn = true}) : super.forTesting();

  final bool loggedIn;

  @override
  bool get isLoggedIn => loggedIn;
}
