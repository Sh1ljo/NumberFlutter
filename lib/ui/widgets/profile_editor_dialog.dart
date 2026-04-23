import 'package:flutter/material.dart';

import '../../logic/location_catalog_service.dart';
import '../../logic/supabase_service.dart';
import '../../models/user_profile.dart';
import '../../utils/network_error_utils.dart';

class ProfileEditorDialog extends StatefulWidget {
  const ProfileEditorDialog({
    super.key,
    this.requireLocation = false,
    this.title,
    this.subtitle,
  });

  final bool requireLocation;
  final String? title;
  final String? subtitle;

  static Future<UserProfile?> show(
    BuildContext context, {
    bool requireLocation = false,
    String? title,
    String? subtitle,
  }) {
    return showDialog<UserProfile>(
      context: context,
      barrierDismissible: !requireLocation,
      builder: (_) => ProfileEditorDialog(
        requireLocation: requireLocation,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<ProfileEditorDialog> {
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
      Navigator.of(context).pop(updated ?? _profile);
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
    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: Text(
        widget.title ?? 'PROFILE',
        style: theme.textTheme.titleLarge,
      ),
      content: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 460,
              height: 420,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subtitle ??
                            'Update your display name and location for country and city leaderboards.',
                        style:
                            theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If your city is missing, please choose the closest city. We are actively expanding the list.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Display Name'),
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
                        initialValue:
                            TextEditingValue(text: _countryController.text),
                        optionsBuilder: (textEditingValue) {
                          final input =
                              textEditingValue.text.trim().toLowerCase();
                          if (_catalog == null) {
                            return const Iterable<String>.empty();
                          }
                          if (input.isEmpty) {
                            return _catalog!.countries.take(12);
                          }
                          return _catalog!.countries
                              .where(
                                (country) =>
                                    country.toLowerCase().contains(input),
                              )
                              .take(12);
                        },
                        onSelected: (selection) {
                          _countryController.text = selection;
                          final cities = _citiesForCountry(selection);
                          if (!cities.contains(_cityController.text.trim())) {
                            _cityController.clear();
                          }
                        },
                        fieldViewBuilder:
                            (context, textController, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration:
                                const InputDecoration(labelText: 'Country'),
                            onChanged: (value) {
                              _countryController.text = value;
                            },
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) return 'Country is required';
                              final exists =
                                  _catalog?.countries.contains(trimmed) ??
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
                        initialValue:
                            TextEditingValue(text: _cityController.text),
                        optionsBuilder: (textEditingValue) {
                          final country = _countryController.text.trim();
                          final cities = _citiesForCountry(country);
                          if (cities.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          final input =
                              textEditingValue.text.trim().toLowerCase();
                          if (input.isEmpty) return cities.take(12);
                          return cities
                              .where(
                                  (city) => city.toLowerCase().contains(input))
                              .take(12);
                        },
                        onSelected: (selection) {
                          _cityController.text = selection;
                        },
                        fieldViewBuilder:
                            (context, textController, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration:
                                const InputDecoration(labelText: 'City'),
                            onChanged: (value) {
                              _cityController.text = value;
                            },
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) return 'City is required';
                              final country = _countryController.text.trim();
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
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        if (!widget.requireLocation)
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ElevatedButton(
          onPressed: _saving || _loading ? null : _saveProfile,
          child: Text(_saving ? 'SAVING...' : 'SAVE'),
        ),
      ],
    );
  }
}
