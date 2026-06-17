class FuneralServiceRequestDto {
  final String? id;
  final String mortuaryInventoryId;
  final String deceasedIdentityNumber;
  final DateTime funeralDate;
  final String funeralLocation;
  final String familyRepPartnerId;
  final String packageId;
  final List<FuneralExtraDto> extras;

  FuneralServiceRequestDto({
    this.id,
    required this.mortuaryInventoryId,
    required this.deceasedIdentityNumber,
    required this.funeralDate,
    required this.funeralLocation,
    required this.familyRepPartnerId,
    required this.packageId,
    required this.extras,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'mortuaryInventoryId': mortuaryInventoryId,
      'deceasedIdentityNumber': deceasedIdentityNumber,
      'funeralDate': funeralDate.toIso8601String(),
      'funeralLocation': funeralLocation,
      'familyRepPartnerId': familyRepPartnerId,
      'packageId': packageId,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralServiceRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralServiceRequestDto(
      id: json['id']?.toString(),
      mortuaryInventoryId: json['mortuaryInventoryId']?.toString() ?? '',
      deceasedIdentityNumber: json['deceasedIdentityNumber']?.toString() ?? '',
      funeralDate: DateTime.parse(json['funeralDate'].toString()),
      funeralLocation: json['funeralLocation']?.toString() ?? '',
      familyRepPartnerId: json['familyRepPartnerId']?.toString() ?? '',
      packageId: json['packageId']?.toString() ?? '',
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class FuneralExtraDto {
  final String description;
  final int amountCents;

  FuneralExtraDto({required this.description, required this.amountCents});

  Map<String, dynamic> toJson() => {
    'description': description,
    'amountCents': amountCents,
  };

  factory FuneralExtraDto.fromJson(Map<String, dynamic> json) {
    return FuneralExtraDto(
      description: json['description']?.toString() ?? '',
      amountCents: json['amountCents'] as int? ?? 0,
    );
  }
}
