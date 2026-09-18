import 'package:flutter/material.dart';

import '../../logic/location_catalog_service.dart';
import '../../logic/backend_service.dart';
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
  String? _country;
  String? _city;
  String? _countryError;
  String? _cityError;

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
    super.dispose();
  }

  Future<void> _loadData() async {
    final service = BackendService.instance;
    final userId = service.currentUserId;
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
      final country = profile.country;
      if (country != null && catalog.countries.contains(country)) {
        _country = country;
        final city = profile.city;
        if (city != null &&
            (catalog.citiesByCountry[country]?.contains(city) ?? false)) {
          _city = city;
        }
      }
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

  Future<void> _pickCountry() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final picked = await _LocationPickerPage.open(
      context,
      title: 'Choose country',
      options: catalog.countries,
      selected: _country,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked != _country) _city = null;
      _country = picked;
      _countryError = null;
    });
  }

  Future<void> _pickCity() async {
    final country = _country;
    if (country == null) return;
    final picked = await _LocationPickerPage.open(
      context,
      title: 'Choose city in $country',
      options: _citiesForCountry(country),
      selected: _city,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _city = picked;
      _cityError = null;
    });
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    final nameValid = form?.validate() ?? false;
    setState(() {
      _countryError = _country == null ? 'Choose your country' : null;
      _cityError = _city == null ? 'Choose your city' : null;
    });
    if (!nameValid || _country == null || _city == null) return;
    final service = BackendService.instance;
    final userId = service.currentUserId;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await service.updateProfile(
        userId: userId,
        displayName: _nameController.text.trim(),
        country: _country!,
        city: _city!,
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
                      _LocationField(
                        label: 'Country',
                        value: _country,
                        placeholder: 'Tap to choose',
                        errorText: _countryError,
                        onTap: _saving ? null : _pickCountry,
                      ),
                      const SizedBox(height: 12),
                      _LocationField(
                        label: 'City',
                        value: _city,
                        placeholder: _country == null
                            ? 'Choose a country first'
                            : 'Tap to choose',
                        errorText: _cityError,
                        onTap: _saving || _country == null ? null : _pickCity,
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

/// Read-only field that opens a picker when tapped. Replaces the floating
/// Autocomplete dropdowns, which jumped around as the keyboard opened.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.errorText,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          enabled: onTap != null,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? placeholder,
          overflow: TextOverflow.ellipsis,
          style: value == null
              ? theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.outline)
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Full-screen searchable list. The search box is pinned at the top and the
/// list only shrinks when the keyboard opens, so nothing moves under the
/// player's finger.
class _LocationPickerPage extends StatefulWidget {
  const _LocationPickerPage({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  static Future<String?> open(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String? selected,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPickerPage(
          title: title,
          options: options,
          selected: selected,
        ),
      ),
    );
  }

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  String _query = '';

  List<String> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    // Names that start with the query first, then the rest that contain it.
    final starts = <String>[];
    final contains = <String>[];
    for (final option in widget.options) {
      final lower = option.toLowerCase();
      if (lower.startsWith(query)) {
        starts.add(option);
      } else if (lower.contains(query)) {
        contains.add(option);
      }
    }
    return [...starts, ...contains];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _matches;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No matches. Try another spelling or pick the closest one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final option = matches[index];
                      final isSelected = option == widget.selected;
                      return ListTile(
                        title: Text(option),
                        selected: isSelected,
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
