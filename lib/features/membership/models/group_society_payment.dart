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
  final String status;
  final String? approvalRequestId;
  final String? paymentBatchId;
  final String? receiptId;
  final String? requestedBy;

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
    this.status = 'POSTED',
    this.approvalRequestId,
    this.paymentBatchId,
    this.receiptId,
    this.requestedBy,
  });

  double get amount => amountCents / 100.0;
  double get balanceBefore => balanceBeforeCents / 100.0;
  double get balanceAfter => balanceAfterCents / 100.0;

  factory GroupSocietyPayment.fromJson(Map<String, dynamic> json) {
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

    return GroupSocietyPayment(
      id: (json['id'] ?? '').toString(),
      groupSocietyId: (json['groupSocietyId'] ?? '').toString(),
      txnType: (json['txnType'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      amountCents: toInt(json['amountCents']),
      balanceBeforeCents: toInt(json['balanceBeforeCents']),
      balanceAfterCents: toInt(json['balanceAfterCents']),
      txnDate: parseDate(json['txnDate']),
      txnDatetime: parseDate(json['txnDatetime']),
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      referenceNo: json['referenceNo']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      period: json['period']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      status: (json['status'] ?? 'POSTED').toString(),
      approvalRequestId: json['approvalRequestId']?.toString(),
      paymentBatchId: json['paymentBatchId']?.toString(),
      receiptId: json['receiptId']?.toString(),
      requestedBy: json['requestedBy']?.toString(),
    );
  }
}
