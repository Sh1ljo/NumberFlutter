import 'dart:convert';

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

  LocationCatalog? _cache;

  Future<LocationCatalog> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('lib/countries/countries.json');
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
    _cache = LocationCatalog(
      countries: countries,
      citiesByCountry: citiesByCountry,
    );
    return _cache!;
  }
}
