class FuneralServiceRequestDto {
  final String? id;
  final String? serviceRequestNo;
  final String mortuaryInventoryId;
  final String deceasedName;
  final String deceasedIdentityNumber;
  final DateTime funeralDate;
  final String funeralLocation;
  final String familyRepPartnerId;
  final String? deathCertificateNo;
  final String? causeOfDeath;
  final String packageId;
  final List<FuneralExtraDto> extras;
  final String? deceasedPartnerId;
  final int? totalAmountCents;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FuneralServiceRequestDto({
    this.id,
    this.serviceRequestNo,
    required this.mortuaryInventoryId,
    required this.deceasedName,
    required this.deceasedIdentityNumber,
    required this.funeralDate,
    required this.funeralLocation,
    required this.familyRepPartnerId,
    this.deathCertificateNo,
    this.causeOfDeath,
    required this.packageId,
    required this.extras,
    this.deceasedPartnerId,
    this.totalAmountCents,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (serviceRequestNo != null && serviceRequestNo!.isNotEmpty) 'serviceRequestNo': serviceRequestNo,
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
      if (deathCertificateNo != null && deathCertificateNo!.isNotEmpty) 'deathCertificateNo': deathCertificateNo,
      if (causeOfDeath != null && causeOfDeath!.isNotEmpty) 'causeOfDeath': causeOfDeath,
      'packageId': packageId,
      if (deceasedPartnerId != null && deceasedPartnerId!.isNotEmpty) 'deceasedPartnerId': deceasedPartnerId,
      if (totalAmountCents != null) 'totalAmountCents': totalAmountCents,
      if (status != null && status!.isNotEmpty) 'status': status,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralServiceRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralServiceRequestDto(
      id: json['id']?.toString(),
      serviceRequestNo: json['serviceRequestNo']?.toString(),
      mortuaryInventoryId: json['mortuaryInventoryId']?.toString() ?? '',
      deceasedName: json['deceasedName']?.toString() ?? '',
      deceasedIdentityNumber: json['deceasedIdentityNumber']?.toString() ?? '',
      funeralDate: _parseDateTime(json['funeralDate']),
      funeralLocation: (json['funeralLocation'] ?? json['funeralArea'] ?? '').toString(),
      familyRepPartnerId: (json['familyRepPartnerId'] ?? json['familyRepId'] ?? '').toString(),
      deathCertificateNo: (json['deathCertificateNo'] ?? json['certificateNumber'])?.toString(),
      causeOfDeath: json['causeOfDeath']?.toString(),
      packageId: json['packageId']?.toString() ?? '',
      deceasedPartnerId: json['deceasedPartnerId']?.toString(),
      totalAmountCents: _parseInt(json['totalAmountCents']),
      status: json['status']?.toString(),
      createdAt: _parseNullableDateTime(json['createdAt']),
      updatedAt: _parseNullableDateTime(json['updatedAt']),
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  return _parseDateTime(value);
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
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
  final String? productId;
  final String? productCode;

  FuneralExtraDto({
    required this.description,
    required this.amountCents,
    this.productId,
    this.productCode,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'amountCents': amountCents,
        if (productId != null && productId!.isNotEmpty) 'productId': productId,
        if (productCode != null && productCode!.isNotEmpty) 'productCode': productCode,
      };

  factory FuneralExtraDto.fromJson(Map<String, dynamic> json) {
    return FuneralExtraDto(
      description: json['description']?.toString() ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      productId: json['productId']?.toString(),
      productCode: json['productCode']?.toString(),
    );
  }
}
