import 'package:flutter/material.dart';

import '../../logic/supabase_service.dart';
import '../widgets/system_loading_indicator.dart';
import '../../models/user_profile.dart';
import '../../utils/number_formatter.dart';
import '../../utils/network_error_utils.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _refreshEpoch = 0;
  LeaderboardScope _scope = LeaderboardScope.global;

  String _formatLeaderboardNumber(dynamic value) {
    final raw = value?.toString() ?? '0';
    final parsed = BigInt.tryParse(raw);
    if (parsed == null) return raw;
    return NumberFormatter.format(parsed);
  }

  Future<UserProfile?> _fetchProfile() async {
    final s = SupabaseService.instance;
    final userId = s.currentSession?.user.id;
    if (userId == null) return null;
    return s.fetchOrCreateProfile(userId: userId);
  }

  Future<_LeaderboardData> _fetchRows() async {
    final s = SupabaseService.instance;
    if (!s.isInitialized || s.currentSession == null) {
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
    final rows =
        await s.fetchLeaderboard(limit: 100, country: country, city: city);
    return _LeaderboardData(profile: profile, rows: rows);
  }

  String _titleForScope() {
    switch (_scope) {
      case LeaderboardScope.global:
        return 'GLOBAL RANKS';
      case LeaderboardScope.country:
        return 'COUNTRY RANKS';
      case LeaderboardScope.city:
        return 'CITY RANKS';
    }
  }

  String _subtitleForScope(UserProfile? profile) {
    switch (_scope) {
      case LeaderboardScope.global:
        return 'Top players worldwide by highest number';
      case LeaderboardScope.country:
        final country = profile?.country;
        if (country == null || country.isEmpty) {
          return 'Set your country in profile to see local rankings';
        }
        return 'Top players in $country';
      case LeaderboardScope.city:
        final country = profile?.country;
        final city = profile?.city;
        if (country == null ||
            city == null ||
            country.isEmpty ||
            city.isEmpty) {
          return 'Set both country and city in profile to see city rankings';
        }
        return 'Top players in $city, $country';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabase = SupabaseService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleForScope(),
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 42),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 20),
              Expanded(
                child: !supabase.isConfigured || !supabase.isInitialized
                    ? Center(
                        child: Text(
                          'Leaderboard needs Supabase in assets/.env. You can still play offline from other tabs.',
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : StreamBuilder(
                        stream: supabase.authStateChanges(),
                        builder: (context, _) {
                          final session = supabase.currentSession;
                          if (session == null) {
                            return Center(
                              child: Text(
                                'Sign in under System to view global rankings. Your local progress is unchanged.',
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return FutureBuilder<_LeaderboardData>(
                            key: ValueKey<String>(
                                '${session.user.id}_${_scope.name}_$_refreshEpoch'),
                            future: _fetchRows(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: SystemLoadingIndicator(repeat: true),
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
                                  await _fetchRows();
                                  if (!mounted) return;
                                  setState(() => _refreshEpoch++);
                                },
                                child: ListView(
                                  children: [
                                    Text(
                                      _subtitleForScope(profile),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 14),
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
                                        final highest =
                                            _formatLeaderboardNumber(
                                          row['highest_number_numeric'],
                                        );
                                        final country =
                                            row['country']?.toString();
                                        final city = row['city']?.toString();
                                        final location = [city, country]
                                            .where((value) =>
                                                value != null &&
                                                value.trim().isNotEmpty)
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
                                                    ? highest
                                                    : '$highest\n$location',
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
    );
  }
}

enum LeaderboardScope { global, country, city }

class _LeaderboardData {
  const _LeaderboardData({required this.profile, required this.rows});

  final UserProfile? profile;
  final List<Map<String, dynamic>> rows;
}
