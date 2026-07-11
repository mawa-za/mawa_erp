import 'funeral_enums.dart';

class FuneralClaimDto {
  final String id;
  final String? claimNumber;
  final String membershipNumber;
  final String burialSocietyName;
  final int claimedAmountCents;
  final int approvedAmountCents;
  final ClaimStatus status;
  final CoverSource coverSource;
  final String? sourceTenantName;

  FuneralClaimDto({
    required this.id,
    this.claimNumber,
    required this.membershipNumber,
    required this.burialSocietyName,
    required this.claimedAmountCents,
    required this.approvedAmountCents,
    required this.status,
    required this.coverSource,
    this.sourceTenantName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (claimNumber != null) 'claimNumber': claimNumber,
      'membershipNumber': membershipNumber,
      'burialSocietyName': burialSocietyName,
      'claimedAmountCents': claimedAmountCents,
      'approvedAmountCents': approvedAmountCents,
      'status': status.name,
      'coverSource': coverSource.name,
      if (sourceTenantName != null) 'sourceTenantName': sourceTenantName,
    };
  }

  factory FuneralClaimDto.fromJson(Map<String, dynamic> json) {
    return FuneralClaimDto(
      id: json['id']?.toString() ?? '',
      claimNumber: json['claimNumber']?.toString(),
      membershipNumber: json['membershipNumber']?.toString() ?? '',
      burialSocietyName: json['burialSocietyName']?.toString() ?? '',
      claimedAmountCents: json['claimedAmountCents'] as int? ?? 0,
      approvedAmountCents: json['approvedAmountCents'] as int? ?? 0,
      status: ClaimStatus.parse(json['status']),
      coverSource: CoverSource.parse(json['coverSource']),
      sourceTenantName: json['sourceTenantName']?.toString(),
    );
  }
}
