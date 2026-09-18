import 'package:flutter/material.dart';

import '../../logic/backend_service.dart';
import '../widgets/system_loading_indicator.dart';
import '../../models/user_profile.dart';
import '../../utils/number_formatter.dart';
import '../../utils/network_error_utils.dart';
import 'auth_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _refreshEpoch = 0;
  LeaderboardScope _scope = LeaderboardScope.global;
  LeaderboardMetric _metric = LeaderboardMetric.number;

  /// The fetch for the current user/metric/scope/refresh. It used to be
  /// created inside build(), so any rebuild of the auth StreamBuilder (a
  /// token refresh, a keyboard or MediaQuery change) started a new network
  /// fetch.
  String? _rowsKey;
  Future<_LeaderboardData>? _rowsFuture;

  String _rowsKeyFor(String userId) =>
      '${userId}_${_metric.name}_${_scope.name}_$_refreshEpoch';

  Future<_LeaderboardData> _rowsFor(String key) {
    if (key != _rowsKey || _rowsFuture == null) {
      _rowsKey = key;
      _rowsFuture = _fetchRows();
    }
    return _rowsFuture!;
  }

  String _formatLeaderboardNumber(dynamic value) {
    final raw = value?.toString() ?? '0';
    final parsed = BigInt.tryParse(raw);
    if (parsed == null) return raw;
    return NumberFormatter.format(parsed);
  }

  /// Renders a `neural_lowest_loss` value as an "Accuracy: 99.21%" string for
  /// the loss leaderboard. Lower loss = higher accuracy = better.
  String _formatAccuracy(dynamic value) {
    final raw = (value as num?)?.toDouble();
    if (raw == null) return 'Accuracy: —';
    final accuracy = (1.0 - raw).clamp(0.0, 1.0) * 100.0;
    return 'Accuracy: ${accuracy.toStringAsFixed(2)}%';
  }

  Future<UserProfile?> _fetchProfile() async {
    final s = BackendService.instance;
    final userId = s.currentUserId;
    if (userId == null) return null;
    return s.fetchOrCreateProfile(userId: userId);
  }

  Future<_LeaderboardData> _fetchRows() async {
    final s = BackendService.instance;
    if (!s.isInitialized || !s.isSignedIn) {
      return const _LeaderboardData(
          profile: null, rows: <Map<String, dynamic>>[]);
    }
    final profile = await _fetchProfile();
    String? country;
    String? city;
    if (_scope == LeaderboardScope.country) {
      country = profile?.country;
    } else if (_scope == LeaderboardScope.city) {
      country = profile?.country;
      city = profile?.city;
    }
    if (_scope == LeaderboardScope.country && (country?.isEmpty ?? true)) {
      return _LeaderboardData(
          profile: profile, rows: const <Map<String, dynamic>>[]);
    }
    if (_scope == LeaderboardScope.city &&
        ((country?.isEmpty ?? true) || (city?.isEmpty ?? true))) {
      return _LeaderboardData(
          profile: profile, rows: const <Map<String, dynamic>>[]);
    }
    final rows = await s.fetchLeaderboard(
      limit: 100,
      country: country,
      city: city,
      metric: _metric == LeaderboardMetric.loss ? 'loss' : 'number',
    );
    return _LeaderboardData(profile: profile, rows: rows);
  }

  String _titleForScope() {
    final suffix = _metric == LeaderboardMetric.loss ? 'ACCURACY' : 'RANKS';
    switch (_scope) {
      case LeaderboardScope.global:
        return 'GLOBAL $suffix';
      case LeaderboardScope.country:
        return 'COUNTRY $suffix';
      case LeaderboardScope.city:
        return 'CITY $suffix';
    }
  }

  String _subtitleForScope(UserProfile? profile) {
    final byMetric = _metric == LeaderboardMetric.loss
        ? 'best neural network accuracy'
        : 'highest number';
    switch (_scope) {
      case LeaderboardScope.global:
        return 'Top players worldwide by $byMetric';
      case LeaderboardScope.country:
        final country = profile?.country;
        if (country == null || country.isEmpty) {
          return 'Set your country in profile to see local rankings';
        }
        return 'Top players in $country by $byMetric';
      case LeaderboardScope.city:
        final country = profile?.country;
        final city = profile?.city;
        if (country == null ||
            city == null ||
            country.isEmpty ||
            city.isEmpty) {
          return 'Set both country and city in profile to see city rankings';
        }
        return 'Top players in $city, $country by $byMetric';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = BackendService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  // Wrap in Expanded + FittedBox so titles like
                  // "GLOBAL ACCURACY" (longer than the old "GLOBAL RANKS")
                  // shrink to fit on narrow screens instead of overflowing.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _titleForScope(),
                        maxLines: 1,
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Expanded(
                      child: !backend.isConfigured || !backend.isInitialized
                          ? Center(
                              child: Text(
                                'Leaderboard is unavailable right now (could not reach the cloud). You can still play offline from other tabs.',
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : StreamBuilder(
                        stream: backend.authStateChanges(),
                        builder: (context, _) {
                          final userId = backend.currentUserId;
                          if (userId == null) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sign in to view global rankings',
                                    style: theme.textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Your local progress is unchanged. Create an account to compete on leaderboards.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 28),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const AuthScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.login),
                                    label: const Text('SIGN IN OR SIGN UP'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final rowsKey = _rowsKeyFor(userId);
                          return FutureBuilder<_LeaderboardData>(
                            key: ValueKey<String>(rowsKey),
                            future: _rowsFor(rowsKey),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: SystemLoadingIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                final message = cloudErrorMessage(
                                  snapshot.error,
                                  offlineMessage:
                                      'No internet connection. Leaderboard is unavailable offline.',
                                  fallbackMessage:
                                      'Could not load leaderboard.',
                                );
                                return Center(
                                  child: Text(
                                    message,
                                    style: theme.textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              final data = snapshot.data ??
                                  const _LeaderboardData(
                                    profile: null,
                                    rows: <Map<String, dynamic>>[],
                                  );
                              final rows = data.rows;
                              final profile = data.profile;

                              final hasCountry =
                                  (profile?.country?.isNotEmpty ?? false);
                              final hasCity =
                                  (profile?.city?.isNotEmpty ?? false);

                              final missingScopeLocation =
                                  (_scope == LeaderboardScope.country &&
                                          !hasCountry) ||
                                      (_scope == LeaderboardScope.city &&
                                          (!hasCountry || !hasCity));

                              return RefreshIndicator(
                                onRefresh: () async {
                                  final refreshed = _fetchRows();
                                  await refreshed;
                                  if (!mounted) return;
                                  // Show the rows just fetched rather than
                                  // fetching them a second time.
                                  setState(() {
                                    _refreshEpoch++;
                                    _rowsKey =
                                        _rowsKeyFor(userId);
                                    _rowsFuture = refreshed;
                                  });
                                },
                                child: ListView(
                                  children: [
                                    Text(
                                      _subtitleForScope(profile),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 14),
                                    // Metric selector — pick what the
                                    // leaderboard ranks by. Sits above the
                                    // scope chips so the player picks
                                    // metric first, then scope.
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Number'),
                                          selected: _metric ==
                                              LeaderboardMetric.number,
                                          onSelected: (_) {
                                            setState(() {
                                              _metric =
                                                  LeaderboardMetric.number;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Loss'),
                                          selected: _metric ==
                                              LeaderboardMetric.loss,
                                          onSelected: (_) {
                                            setState(() {
                                              _metric =
                                                  LeaderboardMetric.loss;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Global'),
                                          selected:
                                              _scope == LeaderboardScope.global,
                                          onSelected: (_) {
                                            setState(() {
                                              _scope = LeaderboardScope.global;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Country'),
                                          selected: _scope ==
                                              LeaderboardScope.country,
                                          onSelected: hasCountry
                                              ? (_) {
                                                  setState(() {
                                                    _scope = LeaderboardScope
                                                        .country;
                                                  });
                                                }
                                              : null,
                                        ),
                                        ChoiceChip(
                                          label: const Text('City'),
                                          selected:
                                              _scope == LeaderboardScope.city,
                                          onSelected: hasCountry && hasCity
                                              ? (_) {
                                                  setState(() {
                                                    _scope =
                                                        LeaderboardScope.city;
                                                  });
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    if (rows.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 20),
                                        child: Text(
                                          missingScopeLocation
                                              ? 'Update your profile to view this local leaderboard.'
                                              : 'No scores yet. Be the first to rank.',
                                          style: theme.textTheme.bodyLarge,
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else
                                      ...List<Widget>.generate(rows.length,
                                          (index) {
                                        final row = rows[index];
                                        final rank = row['rank']?.toString() ??
                                            '${index + 1}';
                                        final displayName =
                                            row['display_name']?.toString() ??
                                                'Player';
                                        // Pick the column to display based on
                                        // the active metric. Loss metric shows
                                        // "Accuracy: 99.21%"; number metric
                                        // shows the formatted highest number.
                                        final value = _metric ==
                                                LeaderboardMetric.loss
                                            ? _formatAccuracy(
                                                row['neural_lowest_loss'])
                                            : _formatLeaderboardNumber(
                                                row['highest_number_numeric']);
                                        final country =
                                            row['country']?.toString();
                                        final city = row['city']?.toString();
                                        final location = [city, country]
                                            .where((v) =>
                                                v != null &&
                                                v.trim().isNotEmpty)
                                            .join(', ');
                                        return Column(
                                          children: [
                                            ListTile(
                                              dense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 0,
                                                vertical: 4,
                                              ),
                                              leading: Text(
                                                '#$rank',
                                                style:
                                                    theme.textTheme.titleLarge,
                                              ),
                                              title: Text(
                                                displayName,
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                              subtitle: Text(
                                                location.isEmpty
                                                    ? value
                                                    : '$value\n$location',
                                                style:
                                                    theme.textTheme.labelSmall,
                                              ),
                                            ),
                                            Divider(
                                              color: theme.colorScheme
                                                  .surfaceContainerLow,
                                              height: 1,
                                            ),
                                          ],
                                        );
                                      }),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum LeaderboardScope { global, country, city }

enum LeaderboardMetric { number, loss }

class _LeaderboardData {
  const _LeaderboardData({required this.profile, required this.rows});

  final UserProfile? profile;
  final List<Map<String, dynamic>> rows;
}
