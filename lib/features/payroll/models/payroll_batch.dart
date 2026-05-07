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
    return PayrollBatchSummary(
      id: json['id'] ?? '',
      batchNo: json['batchNo'] ?? '',
      description: json['description'] ?? '',
      payPeriod: json['payPeriod'] ?? '',
      paymentDate: json['paymentDate'] ?? '',
      status: json['status'] ?? 'NEW',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      itemCount: json['itemCount'] ?? 0,
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

  PayrollBatchDetail({
    required this.id,
    required this.batchNo,
    required this.description,
    required this.payPeriod,
    required this.paymentDate,
    required this.notes,
    required this.status,
    required this.items,
  });

  factory PayrollBatchDetail.fromJson(Map<String, dynamic> json) {
    return PayrollBatchDetail(
      id: json['id'] ?? '',
      batchNo: json['batchNo'] ?? '',
      description: json['description'] ?? '',
      payPeriod: json['payPeriod'] ?? '',
      paymentDate: json['paymentDate'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'NEW',
      items: (json['items'] as List? ?? [])
          .map((item) => PayrollItem.fromJson(item))
          .toList(),
    );
  }
}

class PayrollItem {
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

  PayrollItem({
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
  });

  double get amount => amountCents / 100.0;

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    return PayrollItem(
      employeeId: json['employeeId'],
      employeeNo: json['employeeNo'],
      employeeName: json['employeeName'],
      bankName: json['bankName'],
      branchCode: json['branchCode'],
      accountNo: json['accountNo'],
      accountType: json['accountType'],
      accountHolderName: json['accountHolderName'],
      amountCents: json['amountCents'] ?? 0,
      paymentReference: json['paymentReference'],
      salaryReference: json['salaryReference'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }
}
