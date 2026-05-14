class MembershipClaim {
  final String id;
  final String claimNo;
  final String membershipId;
  final String claimType;
  final String deceasedType;
  final String deceasedPartnerId;
  final String dateOfDeath;
  final String claimDate;
  final String? causeOfDeath;
  final String? deathCertificateNo;
  final String claimantPartnerId;
  final int claimAmountCents;
  final int combinedClaimAmountCents;
  final String status;
  final String? rejectionReason;
  final String? notes;
  final bool parentCombinationClaim;
  final bool linkedToCombinationClaim;
  final String createdAt;
  final String createdBy;
  final String updatedAt;
  final String? updatedBy;
  final List<LinkedClaim> linkedClaims;

  MembershipClaim({
    required this.id,
    required this.claimNo,
    required this.membershipId,
    required this.claimType,
    required this.deceasedType,
    required this.deceasedPartnerId,
    required this.dateOfDeath,
    required this.claimDate,
    this.causeOfDeath,
    this.deathCertificateNo,
    required this.claimantPartnerId,
    required this.claimAmountCents,
    required this.combinedClaimAmountCents,
    required this.status,
    this.rejectionReason,
    this.notes,
    required this.parentCombinationClaim,
    required this.linkedToCombinationClaim,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.updatedBy,
    required this.linkedClaims,
  });

  double get claimAmount => claimAmountCents / 100.0;
  double get combinedClaimAmount => combinedClaimAmountCents / 100.0;

  factory MembershipClaim.fromJson(Map<String, dynamic> json) {
    String parseDate(dynamic date) {
      if (date == null) return '';
      if (date is String) return date;
      if (date is List && date.length >= 3) {
        final year = date[0];
        final month = date[1].toString().padLeft(2, '0');
        final day = date[2].toString().padLeft(2, '0');
        return '$year-$month-$day';
      }
      return date.toString();
    }

    return MembershipClaim(
      id: json['id'] ?? '',
      claimNo: json['claimNo'] ?? '',
      membershipId: json['membershipId'] ?? '',
      claimType: json['claimType'] ?? '',
      deceasedType: json['deceasedType'] ?? '',
      deceasedPartnerId: json['deceasedPartnerId'] ?? '',
      dateOfDeath: parseDate(json['dateOfDeath']),
      claimDate: parseDate(json['claimDate']),
      causeOfDeath: json['causeOfDeath'],
      deathCertificateNo: json['deathCertificateNo'],
      claimantPartnerId: json['claimantPartnerId'] ?? '',
      claimAmountCents: json['claimAmountCents'] ?? 0,
      combinedClaimAmountCents: json['combinedClaimAmountCents'] ?? 0,
      status: json['status'] ?? '',
      rejectionReason: json['rejectionReason'],
      notes: json['notes'],
      parentCombinationClaim: json['parentCombinationClaim'] ?? false,
      linkedToCombinationClaim: json['linkedToCombinationClaim'] ?? false,
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      updatedBy: json['updatedBy'],
      linkedClaims: (json['linkedClaims'] as List? ?? [])
          .map((i) => LinkedClaim.fromJson(i))
          .toList(),
    );
  }
}

class LinkedClaim {
  final String linkId;
  final String claimId;
  final String claimNo;
  final String membershipId;
  final String claimType;
  final int claimAmountCents;
  final String status;

  LinkedClaim({
    required this.linkId,
    required this.claimId,
    required this.claimNo,
    required this.membershipId,
    required this.claimType,
    required this.claimAmountCents,
    required this.status,
  });

  double get claimAmount => claimAmountCents / 100.0;

  factory LinkedClaim.fromJson(Map<String, dynamic> json) {
    return LinkedClaim(
      linkId: json['linkId'] ?? '',
      claimId: json['claimId'] ?? '',
      claimNo: json['claimNo'] ?? '',
      membershipId: json['membershipId'] ?? '',
      claimType: json['claimType'] ?? '',
      claimAmountCents: json['claimAmountCents'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}
