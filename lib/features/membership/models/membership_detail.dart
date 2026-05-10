class MembershipDetail {
  final String id;
  final String memberId;
  final String membershipNo;
  final String planId;
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

  MembershipDetail({
    required this.id,
    required this.memberId,
    required this.membershipNo,
    required this.planId,
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
  });

  factory MembershipDetail.fromJson(Map<String, dynamic> json) {
    String? parseDateArray(dynamic date) {
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
      return date?.toString();
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
      startDate: parseDateArray(json['startDate']),
      endDate: parseDateArray(json['endDate']),
      status: (json['status'] ?? '').toString(),
      paidUpToPeriod: json['paidUpToPeriod']?.toString(),
      joinDate: parseDateArray(json['joinDate']),
      createdAt: parseDateArray(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDateArray(json['updatedAt']),
      updatedBy: (json['updatedBy'] ?? '').toString(),
      oldId: parseOldId(json['oldId'] ?? json['old_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'membershipNo': membershipNo,
      'planId': planId,
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
    };
  }
}
