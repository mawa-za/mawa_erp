class FuneralServiceConfigurationDto {
  final int maxSelectableCovers;
  final bool coverSelectionLimitEnabled;
  final bool automaticMortuaryCheckoutEnabled;

  const FuneralServiceConfigurationDto({
    this.maxSelectableCovers = 3,
    this.coverSelectionLimitEnabled = true,
    this.automaticMortuaryCheckoutEnabled = false,
  });

  bool get hasCoverSelectionLimit => maxSelectableCovers > 0;

  factory FuneralServiceConfigurationDto.fromJson(Map<String, dynamic> json) {
    final maxSelectableCovers = _parseInt(json['maxSelectableCovers'], fallback: 3);
    return FuneralServiceConfigurationDto(
      maxSelectableCovers: maxSelectableCovers < 0 ? 0 : maxSelectableCovers,
      coverSelectionLimitEnabled: json['coverSelectionLimitEnabled'] is bool
          ? json['coverSelectionLimitEnabled'] as bool
          : maxSelectableCovers > 0,
      automaticMortuaryCheckoutEnabled: json['automaticMortuaryCheckoutEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxSelectableCovers': maxSelectableCovers,
        'coverSelectionLimitEnabled': maxSelectableCovers > 0,
        'automaticMortuaryCheckoutEnabled': automaticMortuaryCheckoutEnabled,
      };

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
