class MembershipClaim {
  final String id;
  final String claimNo;
  final String membershipId;
  final String membershipNo;
  final String memberName;
  final String memberNumber;
  final String memberIdentityNumber;
  final String deceasedName;
  final String deceasedNumber;
  final String deceasedIdentityNumber;
  final String claimantName;
  final String claimType;
  final String coveragePlanId;
  final String coveragePlanName;
  final String coverageEventDate;
  final String deceasedType;
  final String deceasedPartnerId;
  final String dateOfDeath;
  final String claimDate;
  final String? causeOfDeath;
  final String? deathCertificateNo;
  final String claimantPartnerId;
  final int claimAmountCents;
  final int approvedAmountCents;
  final int? arrearsMonths;
  final int arrearsFineCents;
  final int combinedClaimAmountCents;
  final String status;
  final String? payoutMethod;
  final String? bankName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? branchCode;
  final String? accountType;
  final String? paymentRequestId;
  final String? tombstoneOrderId;
  final String? settlementMethod;
  final String? settlementReference;
  final String? settledAt;
  final String? approvedAt;
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
    required this.membershipNo,
    required this.memberName,
    required this.memberNumber,
    required this.memberIdentityNumber,
    required this.deceasedName,
    required this.deceasedNumber,
    required this.deceasedIdentityNumber,
    required this.claimantName,
    required this.claimType,
    required this.coveragePlanId,
    required this.coveragePlanName,
    required this.coverageEventDate,
    required this.deceasedType,
    required this.deceasedPartnerId,
    required this.dateOfDeath,
    required this.claimDate,
    this.causeOfDeath,
    this.deathCertificateNo,
    required this.claimantPartnerId,
    required this.claimAmountCents,
    required this.approvedAmountCents,
    this.arrearsMonths,
    required this.arrearsFineCents,
    required this.combinedClaimAmountCents,
    required this.status,
    this.payoutMethod,
    this.bankName,
    this.accountHolderName,
    this.accountNumber,
    this.branchCode,
    this.accountType,
    this.paymentRequestId,
    this.tombstoneOrderId,
    this.settlementMethod,
    this.settlementReference,
    this.settledAt,
    this.approvedAt,
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
  double get approvedAmount => approvedAmountCents / 100.0;
  double get arrearsFine => arrearsFineCents / 100.0;
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
      membershipNo: (json['membershipNo'] ?? '').toString(),
      memberName: (json['memberName'] ?? '').toString(),
      memberNumber: (json['memberNumber'] ?? '').toString(),
      memberIdentityNumber: (json['memberIdentityNumber'] ?? '').toString(),
      deceasedName: (json['deceasedName'] ?? '').toString(),
      deceasedNumber: (json['deceasedNumber'] ?? '').toString(),
      deceasedIdentityNumber: (json['deceasedIdentityNumber'] ?? '').toString(),
      claimantName: (json['claimantName'] ?? '').toString(),
      claimType: (json['claimType'] ?? '').toString(),
      coveragePlanId: (json['coveragePlanId'] ?? '').toString(),
      coveragePlanName: (json['coveragePlanName'] ?? json['coveragePlanId'] ?? '').toString(),
      coverageEventDate: parseDate(json['coverageEventDate']),
      deceasedType: (json['deceasedType'] ?? '').toString(),
      deceasedPartnerId: (json['deceasedPartnerId'] ?? '').toString(),
      dateOfDeath: parseDate(json['dateOfDeath']),
      claimDate: parseDate(json['claimDate']),
      causeOfDeath: json['causeOfDeath']?.toString(),
      deathCertificateNo: json['deathCertificateNo']?.toString(),
      claimantPartnerId: (json['claimantPartnerId'] ?? '').toString(),
      claimAmountCents: toInt(json['claimAmountCents']),
      approvedAmountCents: toInt(json['approvedAmountCents']),
      arrearsMonths: json['arrearsMonths'] == null ? null : toInt(json['arrearsMonths']),
      arrearsFineCents: toInt(json['arrearsFineCents']),
      combinedClaimAmountCents: toInt(json['combinedClaimAmountCents']),
      status: (json['status'] ?? '').toString(),
      payoutMethod: json['payoutMethod']?.toString(),
      bankName: json['bankName']?.toString(),
      accountHolderName: json['accountHolderName']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      branchCode: json['branchCode']?.toString(),
      accountType: json['accountType']?.toString(),
      paymentRequestId: json['paymentRequestId']?.toString(),
      tombstoneOrderId: json['tombstoneOrderId']?.toString(),
      settlementMethod: json['settlementMethod']?.toString(),
      settlementReference: json['settlementReference']?.toString(),
      settledAt: json['settledAt'] == null ? null : parseDate(json['settledAt']),
      approvedAt: json['approvedAt'] == null ? null : parseDate(json['approvedAt']),
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
      'membershipNo': membershipNo,
      'memberName': memberName,
      'memberNumber': memberNumber,
      'memberIdentityNumber': memberIdentityNumber,
      'deceasedName': deceasedName,
      'deceasedNumber': deceasedNumber,
      'deceasedIdentityNumber': deceasedIdentityNumber,
      'claimantName': claimantName,
      'claimType': claimType,
      'coveragePlanId': coveragePlanId,
      'coveragePlanName': coveragePlanName,
      'coverageEventDate': coverageEventDate,
      'deceasedType': deceasedType,
      'deceasedPartnerId': deceasedPartnerId,
      'dateOfDeath': dateOfDeath,
      'claimDate': claimDate,
      'causeOfDeath': causeOfDeath,
      'deathCertificateNo': deathCertificateNo,
      'claimantPartnerId': claimantPartnerId,
      'claimAmountCents': claimAmountCents,
      'approvedAmountCents': approvedAmountCents,
      'arrearsMonths': arrearsMonths,
      'arrearsFineCents': arrearsFineCents,
      'combinedClaimAmountCents': combinedClaimAmountCents,
      'status': status,
      'payoutMethod': payoutMethod,
      if (payoutMethod?.toUpperCase() == 'EFT') ...{
        'bankName': bankName,
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'branchCode': branchCode,
        'accountType': accountType,
      },
      'paymentRequestId': paymentRequestId,
      'tombstoneOrderId': tombstoneOrderId,
      'settlementMethod': settlementMethod,
      'settlementReference': settlementReference,
      'settledAt': settledAt,
      'approvedAt': approvedAt,
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
