import 'funeral_service_request_dto.dart';

class FuneralInvoicePreviewRequestDto {
  final String deceasedName;
  final String packageId;
  final String familyRepId;
  final List<String> memberships;
  final List<FuneralExtraDto> extras;

  FuneralInvoicePreviewRequestDto({
    required this.deceasedName,
    required this.packageId,
    required this.familyRepId,
    required this.memberships,
    required this.extras,
  });

  Map<String, dynamic> toJson() {
    return {
      'deceasedName': deceasedName,
      'packageId': packageId,
      'familyRepId': familyRepId,
      'memberships': memberships,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralInvoicePreviewRequestDto.fromJson(Map<String, dynamic> json) {
    return FuneralInvoicePreviewRequestDto(
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
