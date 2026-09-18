import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads [assets/.env] at runtime (see README). Firebase itself is
/// configured by the generated `lib/firebase_options.dart`. Values override empty
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

  /// The Firebase project's **Web client ID** (Firebase → Authentication →
  /// Sign-in method → Google → Web SDK configuration).
  /// Used as `serverClientId` by `google_sign_in` so the ID token we receive
  /// has an audience Firebase Auth accepts.
  static String get googleWebClientId => _resolve(
        'GOOGLE_WEB_CLIENT_ID',
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );

  static bool get hasGoogleSignInConfig => googleWebClientId.isNotEmpty;
}
