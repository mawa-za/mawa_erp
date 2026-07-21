import 'funeral_enums.dart';

class FuneralClaimDto {
  final String id;
  final String? claimNumber;
  final String membershipNumber;
  final String burialSocietyName;
  final int claimedAmountCents;
  final int approvedAmountCents;
  final ClaimStatus status;
  final String rawStatus;
  final CoverSource coverSource;
  final String claimStorageScope;
  final String? sourceTenantName;

  FuneralClaimDto({
    required this.id,
    this.claimNumber,
    required this.membershipNumber,
    required this.burialSocietyName,
    required this.claimedAmountCents,
    required this.approvedAmountCents,
    required this.status,
    required this.rawStatus,
    required this.coverSource,
    this.claimStorageScope = 'LOCAL',
    this.sourceTenantName,
  });

  bool get managedExternally => claimStorageScope == 'EXTERNAL';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (claimNumber != null) 'claimNumber': claimNumber,
      'membershipNumber': membershipNumber,
      'burialSocietyName': burialSocietyName,
      'claimedAmountCents': claimedAmountCents,
      'approvedAmountCents': approvedAmountCents,
      'status': rawStatus,
      'coverSource': coverSource.name,
      'claimStorageScope': claimStorageScope,
      if (sourceTenantName != null) 'sourceTenantName': sourceTenantName,
    };
  }

  factory FuneralClaimDto.fromJson(Map<String, dynamic> json) {
    return FuneralClaimDto(
      id: (json['id'] ?? json['membershipClaimId'])?.toString() ?? '',
      claimNumber: (json['claimNumber'] ?? json['claimNo'])?.toString(),
      membershipNumber: json['membershipNumber']?.toString() ?? '',
      burialSocietyName: json['burialSocietyName']?.toString() ??
          json['sourceTenantName']?.toString() ??
          '',
      claimedAmountCents: json['claimedAmountCents'] as int? ?? 0,
      approvedAmountCents: json['approvedAmountCents'] as int? ?? 0,
      status: ClaimStatus.parse(json['status']),
      rawStatus: json['status']?.toString().trim().toUpperCase() ?? 'PENDING',
      coverSource: CoverSource.parse(json['coverSource']),
      claimStorageScope:
          json['claimStorageScope']?.toString().toUpperCase() ?? 'LOCAL',
      sourceTenantName: json['sourceTenantName']?.toString(),
    );
  }
}
