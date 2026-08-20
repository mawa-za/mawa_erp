class Cashup {
  final String id;
  final int cashupNo;
  final String deviceId;
  final String userId;
  final String cashierName;
  final String cashupDate;
  final int totalCents;
  final int receiptCount;
  final String status;
  final String source;
  final String receiptBookNo;
  final String receiptFromNo;
  final String receiptToNo;
  final int manualAmountCents;
  final int receiptTotalCents;
  final int varianceCents;
  final String employeeResponsibleId;
  final String employeeResponsibleName;
  final String areaCode;
  final String areaName;
  final int depositTotalCents;
  final int depositCount;
  final String? approvalRequestId;
  final List<CashupPayment> payments;
  final List<CashupDeposit> deposits;

  Cashup({
    required this.id,
    required this.cashupNo,
    required this.deviceId,
    required this.userId,
    required this.cashierName,
    required this.cashupDate,
    required this.totalCents,
    required this.receiptCount,
    required this.status,
    required this.source,
    required this.receiptBookNo,
    required this.receiptFromNo,
    required this.receiptToNo,
    required this.manualAmountCents,
    required this.receiptTotalCents,
    required this.varianceCents,
    required this.employeeResponsibleId,
    required this.employeeResponsibleName,
    required this.areaCode,
    required this.areaName,
    required this.depositTotalCents,
    required this.depositCount,
    required this.approvalRequestId,
    required this.payments,
    required this.deposits,
  });

  double get totalAmount => totalCents / 100;
  double get depositTotalAmount => depositTotalCents / 100;
  int get depositBalanceCents => totalCents - depositTotalCents;
  double get depositBalanceAmount => depositBalanceCents / 100;
  bool get isManualReceiptBook => source.toUpperCase() == 'MANUAL_RECEIPT_BOOK';
  bool get isElectronicPaymentCashup => source.toUpperCase() == 'ERP_ONLINE_ELECTRONIC';
  bool get depositRequired => !isElectronicPaymentCashup;
  String get cashierDisplayName => cashierName.trim().isNotEmpty ? cashierName : 'Unknown cashier';

  factory Cashup.fromJson(Map<String, dynamic> json) {
    return Cashup(
      id: json['id']?.toString() ?? json['cashupId']?.toString() ?? '',
      cashupNo: _asInt(json['cashupNo']),
      deviceId: json['deviceId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      cashierName: json['cashierName']?.toString() ?? '',
      cashupDate: _formatDate(json['cashupDate'] ?? json['date']),
      totalCents: _asInt(json['totalCents'] ?? json['totalAmountCents']),
      receiptCount: _asInt(json['receiptCount']),
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      receiptBookNo: json['receiptBookNo']?.toString() ?? '',
      receiptFromNo: json['receiptFromNo']?.toString() ?? '',
      receiptToNo: json['receiptToNo']?.toString() ?? '',
      manualAmountCents: _asInt(json['manualAmountCents']),
      receiptTotalCents: _asInt(json['receiptTotalCents']),
      varianceCents: _asInt(json['varianceCents']),
      employeeResponsibleId: json['employeeResponsibleId']?.toString() ?? '',
      employeeResponsibleName: json['employeeResponsibleName']?.toString() ?? '',
      areaCode: json['areaCode']?.toString() ?? '',
      areaName: json['areaName']?.toString() ?? '',
      depositTotalCents: _asInt(json['depositTotalCents'] ?? json['amountDepositedCents']),
      depositCount: _asInt(json['depositCount']),
      approvalRequestId: json['approvalRequestId']?.toString(),
      payments: (json['payments'] as List? ?? [])
          .whereType<Map>()
          .map((p) => CashupPayment.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      deposits: (json['deposits'] as List? ?? [])
          .whereType<Map>()
          .map((d) => CashupDeposit.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashupNo': cashupNo,
      'deviceId': deviceId,
      'userId': userId,
      'cashierName': cashierName,
      'cashupDate': cashupDate,
      'totalCents': totalCents,
      'receiptCount': receiptCount,
      'status': status,
      'source': source,
      'receiptBookNo': receiptBookNo,
      'receiptFromNo': receiptFromNo,
      'receiptToNo': receiptToNo,
      'manualAmountCents': manualAmountCents,
      'receiptTotalCents': receiptTotalCents,
      'varianceCents': varianceCents,
      'employeeResponsibleId': employeeResponsibleId,
      'employeeResponsibleName': employeeResponsibleName,
      'areaCode': areaCode,
      'areaName': areaName,
      'depositTotalCents': depositTotalCents,
      'depositCount': depositCount,
      'approvalRequestId': approvalRequestId,
      'payments': payments.map((p) => p.toJson()).toList(),
      'deposits': deposits.map((d) => d.toJson()).toList(),
    };
  }

  static String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    if (rawDate is String) return rawDate;
    if (rawDate is List && rawDate.length >= 3) {
      final year = rawDate[0];
      final month = rawDate[1].toString().padLeft(2, '0');
      final day = rawDate[2].toString().padLeft(2, '0');
      return '$year-$month-$day';
    }
    return rawDate.toString();
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class CashupPayment {
  final String paymentMethod;
  final int amountCents;
  final int paymentCount;

  CashupPayment({
    required this.paymentMethod,
    required this.amountCents,
    required this.paymentCount,
  });

  double get amount => amountCents / 100;

  factory CashupPayment.fromJson(Map<String, dynamic> json) {
    return CashupPayment(
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      amountCents: Cashup._asInt(json['amountCents']),
      paymentCount: Cashup._asInt(json['paymentCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentMethod': paymentMethod,
      'amountCents': amountCents,
      'paymentCount': paymentCount,
    };
  }
}

class CashupDeposit {
  final String id;
  final String cashupId;
  final String depositDate;
  final int amountCents;
  final String paymentMethod;
  final String bankName;
  final String referenceNo;
  final String notes;
  final String createdBy;
  final String proofAttachmentId;

  CashupDeposit({
    required this.id,
    required this.cashupId,
    required this.depositDate,
    required this.amountCents,
    required this.paymentMethod,
    required this.bankName,
    required this.referenceNo,
    required this.notes,
    required this.createdBy,
    required this.proofAttachmentId,
  });

  double get amount => amountCents / 100;

  factory CashupDeposit.fromJson(Map<String, dynamic> json) {
    return CashupDeposit(
      id: json['id']?.toString() ?? '',
      cashupId: json['cashupId']?.toString() ?? '',
      depositDate: Cashup._formatDate(json['depositDate']),
      amountCents: Cashup._asInt(json['amountCents']),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      referenceNo: json['referenceNo']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      proofAttachmentId: json['proofAttachmentId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashupId': cashupId,
      'depositDate': depositDate,
      'amountCents': amountCents,
      'paymentMethod': paymentMethod,
      'bankName': bankName,
      'referenceNo': referenceNo,
      'notes': notes,
      'createdBy': createdBy,
      'proofAttachmentId': proofAttachmentId,
    };
  }
}
