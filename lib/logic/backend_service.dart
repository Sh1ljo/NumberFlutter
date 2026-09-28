import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';
import '../models/leaderboard.dart';
import '../models/player_progress.dart';
import '../models/trials.dart';
import '../models/user_profile.dart';
import 'leaderboard_ranking.dart';

/// Firebase backend: Auth for accounts, Firestore for profiles, cloud saves
/// and the leaderboard.
///
/// Collections (doc id = auth uid unless noted):
///   profiles/{uid}                 — name, location, tutorial flag, stats
///   profiles/{uid}/sessions/{auto} — one doc per archived prestige run
///   player_progress/{uid}          — [PlayerProgress.toDatabase] (owner only)
///   leaderboard/{uid}              — public ranking row, see [_leaderboardFields]
class BackendService {
  BackendService._();

  static final BackendService instance = BackendService._();

  static bool _initialized = false;
  static Future<void>? _initializing;
  static final Completer<void> _settled = Completer<void>();

  /// Completes once [initialize] has finished, whether it succeeded or not.
  /// Startup may give up waiting on a slow connection; widgets that need the
  /// backend can still wait on this and hook in once it is up.
  static Future<void> get settled => _settled.future;

  static Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // The game already saves locally (StorageService); a second offline
      // cache here would let sync compare against stale cached cloud data.
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
      _initialized = true;
    } catch (_) {
      _initializing = null; // Let a later call retry.
      rethrow;
    } finally {
      if (!_settled.isCompleted) _settled.complete();
    }
  }

  static const Duration _leaderboardCacheTtl = Duration(minutes: 3);

  final Map<String, LeaderboardPage> _leaderboardCache = {};

  /// Name/location of the signed-in player, copied onto their leaderboard
  /// row on every progress upload so the leaderboard never needs a join.
  ({String? displayName, String? country, String? city})? _profileFields;

  bool get isInitialized => _initialized;
  bool get isConfigured => _initialized;
  bool get isSignedIn => currentUser != null;
  User? get currentUser => _initialized ? _auth.currentUser : null;
  String? get currentUserId => currentUser?.uid;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');
  CollectionReference<Map<String, dynamic>> get _progress =>
      _db.collection('player_progress');
  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _db.collection('leaderboard');

  bool get _isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Google needs the native SDK (Android/iOS) or a browser popup (web);
  /// Firebase has no Google flow for desktop builds.
  bool get supportsGoogleSignIn => kIsWeb || _isMobile;

  bool get supportsAppleSignIn => _isApplePlatform;

  /// Emits the current user first, then every sign-in / sign-out.
  Stream<User?> authStateChanges() {
    if (!_initialized) return const Stream<User?>.empty();
    return _auth.authStateChanges();
  }

  Future<void> signInWithGoogle() async {
    if (!_initialized) return;
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await _signInWithGoogleNative();
  }

  /// Uses the native Google Sign-In SDK and hands its ID token to Firebase.
  /// `serverClientId` must be the Firebase project's Web client ID so the
  /// token's audience is one Firebase accepts.
  Future<void> _signInWithGoogleNative() async {
    final webClientId = AppConfig.googleWebClientId;
    if (webClientId.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-not-configured',
        message: 'Google Sign-In is not configured. Set GOOGLE_WEB_CLIENT_ID '
            'in assets/.env to the Web client ID from Firebase → '
            'Authentication → Sign-in method → Google.',
      );
    }

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
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'No ID token returned by Google. Add the app\'s SHA-1 '
            'fingerprint in Firebase project settings and check that '
            'GOOGLE_WEB_CLIENT_ID is the Web client ID.',
      );
    }

    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      ),
    );
  }

  Future<void> signInWithApple() async {
    if (!_initialized) return;
    await _auth.signInWithProvider(AppleAuthProvider());
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    // Clear the native Google session (Android/iOS) so a subsequent sign-in
    // prompts for account selection instead of silently reusing the last one.
    if (_isMobile && AppConfig.googleWebClientId.isNotEmpty) {
      try {
        await GoogleSignIn(serverClientId: AppConfig.googleWebClientId)
            .signOut();
      } catch (_) {
        // Not signed in with Google (e.g. email/password user) — ignore.
      }
    }
    _profileFields = null;
    _leaderboardCache.clear();
    await _auth.signOut();
  }

  void _rememberProfile(Map<String, dynamic> data) {
    _profileFields = (
      displayName: data['display_name'] as String?,
      country: data['country'] as String?,
      city: data['city'] as String?,
    );
  }

  Future<void> upsertProfile({
    required String userId,
    String? displayName,
    String? country,
    String? city,
    bool? tutorialCompleted,
  }) async {
    if (!_initialized) return;
    final trimmedName = _clip(displayName?.trim(), 100);

    // display_name is only written when a name is actually given. This used
    // to fall back to the auth-metadata name on every call, and cloud sync
    // calls in here every ~20s, so a name the player chose got reset.
    final publicFields = <String, dynamic>{
      if (trimmedName != null && trimmedName.isNotEmpty)
        'display_name': trimmedName,
      // Security rules cap these at 100 characters.
      if (country != null) 'country': _clip(country.trim(), 100),
      if (city != null) 'city': _clip(city.trim(), 100),
    };

    final batch = _db.batch();
    batch.set(
      _profiles.doc(userId),
      {
        ...publicFields,
        if (tutorialCompleted != null) 'tutorial_completed': tutorialCompleted,
      },
      SetOptions(merge: true),
    );
    if (publicFields.isNotEmpty) {
      batch.set(
        _leaderboard.doc(userId),
        publicFields,
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (publicFields.isNotEmpty) {
      final previous = _profileFields;
      _profileFields = (
        displayName: publicFields['display_name'] as String? ??
            previous?.displayName,
        country: publicFields['country'] as String? ?? previous?.country,
        city: publicFields['city'] as String? ?? previous?.city,
      );
      _leaderboardCache.clear();
    }
  }

  /// Creates the profile doc with a default name if it doesn't exist yet,
  /// and leaves an existing doc untouched.
  Future<void> ensureProfile({required String userId}) async {
    if (!_initialized) return;
    final user = currentUser;
    final fallbackName = (user?.email ?? 'Player').split('@').first;
    final displayName = user?.displayName?.trim();
    final defaultName = _clip(
      (displayName != null && displayName.isNotEmpty)
          ? displayName
          : fallbackName,
      100,
    )!;

    final data = await _db.runTransaction((tx) async {
      final ref = _profiles.doc(userId);
      final snapshot = await tx.get(ref);
      if (snapshot.exists) return snapshot.data()!;
      final created = <String, dynamic>{
        'display_name': defaultName,
        'tutorial_completed': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      tx.set(ref, created);
      tx.set(
        _leaderboard.doc(userId),
        {'display_name': defaultName},
        SetOptions(merge: true),
      );
      return created;
    });
    _rememberProfile(data);
  }

  Future<UserProfile?> fetchProfile({required String userId}) async {
    if (!_initialized) return null;
    final snapshot = await _profiles.doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;
    if (userId == currentUserId) _rememberProfile(data);
    return UserProfile.fromDatabase({...data, 'id': userId});
  }

  Future<UserProfile> fetchOrCreateProfile({required String userId}) async {
    final existing = await fetchProfile(userId: userId);
    if (existing != null) return existing;

    await ensureProfile(userId: userId);
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

  /// Persists tutorial completion on `profiles.tutorial_completed`.
  Future<void> setProfileTutorialCompleted({
    required String userId,
    required bool completed,
  }) async {
    if (!_initialized) return;
    await ensureProfile(userId: userId);
    await _profiles.doc(userId).set(
      {'tutorial_completed': completed},
      SetOptions(merge: true),
    );
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
    final snapshot = await _progress.doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return PlayerProgress.fromDatabase({...data, 'user_id': userId});
  }

  Map<String, dynamic> _leaderboardFields(PlayerProgress progress) {
    final highest = progress.normalizedHighestNumber;
    final profile = _profileFields;
    return {
      'highest_number_numeric': highest.toString(),
      'highest_number_log10': highestNumberSortKey(highest),
      'neural_lowest_loss': progress.neuralLowestLoss,
      'lifetime_earned_numeric': progress.lifetimeEarned.toString(),
      'lifetime_earned_log10': highestNumberSortKey(progress.lifetimeEarned),
      'prestige_count': progress.prestigeCount,
      'achievements_count': progress.achievements.length,
      'lifetime_clicks': progress.lifetimeClicks,
      ...TrialState.leaderboardFields(
        TrialState.parse(progress.trialsJson),
        progress.trialCounters,
      ),
      'updated_at': progress.updatedAt.toUtc().toIso8601String(),
      if (profile?.displayName?.isNotEmpty ?? false)
        'display_name': profile!.displayName,
      if (profile?.country != null) 'country': profile!.country,
      if (profile?.city != null) 'city': profile!.city,
    };
  }

  Future<void> upsertProgress(PlayerProgress progress) async {
    if (!_initialized) return;
    final batch = _db.batch();
    batch.set(_progress.doc(progress.userId), progress.toDatabase());
    batch.set(
      _leaderboard.doc(progress.userId),
      _leaderboardFields(progress),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Fetches the top [limit] players for [metric], plus where the signed-in
  /// player stands. [periodId] is required for the Trial boards
  /// ([LeaderboardMetric.periodField]); [country]/[city] narrow the scope.
  ///
  /// Pages are cached for a few minutes: every row is a Firestore read, and
  /// the free plan allows 50k reads a day. [force] skips the cache.
  Future<LeaderboardPage> fetchLeaderboardPage({
    required LeaderboardMetric metric,
    String? periodId,
    String? country,
    String? city,
    int limit = 100,
    bool force = false,
  }) async {
    if (!_initialized) return LeaderboardPage.empty;
    final normalizedCountry = country?.trim() ?? '';
    final normalizedCity = city?.trim() ?? '';
    final userId = currentUserId;

    final cacheKey = [
      userId,
      metric.name,
      periodId,
      normalizedCountry,
      normalizedCity,
      limit,
    ].join('|');
    final cached = _leaderboardCache[cacheKey];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _leaderboardCacheTtl) {
      return cached;
    }

    // Filters go in the same order as firestore.indexes.json.
    Query<Map<String, dynamic>> filtered = _leaderboard;
    final periodField = metric.periodField;
    if (periodField != null) {
      filtered = filtered.where(periodField, isEqualTo: periodId ?? '');
    }
    if (normalizedCountry.isNotEmpty) {
      filtered = filtered.where('country', isEqualTo: normalizedCountry);
    }
    if (normalizedCity.isNotEmpty) {
      filtered = filtered.where('city', isEqualTo: normalizedCity);
    }
    final ordered =
        filtered.orderBy(metric.sortField, descending: metric.descending);

    final results = await Future.wait<Object?>([
      ordered.limit(limit).get(),
      _countOrNull(ordered),
      if (userId != null) _ownRowOrNull(userId),
    ]);
    final snapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final total = results[1] as int?;
    final ownDoc = userId != null
        ? results[2] as DocumentSnapshot<Map<String, dynamic>>?
        : null;

    final entries = rankEntries(
      [
        for (final doc in snapshot.docs)
          LeaderboardEntry.fromDatabase(doc.id, doc.data()),
      ],
      metric,
    );

    LeaderboardEntry? me;
    int? myRank;
    final ownData = ownDoc?.data();
    final ownKey = ownData?[metric.sortField];
    final ownInPeriod =
        periodField == null || ownData?[periodField] == (periodId ?? '');
    if (ownData != null && ownKey is num && ownInPeriod) {
      final listed = entries.where((e) => e.userId == userId).firstOrNull;
      if (listed != null) {
        me = listed;
        myRank = listed.rank;
      } else {
        me = LeaderboardEntry.fromDatabase(userId!, ownData);
        // Off the page: count the players strictly ahead instead.
        final ahead = await _countOrNull(
          metric.descending
              ? filtered
                  .where(metric.sortField, isGreaterThan: ownKey)
                  .orderBy(metric.sortField, descending: true)
              : filtered
                  .where(metric.sortField, isLessThan: ownKey)
                  .orderBy(metric.sortField),
        );
        if (ahead != null) myRank = ahead + 1;
      }
    }

    final page = LeaderboardPage(
      entries: entries,
      fetchedAt: DateTime.now(),
      me: me,
      myRank: myRank,
      totalRanked: total,
    );
    _leaderboardCache[cacheKey] = page;
    return page;
  }

  /// Sorts [entries] exactly and gives them dense ranks. The stored sort
  /// keys can tie numbers that only differ past ~15 digits.
  @visibleForTesting
  static List<LeaderboardEntry> rankEntries(
    List<LeaderboardEntry> entries,
    LeaderboardMetric metric,
  ) {
    final sorted = [...entries]..sort((a, b) {
        final byValue = a.valueFor(metric).compareTo(b.valueFor(metric));
        return metric.descending ? -byValue : byValue;
      });
    final ranked = <LeaderboardEntry>[];
    var rank = 0;
    Object? previous;
    for (var i = 0; i < sorted.length; i++) {
      final value = sorted[i].valueFor(metric);
      if (i == 0 || value != previous) rank++;
      previous = value;
      ranked.add(sorted[i].withRank(rank));
    }
    return ranked;
  }

  /// Aggregation counts cost one read per 1000 matches. They are extras
  /// (rank, total), so a failure just leaves them out.
  Future<int?> _countOrNull(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.count().get();
      return snapshot.count;
    } catch (error) {
      debugPrint('Leaderboard count failed: $error');
      return null;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _ownRowOrNull(
      String userId) async {
    try {
      return await _leaderboard.doc(userId).get();
    } catch (error) {
      debugPrint('Own leaderboard row failed: $error');
      return null;
    }
  }

  static String? _clip(String? value, int maxLength) =>
      (value == null || value.length <= maxLength)
          ? value
          : value.substring(0, maxLength);

  Future<void> archiveSession({
    required String userId,
    required PlayerProgress sessionProgress,
  }) async {
    if (!_initialized) return;
    final archivedAt = DateTime.now().toUtc().toIso8601String();
    final profileRef = _profiles.doc(userId);
    final batch = _db.batch();
    batch.set(profileRef.collection('sessions').doc(), {
      'session_number': sessionProgress.prestigeCount + 1,
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
      'archived_at': archivedAt,
    });
    // Replaces the old Postgres trigger that aggregated these on insert.
    batch.set(
      profileRef,
      {
        'total_sessions': FieldValue.increment(1),
        'total_prestige_currency':
            FieldValue.increment(sessionProgress.prestigeCurrency),
        'last_session_archived_at': archivedAt,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
