class Premium {
  final String id;
  final String membershipId;
  final String periodYYYYMM;
  final int amountCents;
  final int paidAmountCents;
  final int balanceCents;
  final String status;
  final String? dueDate;
  final String? createdAt;
  final String? createdBy;

  Premium({
    required this.id,
    required this.membershipId,
    required this.periodYYYYMM,
    required this.amountCents,
    required this.paidAmountCents,
    required this.balanceCents,
    required this.status,
    this.dueDate,
    this.createdAt,
    this.createdBy,
  });

  double get amount => amountCents / 100.0;
  double get paidAmount => paidAmountCents / 100.0;
  double get balance => balanceCents / 100.0;

  factory Premium.fromJson(Map<String, dynamic> json) {
    return Premium(
      id: (json['id'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      periodYYYYMM: (json['periodYYYYMM'] ?? json['membershipPeriod'] ?? '').toString(),
      amountCents: json['amountCents'] ?? 0,
      paidAmountCents: json['paidAmountCents'] ?? 0,
      balanceCents: json['balanceCents'] ?? 0,
      status: (json['status'] ?? 'UNPAID').toString(),
      dueDate: _parseDate(json['dueDate']),
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  static String? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is List && date.length >= 3) {
      final year = date[0].toString();
      final month = date[1].toString().padLeft(2, '0');
      final day = date[2].toString().padLeft(2, '0');
      return '$year-$month-$day';
    }
    return date.toString();
  }
}
