import 'funeral_enums.dart';

class FuneralMembershipCoverDto {
  /// Stable selection id returned by the backend for funeral claim initiation.
  ///
  /// Local covers normally come back as:
  ///   LOCAL:{membershipId}:{deceasedPartnerId}:{deceasedType}
  /// External covers normally come back as:
  ///   EXTERNAL:{externalCoverId}
  final String? membershipId;
  final String burialSocietyName;

  /// Backwards compatible amount. This remains the normal FUNERAL amount.
  final int coverAmountCents;

  /// Amount payable when this cover is used as a normal FUNERAL claim.
  final int funeralAmountCents;

  /// Amount payable when more than one cover is selected and the claim type is COMBINATION.
  final int combinationAmountCents;

  final String membershipNumber;
  final CoverSource coverSource;
  final String? sourceTenantId;
  final String? sourceTenantName;
  final String? sourceMembershipId;
  final String? sourceReference;
  final String? burialSocietyPartnerId;

  FuneralMembershipCoverDto({
    this.membershipId,
    required this.burialSocietyName,
    required this.coverAmountCents,
    int? funeralAmountCents,
    int? combinationAmountCents,
    required this.membershipNumber,
    required this.coverSource,
    this.sourceTenantId,
    this.sourceTenantName,
    this.sourceMembershipId,
    this.sourceReference,
    this.burialSocietyPartnerId,
  })  : funeralAmountCents = funeralAmountCents ?? coverAmountCents,
        combinationAmountCents = combinationAmountCents ?? coverAmountCents;

  String get selectionId {
    final candidates = [
      membershipId,
      sourceReference,
      sourceMembershipId,
      membershipNumber,
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty && value.toUpperCase() != 'N/A') {
        return value;
      }
    }

    return '${coverSource.name}:${burialSocietyName.trim()}:${membershipNumber.trim()}:${coverAmountCents.toString()}';
  }

  bool get hasValidClaimSelectionId {
    final value = membershipId?.trim();
    return value != null &&
        value.isNotEmpty &&
        (value.startsWith('LOCAL:') || value.startsWith('EXTERNAL:'));
  }

  int amountForClaimType(String claimType) {
    if (claimType.toUpperCase() == 'COMBINATION') {
      return _firstPositive([combinationAmountCents, coverAmountCents, funeralAmountCents]);
    }
    return _firstPositive([funeralAmountCents, coverAmountCents, combinationAmountCents]);
  }

  Map<String, dynamic> toJson() {
    return {
      if (membershipId != null) 'membershipId': membershipId,
      'burialSocietyName': burialSocietyName,
      'coverAmountCents': coverAmountCents,
      'funeralAmountCents': funeralAmountCents,
      'combinationAmountCents': combinationAmountCents,
      'membershipNumber': membershipNumber,
      'coverSource': coverSource.name,
      if (sourceTenantId != null) 'sourceTenantId': sourceTenantId,
      if (sourceTenantName != null) 'sourceTenantName': sourceTenantName,
      if (sourceMembershipId != null) 'sourceMembershipId': sourceMembershipId,
      if (sourceReference != null) 'sourceReference': sourceReference,
      if (burialSocietyPartnerId != null) 'burialSocietyPartnerId': burialSocietyPartnerId,
    };
  }

  factory FuneralMembershipCoverDto.fromJson(Map<String, dynamic> json) {
    final membershipSelectionId = json['membershipId'] ??
        json['selectionId'] ??
        json['selection_id'] ??
        json['id'];

    final funeralAmount = _asInt(json['funeralAmountCents'] ??
        json['funeral_amount_cents'] ??
        json['funeralCoverAmountCents'] ??
        json['funeral_cover_amount_cents'] ??
        json['funeralClaimAmountCents'] ??
        json['funeral_claim_amount_cents'] ??
        json['coverAmountCents'] ??
        json['cover_amount_cents']);

    final combinationAmount = _asInt(json['combinationAmountCents'] ??
        json['combination_amount_cents'] ??
        json['combinationCoverAmountCents'] ??
        json['combination_cover_amount_cents'] ??
        json['combinationClaimAmountCents'] ??
        json['combination_claim_amount_cents'] ??
        json['coverAmountCents'] ??
        json['cover_amount_cents']);

    return FuneralMembershipCoverDto(
      membershipId: membershipSelectionId?.toString(),
      burialSocietyName: (json['burialSocietyName'] ?? json['burial_society_name'])?.toString() ?? '',
      coverAmountCents: _asInt(json['coverAmountCents'] ?? json['cover_amount_cents'] ?? funeralAmount),
      funeralAmountCents: funeralAmount,
      combinationAmountCents: combinationAmount,
      membershipNumber: (json['membershipNumber'] ?? json['membershipNo'] ?? json['membership_no'])?.toString() ?? '',
      coverSource: CoverSource.parse((json['coverSource'] ?? json['cover_source'])?.toString()),
      sourceTenantId: (json['sourceTenantId'] ?? json['source_tenant_id'])?.toString(),
      sourceTenantName: (json['sourceTenantName'] ?? json['source_tenant_name'])?.toString(),
      sourceMembershipId: (json['sourceMembershipId'] ?? json['source_membership_id'])?.toString(),
      sourceReference: (json['sourceReference'] ?? json['source_reference'])?.toString(),
      burialSocietyPartnerId: (json['burialSocietyPartnerId'] ?? json['burial_society_partner_id'])?.toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int _firstPositive(List<int> values) {
    for (final value in values) {
      if (value > 0) return value;
    }
    return 0;
  }
}
