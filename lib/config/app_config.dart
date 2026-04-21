import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads [assets/.env] at runtime (see README). Values override empty
/// `--dart-define` compile-time defaults when set.
class AppConfig {
  AppConfig._();

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (_) {
      // Missing asset or parse error; use --dart-define or leave unset.
    }
  }

  static String _resolve(String key, String fromDefine) {
    try {
      final fromFile = dotenv.env[key];
      if (fromFile != null && fromFile.trim().isNotEmpty) {
        return fromFile.trim();
      }
    } on Object {
      // dotenv not loaded yet (e.g. widget tests that skip main()).
    }
    return fromDefine;
  }

  static String get supabaseProjectId => _resolve(
        'SUPABASE_PROJECT_ID',
        const String.fromEnvironment('SUPABASE_PROJECT_ID'),
      );

  static String get supabaseUrl => _resolve(
        'SUPABASE_URL',
        const String.fromEnvironment('SUPABASE_URL'),
      );

  static String get supabaseAnonKey => _resolve(
        'SUPABASE_ANON_KEY',
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  /// Must match [AndroidManifest] / iOS URL types and Supabase Auth redirect allow list.
  static const String defaultOauthRedirectUrl =
      'com.example.number_flutter://login-callback';

  static String get oauthRedirectUrl {
    final v = _resolve(
      'SUPABASE_OAUTH_REDIRECT_URL',
      const String.fromEnvironment('SUPABASE_OAUTH_REDIRECT_URL'),
    );
    return v.isNotEmpty ? v : defaultOauthRedirectUrl;
  }

  /// Google Cloud **Web application** OAuth Client ID.
  /// Used as `serverClientId` by `google_sign_in` so the ID token we receive
  /// is audience-bound to Supabase's registered client. Also listed in
  /// Supabase → Authentication → Providers → Google → Client IDs.
  static String get googleWebClientId => _resolve(
        'GOOGLE_WEB_CLIENT_ID',
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasGoogleSignInConfig => googleWebClientId.isNotEmpty;
}
