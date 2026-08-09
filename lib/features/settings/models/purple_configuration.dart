class PurpleConfiguration {
  final Map<String, dynamic> provider;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> availabilityRules;

  const PurpleConfiguration({
    required this.provider,
    required this.services,
    required this.availabilityRules,
  });

  factory PurpleConfiguration.fromJson(Map<String, dynamic> json) {
    return PurpleConfiguration(
      provider: Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
      services: _maps(json['services']),
      availabilityRules: _maps(json['availabilityRules']),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
}
