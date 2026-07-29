import 'funeral_service_request_dto.dart';

class FuneralInvoicePreviewRequestDto {
  final String? funeralServiceId;
  final String deceasedName;
  final String packageId;
  final String familyRepId;
  final List<String> memberships;
  final List<FuneralExtraDto> extras;

  FuneralInvoicePreviewRequestDto({
    this.funeralServiceId,
    this.deceasedName = '',
    this.packageId = '',
    this.familyRepId = '',
    this.memberships = const [],
    this.extras = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      if (funeralServiceId != null && funeralServiceId!.trim().isNotEmpty)
        'funeralServiceId': funeralServiceId!.trim(),
      'deceasedName': deceasedName,
      'packageId': packageId,
      'familyRepId': familyRepId,
      'memberships': memberships,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralInvoicePreviewRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralInvoicePreviewRequestDto(
      funeralServiceId: (json['funeralServiceId'] ?? json['serviceRequestId'])?.toString(),
      deceasedName: json['deceasedName']?.toString() ?? '',
      packageId: json['packageId']?.toString() ?? '',
      familyRepId: json['familyRepId']?.toString() ?? '',
      memberships: (json['memberships'] as List?)?.map((e) => e.toString()).toList() ?? [],
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
