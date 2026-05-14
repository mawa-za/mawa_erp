class GroupSociety {
  final String id;
  final String partnerId;
  final String groupNo;
  final String societyType;
  final String status;
  final int availableBalanceCents;
  final int totalPaidCents;
  final int totalClaimedCents;
  final String? lastPaymentDate;
  final String? lastClaimDate;
  final String createdAt;
  final String createdBy;
  final String updatedAt;
  final String? updatedBy;

  GroupSociety({
    required this.id,
    required this.partnerId,
    required this.groupNo,
    required this.societyType,
    required this.status,
    required this.availableBalanceCents,
    required this.totalPaidCents,
    required this.totalClaimedCents,
    this.lastPaymentDate,
    this.lastClaimDate,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  double get availableBalance => availableBalanceCents / 100.0;
  double get totalPaid => totalPaidCents / 100.0;
  double get totalClaimed => totalClaimedCents / 100.0;

  factory GroupSociety.fromJson(Map<String, dynamic> json) {
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

    return GroupSociety(
      id: (json['id'] ?? '').toString(),
      partnerId: (json['partnerId'] ?? '').toString(),
      groupNo: (json['groupNo'] ?? '').toString(),
      societyType: (json['societyType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      availableBalanceCents: toInt(json['availableBalanceCents']),
      totalPaidCents: toInt(json['totalPaidCents']),
      totalClaimedCents: toInt(json['totalClaimedCents']),
      lastPaymentDate: parseDate(json['lastPaymentDate']),
      lastClaimDate: parseDate(json['lastClaimDate']),
      createdAt: parseDate(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}
