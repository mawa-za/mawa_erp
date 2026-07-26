class PayrollBatchSummary {
  final String id;
  final String batchNo;
  final String description;
  final String payPeriod;
  final String paymentDate;
  final String status;
  final double totalAmount;
  final int itemCount;

  PayrollBatchSummary({
    required this.id,
    required this.batchNo,
    required this.description,
    required this.payPeriod,
    required this.paymentDate,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
  });

  factory PayrollBatchSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    double amount = 0.0;
    if (json['totalAmountCents'] != null) {
      amount = toInt(json['totalAmountCents']) / 100.0;
    } else if (json['totalAmount'] != null) {
      amount = toDouble(json['totalAmount']);
    }

    return PayrollBatchSummary(
      id: (json['id'] ?? '').toString(),
      batchNo: (json['batchNo'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      payPeriod: (json['payPeriod'] ?? '').toString(),
      paymentDate: (json['paymentDate'] ?? '').toString(),
      status: (json['status'] ?? 'NEW').toString(),
      totalAmount: amount,
      itemCount: toInt(json['totalEmployees'] ?? json['itemCount']),
    );
  }
}

class PayrollBatchDetail {
  final String id;
  final String batchNo;
  final String description;
  final String payPeriod;
  final String paymentDate;
  final String notes;
  final String status;
  final List<PayrollItem> items;
  final double totalAmount;
  final int itemCount;
  final String bankMessageStatus;
  final String? fnbInstructionId;
  final String? bankReportStatus;
  final String? bankReportReason;
  final String? bankReportJson;
  final String? bankQueuedAt;
  final String? bankSubmittedAt;
  final String? bankReportRetrievedAt;

  PayrollBatchDetail({
    required this.id,
    required this.batchNo,
    required this.description,
    required this.payPeriod,
    required this.paymentDate,
    required this.notes,
    required this.status,
    required this.items,
    this.totalAmount = 0.0,
    this.itemCount = 0,
    this.bankMessageStatus = 'NOT_QUEUED',
    this.fnbInstructionId,
    this.bankReportStatus,
    this.bankReportReason,
    this.bankReportJson,
    this.bankQueuedAt,
    this.bankSubmittedAt,
    this.bankReportRetrievedAt,
  });

  factory PayrollBatchDetail.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is int) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    double amount = 0.0;
    if (json['totalAmountCents'] != null) {
      amount = toInt(json['totalAmountCents']) / 100.0;
    } else if (json['totalAmount'] != null) {
      amount = toDouble(json['totalAmount']);
    }

    return PayrollBatchDetail(
      id: (json['id'] ?? '').toString(),
      batchNo: (json['batchNo'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      payPeriod: (json['payPeriod'] ?? '').toString(),
      paymentDate: (json['paymentDate'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      status: (json['status'] ?? 'NEW').toString(),
      totalAmount: amount,
      itemCount: toInt(json['totalEmployees'] ?? json['itemCount']),
      bankMessageStatus: (json['bankMessageStatus'] ?? 'NOT_QUEUED').toString(),
      fnbInstructionId: json['fnbInstructionId']?.toString(),
      bankReportStatus: json['bankReportStatus']?.toString(),
      bankReportReason: json['bankReportReason']?.toString(),
      bankReportJson: json['bankReportJson']?.toString(),
      bankQueuedAt: json['bankQueuedAt']?.toString(),
      bankSubmittedAt: json['bankSubmittedAt']?.toString(),
      bankReportRetrievedAt: json['bankReportRetrievedAt']?.toString(),
      items: (json['items'] is List)
          ? (json['items'] as List).map((item) => PayrollItem.fromJson(item)).toList()
          : [],
    );
  }
}

class PayrollItem {
  final String? id;
  final String? employeeId;
  final String? employeeNo;
  final String? employeeName;
  final String? bankName;
  final String? branchCode;
  final String? accountNo;
  final String? accountType;
  final String? accountHolderName;
  final int amountCents;
  final String? paymentReference;
  final String? salaryReference;
  final String? status;
  final bool excluded;
  final String? exclusionReason;

  PayrollItem({
    this.id,
    this.employeeId,
    this.employeeNo,
    this.employeeName,
    this.bankName,
    this.branchCode,
    this.accountNo,
    this.accountType,
    this.accountHolderName,
    required this.amountCents,
    this.paymentReference,
    this.salaryReference,
    this.status,
    this.excluded = false,
    this.exclusionReason,
  });

  double get amount => amountCents / 100.0;

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return PayrollItem(
      id: json['id']?.toString(),
      employeeId: json['employeeId']?.toString(),
      employeeNo: json['employeeNo']?.toString(),
      employeeName: json['employeeName']?.toString(),
      bankName: json['bankName']?.toString(),
      branchCode: json['branchCode']?.toString(),
      accountNo: json['accountNo']?.toString(),
      accountType: json['accountType']?.toString(),
      accountHolderName: json['accountHolderName']?.toString(),
      amountCents: toInt(json['amountCents']),
      paymentReference: json['paymentReference']?.toString(),
      salaryReference: json['salaryReference']?.toString(),
      status: json['status']?.toString(),
      excluded: json['excluded'] ?? false,
      exclusionReason: json['exclusionReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeNo': employeeNo,
      'employeeName': employeeName,
      'bankName': bankName,
      'branchCode': branchCode,
      'accountNo': accountNo,
      'accountType': accountType,
      'accountHolderName': accountHolderName,
      'amountCents': amountCents,
      'paymentReference': paymentReference,
      'salaryReference': salaryReference,
      'status': status,
      'excluded': excluded,
      'exclusionReason': exclusionReason,
    };
  }
}
