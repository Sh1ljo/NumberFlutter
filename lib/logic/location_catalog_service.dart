import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

class LocationCatalog {
  const LocationCatalog({
    required this.countries,
    required this.citiesByCountry,
  });

  final List<String> countries;
  final Map<String, List<String>> citiesByCountry;
}

class LocationCatalogService {
  LocationCatalogService._();

  static final LocationCatalogService instance = LocationCatalogService._();

  Future<LocationCatalog>? _loading;

  /// Loads once and shares the result. The 1.45MB JSON is decoded and sorted
  /// on a background isolate: doing it on the UI thread visibly hitched the
  /// first open of the profile editor.
  Future<LocationCatalog> load() {
    return _loading ??= _load().catchError((Object error) {
      _loading = null; // Let a later call retry.
      throw error;
    });
  }

  Future<LocationCatalog> _load() async {
    final raw = await rootBundle.loadString('lib/countries/countries.json');
    return compute(_parseCatalog, raw);
  }
}

LocationCatalog _parseCatalog(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final countries = <String>[];
  final citiesByCountry = <String, List<String>>{};

  for (final entry in decoded.entries) {
    final country = entry.key.trim();
    final rawCities = (entry.value as List<dynamic>)
        .map((city) => city.toString().trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (country.isEmpty || rawCities.isEmpty) continue;
    countries.add(country);
    citiesByCountry[country] = rawCities;
  }

  countries.sort();
  return LocationCatalog(
    countries: countries,
    citiesByCountry: citiesByCountry,
  );
}
