import 'funeral_enums.dart';

import '../../../../core/utils/app_date_utils.dart';
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
  final String? sourceMembershipId;
  final String? sourceReference;
  final bool claimFormPrinted;
  final int claimFormPrintCount;
  final DateTime? claimFormLastPrintedAt;

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
    this.sourceMembershipId,
    this.sourceReference,
    this.claimFormPrinted = false,
    this.claimFormPrintCount = 0,
    this.claimFormLastPrintedAt,
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
      if (sourceMembershipId != null) 'sourceMembershipId': sourceMembershipId,
      if (sourceReference != null) 'sourceReference': sourceReference,
      'claimFormPrinted': claimFormPrinted,
      'claimFormPrintCount': claimFormPrintCount,
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
      sourceMembershipId: json['sourceMembershipId']?.toString(),
      sourceReference: json['sourceReference']?.toString(),
      claimFormPrinted: json['claimFormPrinted'] == true || (json['claimFormPrintCount'] as num? ?? 0) > 0,
      claimFormPrintCount: (json['claimFormPrintCount'] as num?)?.toInt() ?? 0,
      claimFormLastPrintedAt: AppDateUtils.parse(json['claimFormLastPrintedAt']),
    );
  }
}
