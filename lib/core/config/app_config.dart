class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deployed web build (Vercel) — used as the redirect target for
  /// Supabase auth emails (e.g. password recovery) since the app is
  /// served there rather than under a custom mobile URL scheme.
  static const webAppUrl = 'https://team-track-seven.vercel.app';

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Pass them with --dart-define.',
      );
    }
  }
}
