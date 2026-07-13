class FuneralServiceRequestDto {
  final String? id;
  final String mortuaryInventoryId;
  final String deceasedName;
  final String deceasedIdentityNumber;
  final DateTime funeralDate;
  final String funeralLocation;
  final String familyRepPartnerId;
  final String packageId;
  final List<FuneralExtraDto> extras;

  FuneralServiceRequestDto({
    this.id,
    required this.mortuaryInventoryId,
    required this.deceasedName,
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
      'deceasedName': deceasedName,
      'deceasedIdentityNumber': deceasedIdentityNumber,
      'funeralDate': funeralDate.toIso8601String(),
      // Backend DTO uses funeralArea/familyRepId. Keep the existing Flutter names too
      // for backwards compatibility with older builds/endpoints.
      'funeralArea': funeralLocation,
      'funeralLocation': funeralLocation,
      'familyRepId': familyRepPartnerId,
      'familyRepPartnerId': familyRepPartnerId,
      'packageId': packageId,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralServiceRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralServiceRequestDto(
      id: json['id']?.toString(),
      mortuaryInventoryId: json['mortuaryInventoryId']?.toString() ?? '',
      deceasedName: json['deceasedName']?.toString() ?? '',
      deceasedIdentityNumber: json['deceasedIdentityNumber']?.toString() ?? '',
      funeralDate: _parseDateTime(json['funeralDate']),
      funeralLocation: (json['funeralLocation'] ?? json['funeralArea'] ?? '').toString(),
      familyRepPartnerId: (json['familyRepPartnerId'] ?? json['familyRepId'] ?? '').toString(),
      packageId: json['packageId']?.toString() ?? '',
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is List && value.length >= 3) {
    return DateTime(
      (value[0] as num).toInt(),
      (value[1] as num).toInt(),
      (value[2] as num).toInt(),
      value.length > 3 ? (value[3] as num).toInt() : 0,
      value.length > 4 ? (value[4] as num).toInt() : 0,
      value.length > 5 ? (value[5] as num).toInt() : 0,
      value.length > 6 ? ((value[6] as num).toInt() ~/ 1000000) : 0,
    );
  }
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
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
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
    );
  }
}
