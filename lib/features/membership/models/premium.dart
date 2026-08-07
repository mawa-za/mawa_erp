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
  final String? receiptId;
  final String? receiptNo;
  final String? paymentDate;
  final String? paymentMethod;
  final String? cashier;
  final String? paymentLocation;
  final String? deviceId;
  final int paymentCount;

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
    this.receiptId,
    this.receiptNo,
    this.paymentDate,
    this.paymentMethod,
    this.cashier,
    this.paymentLocation,
    this.deviceId,
    this.paymentCount = 0,
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
      createdAt: _parseDateTime(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      receiptId: json['receiptId']?.toString(),
      receiptNo: json['receiptNo']?.toString(),
      paymentDate: _parseDateTime(json['paymentDate']),
      paymentMethod: json['paymentMethod']?.toString(),
      cashier: json['cashier']?.toString(),
      paymentLocation: json['paymentLocation']?.toString(),
      deviceId: json['deviceId']?.toString(),
      paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _parseDateTime(dynamic date) {
    if (date == null) return null;
    if (date is List && date.length >= 3) {
      final year = date[0].toString().padLeft(4, '0');
      final month = date[1].toString().padLeft(2, '0');
      final day = date[2].toString().padLeft(2, '0');
      final hour = date.length > 3 ? date[3].toString().padLeft(2, '0') : '00';
      final minute = date.length > 4 ? date[4].toString().padLeft(2, '0') : '00';
      final second = date.length > 5 ? date[5].toString().padLeft(2, '0') : '00';
      return '$year-$month-${day}T$hour:$minute:$second';
    }
    return date.toString();
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
