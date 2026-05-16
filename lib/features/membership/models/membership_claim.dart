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
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String parseDate(dynamic date) {
      if (date == null) return '';
      if (date is String) return date;
      if (date is List && date.length >= 3) {
        try {
          final year = date[0].toString();
          final month = date[1].toString().padLeft(2, '0');
          final day = date[2].toString().padLeft(2, '0');
          if (date.length >= 5) {
            final hour = date[3].toString().padLeft(2, '0');
            final minute = date[4].toString().padLeft(2, '0');
            return '$year-$month-$day $hour:$minute';
          }
          return '$year-$month-$day';
        } catch (e) {
          return date.toString();
        }
      }
      return date.toString();
    }

    return MembershipClaim(
      id: (json['id'] ?? '').toString(),
      claimNo: (json['claimNo'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      claimType: (json['claimType'] ?? '').toString(),
      deceasedType: (json['deceasedType'] ?? '').toString(),
      deceasedPartnerId: (json['deceasedPartnerId'] ?? '').toString(),
      dateOfDeath: parseDate(json['dateOfDeath']),
      claimDate: parseDate(json['claimDate']),
      causeOfDeath: json['causeOfDeath']?.toString(),
      deathCertificateNo: json['deathCertificateNo']?.toString(),
      claimantPartnerId: (json['claimantPartnerId'] ?? '').toString(),
      claimAmountCents: toInt(json['claimAmountCents']),
      combinedClaimAmountCents: toInt(json['combinedClaimAmountCents']),
      status: (json['status'] ?? '').toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      notes: json['notes']?.toString(),
      parentCombinationClaim: json['parentCombinationClaim'] == true,
      linkedToCombinationClaim: json['linkedToCombinationClaim'] == true,
      createdAt: parseDate(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
      linkedClaims: (json['linkedClaims'] as List? ?? [])
          .where((i) => i != null && i is Map)
          .map((i) => LinkedClaim.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claimNo': claimNo,
      'membershipId': membershipId,
      'claimType': claimType,
      'deceasedType': deceasedType,
      'deceasedPartnerId': deceasedPartnerId,
      'dateOfDeath': dateOfDeath,
      'claimDate': claimDate,
      'causeOfDeath': causeOfDeath,
      'deathCertificateNo': deathCertificateNo,
      'claimantPartnerId': claimantPartnerId,
      'claimAmountCents': claimAmountCents,
      'combinedClaimAmountCents': combinedClaimAmountCents,
      'status': status,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'parentCombinationClaim': parentCombinationClaim,
      'linkedToCombinationClaim': linkedToCombinationClaim,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'linkedClaims': linkedClaims.map((e) => e.toJson()).toList(),
    };
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
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return LinkedClaim(
      linkId: (json['linkId'] ?? '').toString(),
      claimId: (json['claimId'] ?? '').toString(),
      claimNo: (json['claimNo'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      claimType: (json['claimType'] ?? '').toString(),
      claimAmountCents: toInt(json['claimAmountCents']),
      status: (json['status'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'linkId': linkId,
      'claimId': claimId,
      'claimNo': claimNo,
      'membershipId': membershipId,
      'claimType': claimType,
      'claimAmountCents': claimAmountCents,
      'status': status,
    };
  }
}
