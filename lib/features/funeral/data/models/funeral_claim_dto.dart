import 'funeral_enums.dart';

class FuneralClaimDto {
  /// The membership_claim.id. This is the id expected by the backend approval endpoint
  /// /v2/funeral/claims/{membershipClaimId}/submit-for-approval and is also
  /// used as the attachment object id for claim documents.
  final String id;
  final String? funeralServiceClaimId;
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
    this.funeralServiceClaimId,
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
      'membershipClaimId': id,
      if (funeralServiceClaimId != null) 'funeralServiceClaimId': funeralServiceClaimId,
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
    final membershipClaimId = _firstNonBlank(json, const [
      'membershipClaimId',
      'membership_claim_id',
      'claimId',
      'claim_id',
      'id',
    ]);

    return FuneralClaimDto(
      id: membershipClaimId ?? '',
      funeralServiceClaimId: _firstNonBlank(json, const [
        'funeralServiceClaimId',
        'funeral_service_claim_id',
      ]),
      claimNumber: _firstNonBlank(json, const ['claimNumber', 'claimNo', 'claim_no']),
      membershipNumber: json['membershipNumber']?.toString() ?? '',
      burialSocietyName: json['burialSocietyName']?.toString() ?? '',
      claimedAmountCents: _toInt(json['claimedAmountCents'] ?? json['claimAmountCents'] ?? json['claim_amount_cents']),
      approvedAmountCents: _resolveApprovedAmount(json),
      status: ClaimStatus.parse(json['status']),
      coverSource: CoverSource.parse(json['coverSource']),
      sourceTenantName: json['sourceTenantName']?.toString(),
    );
  }

  static String? _firstNonBlank(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  static int _resolveApprovedAmount(Map<String, dynamic> json) {
    final status = (json['status'] ?? '').toString().toUpperCase();
    final approved = _toInt(json['approvedAmountCents'] ?? json['approved_amount_cents']);
    if (approved > 0) return approved;
    if (status == 'APPROVED' || status == 'PARTIALLY_APPROVED' || status == 'PAID') {
      return _toInt(json['claimedAmountCents'] ?? json['claimAmountCents'] ?? json['claim_amount_cents']);
    }
    return approved;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
