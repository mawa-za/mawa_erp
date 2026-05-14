class GroupSocietyPayment {
  final String id;
  final String groupSocietyId;
  final String txnType;
  final String direction;
  final int amountCents;
  final int balanceBeforeCents;
  final int balanceAfterCents;
  final String txnDate;
  final String txnDatetime;
  final String? referenceType;
  final String? referenceId;
  final String? referenceNo;
  final String? paymentMethod;
  final String? period;
  final String? notes;
  final String createdAt;
  final String createdBy;

  GroupSocietyPayment({
    required this.id,
    required this.groupSocietyId,
    required this.txnType,
    required this.direction,
    required this.amountCents,
    required this.balanceBeforeCents,
    required this.balanceAfterCents,
    required this.txnDate,
    required this.txnDatetime,
    this.referenceType,
    this.referenceId,
    this.referenceNo,
    this.paymentMethod,
    this.period,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  double get amount => amountCents / 100.0;
  double get balanceBefore => balanceBeforeCents / 100.0;
  double get balanceAfter => balanceAfterCents / 100.0;

  factory GroupSocietyPayment.fromJson(Map<String, dynamic> json) {
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

    return GroupSocietyPayment(
      id: json['id'] ?? '',
      groupSocietyId: json['groupSocietyId'] ?? '',
      txnType: json['txnType'] ?? '',
      direction: json['direction'] ?? '',
      amountCents: json['amountCents'] ?? 0,
      balanceBeforeCents: json['balanceBeforeCents'] ?? 0,
      balanceAfterCents: json['balanceAfterCents'] ?? 0,
      txnDate: parseDate(json['txnDate']),
      txnDatetime: json['txnDatetime'] ?? '',
      referenceType: json['referenceType'],
      referenceId: json['referenceId'],
      referenceNo: json['referenceNo'],
      paymentMethod: json['paymentMethod'],
      period: json['period'],
      notes: json['notes'],
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy'] ?? '',
    );
  }
}
