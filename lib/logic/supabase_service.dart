import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/player_progress.dart';
import '../models/user_profile.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || !AppConfig.hasSupabaseConfig) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  bool get isConfigured => AppConfig.hasSupabaseConfig;
  bool get isSignedIn => currentUser != null;
  User? get currentUser =>
      _initialized ? Supabase.instance.client.auth.currentUser : null;
  Session? get currentSession =>
      _initialized ? Supabase.instance.client.auth.currentSession : null;

  SupabaseClient get _client => Supabase.instance.client;

  /// Only mobile (Android/iOS) registers the custom URL scheme used by the
  /// Supabase OAuth return. On web / desktop we let Supabase use its Site URL
  /// instead, otherwise the browser gets stranded on `com.example...://...`.
  bool get _supportsDeepLinkRedirect {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  String? get _oauthRedirect =>
      _supportsDeepLinkRedirect ? AppConfig.oauthRedirectUrl : null;

  Stream<AuthState> authStateChanges() {
    if (!_initialized) return const Stream<AuthState>.empty();
    return _client.auth.onAuthStateChange;
  }

  /// On Android/iOS, uses the native Google Sign-In SDK (no browser, no URL
  /// scheme, no Supabase redirect allow list). Google returns an ID token that
  /// we hand to Supabase, which verifies it against the configured Web Client
  /// ID and creates/resolves the session in one round trip.
  ///
  /// On web/desktop, falls back to the browser OAuth flow.
  Future<void> signInWithGoogle() async {
    if (!_initialized) return;

    if (_supportsDeepLinkRedirect) {
      await _signInWithGoogleNative();
      return;
    }

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirect,
    );
  }

  Future<void> _signInWithGoogleNative() async {
    final webClientId = AppConfig.googleWebClientId;
    if (webClientId.isEmpty) {
      throw const AuthException(
        'Google Sign-In is not configured. Set GOOGLE_WEB_CLIENT_ID in '
        'assets/.env to your Google Cloud Web application client ID.',
      );
    }

    // `serverClientId` (web client) makes the returned ID token audience-bound
    // to Supabase's registered client, which is what Supabase verifies against.
    final googleSignIn = GoogleSignIn(serverClientId: webClientId);

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } on PlatformException catch (error) {
      // Code "16" (CANCELED) from Play Services is usually a stale-cache race
      // rather than a real user cancel — clearing state + retrying once fixes
      // it. "sign_in_canceled" is the plugin's equivalent mapped string.
      final code = error.code;
      if (code == 'sign_in_canceled' || code == '16') {
        try {
          await googleSignIn.signOut();
        } catch (_) {}
        googleUser = await googleSignIn.signIn();
      } else {
        rethrow;
      }
    }

    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException(
        'No ID token returned by Google. Make sure an Android OAuth client '
        'with the app\'s package name and SHA-1 fingerprint exists in Google '
        'Cloud, and that GOOGLE_WEB_CLIENT_ID points to the Web client.',
      );
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signInWithApple() async {
    if (!_initialized) return;
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirect,
    );
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      // When the confirmation email eventually reaches the user, clicking it
      // returns them to the app (mobile) or the Site URL (web/desktop).
      emailRedirectTo: _oauthRedirect,
    );
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    // Clear the native Google session (Android/iOS) so a subsequent sign-in
    // prompts for account selection instead of silently reusing the last one.
    if (_supportsDeepLinkRedirect && AppConfig.googleWebClientId.isNotEmpty) {
      try {
        final googleSignIn = GoogleSignIn(
          serverClientId: AppConfig.googleWebClientId,
        );
        await googleSignIn.signOut();
      } catch (_) {
        // Not signed in with Google (e.g. email/password user) — ignore.
      }
    }
    await _client.auth.signOut();
  }

  Future<void> upsertProfile({
    required String userId,
    String? displayName,
    String? country,
    String? city,
    bool? tutorialCompleted,
  }) async {
    if (!_initialized) return;
    final metadata = currentUser?.userMetadata ?? <String, dynamic>{};
    final fallbackName = (currentUser?.email ?? 'Player').split('@').first;
    final resolvedDisplayName = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : ((metadata['full_name'] as String?) ??
            (metadata['name'] as String?) ??
            fallbackName);

    await _client.from('profiles').upsert({
      'id': userId,
      'display_name': resolvedDisplayName,
      if (country != null) 'country': country.trim(),
      if (city != null) 'city': city.trim(),
      if (tutorialCompleted != null) 'tutorial_completed': tutorialCompleted,
    });
  }

  Future<UserProfile?> fetchProfile({required String userId}) async {
    if (!_initialized) return null;
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromDatabase(row);
  }

  Future<UserProfile> fetchOrCreateProfile({required String userId}) async {
    final existing = await fetchProfile(userId: userId);
    if (existing != null) return existing;

    await upsertProfile(userId: userId);
    final created = await fetchProfile(userId: userId);
    if (created != null) return created;

    return UserProfile(
      id: userId,
      displayName: 'Player',
      country: null,
      city: null,
      createdAt: null,
      tutorialCompleted: false,
    );
  }

  /// Persists tutorial completion on `profiles.tutorial_completed` (row must exist).
  Future<void> setProfileTutorialCompleted({
    required String userId,
    required bool completed,
  }) async {
    if (!_initialized) return;
    await fetchOrCreateProfile(userId: userId);
    await _client.from('profiles').update({
      'tutorial_completed': completed,
    }).eq('id', userId);
  }

  Future<UserProfile?> updateProfile({
    required String userId,
    required String displayName,
    required String country,
    required String city,
  }) async {
    if (!_initialized) return null;
    await upsertProfile(
      userId: userId,
      displayName: displayName,
      country: country,
      city: city,
    );
    return fetchProfile(userId: userId);
  }

  Future<PlayerProgress?> fetchProgress({required String userId}) async {
    if (!_initialized) return null;
    final row = await _client
        .from('player_progress')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return PlayerProgress.fromDatabase(row);
  }

  Future<void> upsertProgress(PlayerProgress progress) async {
    if (!_initialized) return;
    await _client.from('player_progress').upsert(progress.toDatabase());
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard({
    int limit = 50,
    String? country,
    String? city,
  }) async {
    if (!_initialized) return <Map<String, dynamic>>[];
    final normalizedCountry = country?.trim();
    final normalizedCity = city?.trim();
    try {
      final rows = await _client.rpc(
        'get_leaderboard',
        params: <String, dynamic>{
          'scope_country': (normalizedCountry?.isNotEmpty ?? false)
              ? normalizedCountry
              : null,
          'scope_city':
              (normalizedCity?.isNotEmpty ?? false) ? normalizedCity : null,
          'row_limit': limit,
        },
      );
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      // Graceful fallback if function is not deployed yet.
      var query = _client.from('leaderboard_view').select();
      if (normalizedCountry?.isNotEmpty ?? false) {
        query = query.eq('country', normalizedCountry!);
      }
      if (normalizedCity?.isNotEmpty ?? false) {
        query = query.eq('city', normalizedCity!);
      }
      final rows = await query.limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  Future<void> archiveSession({
    required String userId,
    required PlayerProgress sessionProgress,
  }) async {
    if (!_initialized) return;
    final sessionNumber = sessionProgress.prestigeCount + 1;
    await _client.from('session_archive').insert({
      'user_id': userId,
      'session_number': sessionNumber,
      'number_numeric': sessionProgress.number.toString(),
      'click_power_numeric': sessionProgress.clickPower.toString(),
      'auto_click_rate': sessionProgress.autoClickRate,
      'prestige_currency': sessionProgress.prestigeCurrency,
      'prestige_multiplier': sessionProgress.prestigeMultiplier,
      'prestige_count': sessionProgress.prestigeCount,
      'upgrade_levels': sessionProgress.upgradeLevels,
      'nexus_levels': sessionProgress.nexusLevels,
      'highest_number_numeric': sessionProgress.highestNumber.toString(),
      'progress_score': sessionProgress.progressScore,
    });
  }
}
