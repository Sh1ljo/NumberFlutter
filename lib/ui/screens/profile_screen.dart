import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/location_catalog_service.dart';
import '../../logic/supabase_service.dart';
import '../../models/user_profile.dart';
import '../../utils/network_error_utils.dart';
import '../../utils/number_formatter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  LocationCatalog? _catalog;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final service = SupabaseService.instance;
    final userId = service.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in first to edit profile.';
      });
      return;
    }

    try {
      final values = await Future.wait<dynamic>([
        LocationCatalogService.instance.load(),
        service.fetchOrCreateProfile(userId: userId),
      ]);
      final catalog = values[0] as LocationCatalog;
      final profile = values[1] as UserProfile;
      if (!mounted) return;
      _catalog = catalog;
      _profile = profile;
      _nameController.text = profile.effectiveDisplayName;
      _countryController.text = profile.country ?? '';
      _cityController.text = profile.city ?? '';
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = cloudErrorMessage(
          error,
          offlineMessage:
              'No internet connection. Profile editing is unavailable offline.',
          fallbackMessage: 'Could not load profile.',
        );
      });
    }
  }

  List<String> _citiesForCountry(String? country) {
    if (_catalog == null || country == null) return const <String>[];
    return _catalog!.citiesByCountry[country] ?? const <String>[];
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final service = SupabaseService.instance;
    final userId = service.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await service.updateProfile(
        userId: userId,
        displayName: _nameController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _profile = updated ?? _profile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = cloudErrorMessage(
          error,
          offlineMessage:
              'No internet connection. Profile changes will need internet to save.',
          fallbackMessage: 'Could not save profile. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameState = context.watch<GameState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROFILE',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        22,
                        24,
                        100 + MediaQuery.of(context).padding.bottom,
                      ),
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EDIT PROFILE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 2.2,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Display Name'),
                                validator: (value) {
                                  final trimmed = value?.trim() ?? '';
                                  if (trimmed.isEmpty) {
                                    return 'Display name is required';
                                  }
                                  if (trimmed.length < 2) {
                                    return 'Use at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Autocomplete<String>(
                                initialValue: TextEditingValue(
                                    text: _countryController.text),
                                optionsBuilder: (textEditingValue) {
                                  final input = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  if (_catalog == null) {
                                    return const Iterable<String>.empty();
                                  }
                                  if (input.isEmpty) {
                                    return _catalog!.countries.take(12);
                                  }
                                  return _catalog!.countries
                                      .where(
                                        (country) => country
                                            .toLowerCase()
                                            .contains(input),
                                      )
                                      .take(12);
                                },
                                onSelected: (selection) {
                                  _countryController.text = selection;
                                  final cities = _citiesForCountry(selection);
                                  if (!cities
                                      .contains(_cityController.text.trim())) {
                                    _cityController.clear();
                                  }
                                },
                                fieldViewBuilder: (context, textController,
                                    focusNode, onSubmitted) {
                                  return TextFormField(
                                    controller: textController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                        labelText: 'Country'),
                                    onChanged: (value) {
                                      _countryController.text = value;
                                    },
                                    validator: (value) {
                                      final trimmed = value?.trim() ?? '';
                                      if (trimmed.isEmpty) {
                                        return 'Country is required';
                                      }
                                      final exists = _catalog?.countries
                                              .contains(trimmed) ??
                                          false;
                                      if (!exists) {
                                        return 'Select a country from the list';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Autocomplete<String>(
                                initialValue: TextEditingValue(
                                    text: _cityController.text),
                                optionsBuilder: (textEditingValue) {
                                  final country =
                                      _countryController.text.trim();
                                  final cities = _citiesForCountry(country);
                                  if (cities.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  final input = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  if (input.isEmpty) return cities.take(12);
                                  return cities
                                      .where((city) =>
                                          city.toLowerCase().contains(input))
                                      .take(12);
                                },
                                onSelected: (selection) {
                                  _cityController.text = selection;
                                },
                                fieldViewBuilder: (context, textController,
                                    focusNode, onSubmitted) {
                                  return TextFormField(
                                    controller: textController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                        labelText: 'City'),
                                    onChanged: (value) {
                                      _cityController.text = value;
                                    },
                                    validator: (value) {
                                      final trimmed = value?.trim() ?? '';
                                      if (trimmed.isEmpty) {
                                        return 'City is required';
                                      }
                                      final country =
                                          _countryController.text.trim();
                                      final cities = _citiesForCountry(country);
                                      if (!cities.contains(trimmed)) {
                                        return 'Select a city from the list';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _saveProfile,
                                  child: Text(_saving ? 'SAVING...' : 'SAVE'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'PLAYER STATS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.2,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StatsCard(
                          title: 'OVERVIEW',
                          children: [
                            _StatRow(
                              label: 'Current Number',
                              value: NumberFormatter.format(gameState.number),
                            ),
                            _StatRow(
                              label: 'Highest Number Reached',
                              value: NumberFormatter.format(
                                  gameState.highestNumber),
                            ),
                            _StatRow(
                              label: 'Total Prestiges',
                              value: gameState.prestigeCount.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StatsCard(
                          title: 'PRODUCTION',
                          children: [
                            _StatRow(
                              label: 'Auto-Click Rate (Base)',
                              value:
                                  '${NumberFormatter.formatDouble(gameState.autoClickRate)} / sec',
                            ),
                            _StatRow(
                              label: 'Idle Output (Effective)',
                              value:
                                  '${NumberFormatter.formatDouble(gameState.totalIdleRate)} / sec',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StatsCard(
                          title: 'PRESTIGE',
                          children: [
                            _StatRow(
                              label: 'Prestige Multiplier',
                              value:
                                  'x${gameState.prestigeMultiplier.toStringAsFixed(3)}',
                            ),
                            _StatRow(
                              label: 'Prestige Currency',
                              value: NumberFormatter.formatDouble(
                                gameState.prestigeCurrency,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StatsCard(
                          title: 'UPGRADES',
                          children: [
                            _StatRow(
                              label: 'Upgrades Purchased',
                              value:
                                  '${gameState.upgrades.where((upgrade) => upgrade.level > 0).length} / ${gameState.upgrades.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatsCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.52),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.88),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2.2,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
