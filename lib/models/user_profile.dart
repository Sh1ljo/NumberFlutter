class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.country,
    required this.city,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String? country;
  final String? city;
  final DateTime? createdAt;

  bool get hasLocation =>
      (country?.trim().isNotEmpty ?? false) &&
      (city?.trim().isNotEmpty ?? false);

  String get effectiveDisplayName {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? 'Player' : trimmed;
  }

  UserProfile copyWith({
    String? displayName,
    String? country,
    String? city,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      city: city ?? this.city,
      createdAt: createdAt,
    );
  }

  factory UserProfile.fromDatabase(Map<String, dynamic> row) {
    return UserProfile(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      country: (row['country'] as String?)?.trim().isEmpty ?? true
          ? null
          : (row['country'] as String?)?.trim(),
      city: (row['city'] as String?)?.trim().isEmpty ?? true
          ? null
          : (row['city'] as String?)?.trim(),
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
    );
  }
}
