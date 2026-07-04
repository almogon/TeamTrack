import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      notifyListeners();
    });
  }

  @visibleForTesting
  AuthNotifier.forTesting() {
    _sub = null;
  }

  late final StreamSubscription<AuthState>? _sub;

  bool _isPasswordRecovery = false;

  bool get isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  /// True once Supabase has emitted [AuthChangeEvent.passwordRecovery] for
  /// the current session (i.e. the user opened a "reset password" email
  /// link). The router uses this to force navigation to the update-password
  /// screen regardless of which route the link happened to land on.
  bool get isPasswordRecovery => _isPasswordRecovery;

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>(
  (ref) => AuthNotifier(),
);
