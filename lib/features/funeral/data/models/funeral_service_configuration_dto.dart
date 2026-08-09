class FuneralServiceConfigurationDto {
  final int maxSelectableCovers;
  final bool coverSelectionLimitEnabled;

  const FuneralServiceConfigurationDto({
    this.maxSelectableCovers = 0,
    this.coverSelectionLimitEnabled = false,
  });

  bool get hasCoverSelectionLimit => maxSelectableCovers > 0;

  factory FuneralServiceConfigurationDto.fromJson(Map<String, dynamic> json) {
    final maxSelectableCovers = _parseInt(json['maxSelectableCovers']);
    return FuneralServiceConfigurationDto(
      maxSelectableCovers: maxSelectableCovers < 0 ? 0 : maxSelectableCovers,
      coverSelectionLimitEnabled: json['coverSelectionLimitEnabled'] is bool
          ? json['coverSelectionLimitEnabled'] as bool
          : maxSelectableCovers > 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxSelectableCovers': maxSelectableCovers,
        'coverSelectionLimitEnabled': maxSelectableCovers > 0,
      };

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
