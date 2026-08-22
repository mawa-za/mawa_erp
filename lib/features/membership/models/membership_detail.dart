class MembershipDetail {
  final String id;
  final String memberId;
  final String membershipNo;
  final String planId;
  final int premiumCents;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? paidUpToPeriod;
  final String? joinDate;
  final String? createdAt;
  final String createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? oldId;
  final String? mergedIntoMembershipId;
  final String? mergedAt;
  final String? mergedBy;

  MembershipDetail({
    required this.id,
    required this.memberId,
    required this.membershipNo,
    required this.planId,
    required this.premiumCents,
    this.startDate,
    this.endDate,
    required this.status,
    this.paidUpToPeriod,
    this.joinDate,
    this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.oldId,
    this.mergedIntoMembershipId,
    this.mergedAt,
    this.mergedBy,
  });

  double get premium => premiumCents / 100.0;

  factory MembershipDetail.fromJson(Map<String, dynamic> json) {
    String? parseDateValue(dynamic date) {
      if (date == null) return null;
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
      
      final str = date.toString();
      // If the string is likely a status (only letters and hyphens, no digits), treat as null/no date
      if (RegExp(r'^[a-zA-Z-]+$').hasMatch(str)) {
        return null;
      }
      
      return str.isEmpty || str == 'null' ? null : str;
    }

    String? parseOldId(dynamic value) {
      if (value == null) return null;
      final str = value.toString();
      if (str.isEmpty || str == 'null') return null;
      return str;
    }

    return MembershipDetail(
      id: (json['id'] ?? '').toString(),
      memberId: (json['memberId'] ?? '').toString(),
      membershipNo: (json['membershipNo'] ?? '').toString(),
      planId: (json['planId'] ?? '').toString(),
      premiumCents: json['premiumCents'] is int ? json['premiumCents'] : (int.tryParse(json['premiumCents']?.toString() ?? '0') ?? 0),
      startDate: parseDateValue(json['startDate']),
      endDate: parseDateValue(json['endDate']),
      status: (json['status'] ?? '').toString(),
      paidUpToPeriod: json['paidUpToPeriod']?.toString(),
      joinDate: parseDateValue(json['joinDate']),
      createdAt: parseDateValue(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDateValue(json['updatedAt']),
      updatedBy: (json['updatedBy'] ?? '').toString(),
      oldId: parseOldId(json['oldId'] ?? json['old_id']),
      mergedIntoMembershipId: parseOldId(json['mergedIntoMembershipId']),
      mergedAt: parseDateValue(json['mergedAt']),
      mergedBy: parseOldId(json['mergedBy']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'membershipNo': membershipNo,
      'planId': planId,
      'premiumCents': premiumCents,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'paidUpToPeriod': paidUpToPeriod,
      'joinDate': joinDate,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'oldId': oldId,
      'mergedIntoMembershipId': mergedIntoMembershipId,
      'mergedAt': mergedAt,
      'mergedBy': mergedBy,
    };
  }
}
