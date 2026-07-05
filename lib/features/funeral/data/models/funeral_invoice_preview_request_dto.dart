import 'funeral_service_request_dto.dart';

class FuneralInvoicePreviewRequestDto {
  final String deceasedName;
  final String packageId;
  final String familyRepId;
  final List<String> memberships;
  final List<FuneralExtraDto> extras;
  final String claimType;

  FuneralInvoicePreviewRequestDto({
    required this.deceasedName,
    required this.packageId,
    required this.familyRepId,
    required this.memberships,
    required this.extras,
    String? claimType,
  }) : claimType = (claimType == null || claimType.trim().isEmpty)
            ? (memberships.length > 1 ? 'COMBINATION' : 'FUNERAL')
            : claimType.trim().toUpperCase();

  Map<String, dynamic> toJson() {
    return {
      'deceasedName': deceasedName,
      'packageId': packageId,
      'familyRepId': familyRepId,
      'memberships': memberships,
      'claimType': claimType,
      'extras': extras.map((e) => e.toJson()).toList(),
    };
  }

  factory FuneralInvoicePreviewRequestDto.fromJson(Map<String, dynamic> json) {
    final memberships = (json['memberships'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return FuneralInvoicePreviewRequestDto(
      deceasedName: json['deceasedName']?.toString() ?? '',
      packageId: json['packageId']?.toString() ?? '',
      familyRepId: json['familyRepId']?.toString() ?? '',
      memberships: memberships,
      claimType: json['claimType']?.toString(),
      extras: (json['extras'] as List? ?? [])
          .map((e) => FuneralExtraDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
