class FuneralServiceRequestDto {
  final String? id;
  final String? serviceRequestNo;
  final String? status;
  final int totalAmountCents;
  final int wizardStep;
  final String mortuaryInventoryId;
  final String deceasedName;
  final String deceasedIdentityNumber;
  final String deathCertificateNo;
  final String causeOfDeath;
  final DateTime dateOfDeath;
  final DateTime funeralDate;
  final String funeralLocation;
  final String deceasedDeliveryDirections;
  final DateTime? deceasedDeliveryDateTime;
  final String familyRepresentativeNames;
  final String familyRepresentativeSurname;
  final String familyRepresentativeContactDetails;
  final String? familyRepPartnerId;
  final String packageId;
  final List<FuneralExtraDto> extras;

  FuneralServiceRequestDto({
    this.id,
    this.serviceRequestNo,
    this.status,
    this.totalAmountCents = 0,
    this.wizardStep = 0,
    required this.mortuaryInventoryId,
    required this.deceasedName,
    required this.deceasedIdentityNumber,
    required this.deathCertificateNo,
    required this.causeOfDeath,
    required this.dateOfDeath,
    required this.funeralDate,
    required this.funeralLocation,
    this.deceasedDeliveryDirections = '',
    this.deceasedDeliveryDateTime,
    required this.familyRepresentativeNames,
    required this.familyRepresentativeSurname,
    required this.familyRepresentativeContactDetails,
    this.familyRepPartnerId,
    required this.packageId,
    required this.extras,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (serviceRequestNo != null) 'serviceRequestNo': serviceRequestNo,
      if (status != null) 'status': status,
      'totalAmountCents': totalAmountCents,
      'wizardStep': wizardStep,
      'mortuaryInventoryId': mortuaryInventoryId,
      'deceasedName': deceasedName,
      'deceasedIdentityNumber': deceasedIdentityNumber,
      'deathCertificateNo': deathCertificateNo,
      'causeOfDeath': causeOfDeath,
      'dateOfDeath': dateOfDeath.toIso8601String().substring(0, 10),
      'funeralDate': funeralDate.toIso8601String().substring(0, 10),
      'funeralArea': funeralLocation,
      'funeralLocation': funeralLocation,
      'deceasedDeliveryDirections': deceasedDeliveryDirections,
      'deliveryDirections': deceasedDeliveryDirections,
      if (deceasedDeliveryDateTime != null)
        'deceasedDeliveryDateTime': deceasedDeliveryDateTime!.toIso8601String(),
      'familyRepresentativeNames': familyRepresentativeNames,
      'familyRepresentativeSurname': familyRepresentativeSurname,
      'familyRepresentativeContactDetails': familyRepresentativeContactDetails,
      if (familyRepPartnerId != null && familyRepPartnerId!.trim().isNotEmpty)
        'familyRepId': familyRepPartnerId,
      'packageId': packageId,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralServiceRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralServiceRequestDto(
      id: json['id']?.toString(),
      serviceRequestNo: json['serviceRequestNo']?.toString(),
      status: json['status']?.toString(),
      totalAmountCents: (json['totalAmountCents'] as num?)?.toInt() ?? 0,
      wizardStep: (json['wizardStep'] as num?)?.toInt() ?? 0,
      mortuaryInventoryId: json['mortuaryInventoryId']?.toString() ?? '',
      deceasedName: json['deceasedName']?.toString() ?? '',
      deceasedIdentityNumber: json['deceasedIdentityNumber']?.toString() ?? '',
      deathCertificateNo: (json['deathCertificateNo'] ?? json['deathCertificateNumber'] ?? json['certificateNumber'] ?? '').toString(),
      causeOfDeath: json['causeOfDeath']?.toString() ?? '',
      dateOfDeath: _parseDateTime(json['dateOfDeath'] ?? json['deathDate'] ?? json['funeralDate']),
      funeralDate: _parseDateTime(json['funeralDate']),
      funeralLocation: (json['funeralLocation'] ?? json['funeralArea'] ?? '').toString(),
      deceasedDeliveryDirections: (json['deceasedDeliveryDirections'] ?? json['deliveryDirections'] ?? '').toString(),
      deceasedDeliveryDateTime: _parseNullableDateTime(json['deceasedDeliveryDateTime'] ?? json['deliveryDateTime']),
      familyRepresentativeNames: (json['familyRepresentativeNames'] ?? json['familyRepNames'] ?? '').toString(),
      familyRepresentativeSurname: (json['familyRepresentativeSurname'] ?? json['familyRepSurname'] ?? '').toString(),
      familyRepresentativeContactDetails: (json['familyRepresentativeContactDetails'] ?? json['familyRepContactDetails'] ?? '').toString(),
      familyRepPartnerId: (json['familyRepPartnerId'] ?? json['familyRepId'])?.toString(),
      packageId: json['packageId']?.toString() ?? '',
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return _parseDateTime(value);
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
