class FuneralPackageDto {
  final String id;
  final String name;
  final int basePriceCents;
  final List<String> inclusions;

  FuneralPackageDto({
    required this.id,
    required this.name,
    required this.basePriceCents,
    required this.inclusions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'basePriceCents': basePriceCents,
      'inclusions': inclusions,
    };
  }

  factory FuneralPackageDto.fromJson(Map<String, dynamic> json) {
    return FuneralPackageDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      basePriceCents: json['basePriceCents'] as int? ?? 0,
      inclusions: (json['inclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
