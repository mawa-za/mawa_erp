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
    String? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is String) return date;
      if (date is List && date.length >= 3) {
        final year = date[0];
        final month = date[1].toString().padLeft(2, '0');
        final day = date[2].toString().padLeft(2, '0');
        return '$year-$month-$day';
      }
      return date.toString();
    }

    return GroupSociety(
      id: json['id'] ?? '',
      partnerId: json['partnerId'] ?? '',
      groupNo: json['groupNo'] ?? '',
      societyType: json['societyType'] ?? '',
      status: json['status'] ?? '',
      availableBalanceCents: json['availableBalanceCents'] ?? 0,
      totalPaidCents: json['totalPaidCents'] ?? 0,
      totalClaimedCents: json['totalClaimedCents'] ?? 0,
      lastPaymentDate: parseDate(json['lastPaymentDate']),
      lastClaimDate: parseDate(json['lastClaimDate']),
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      updatedBy: json['updatedBy'],
    );
  }
}
