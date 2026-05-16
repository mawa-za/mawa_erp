class PaymentRequestResponse {
  final String id;
  final String requestNo;
  final String requestType;
  final String sourceType;
  final String? sourceId;
  final String? payeePartnerId;
  final String payeeName;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? bankName;
  final String? accountHolder;
  final String? accountNumber;
  final String? branchCode;
  final String? accountType;
  final String? invoiceNo;
  final String? externalReference;
  final String? paymentReason;
  final String? notes;
  final String? requestedPaymentDate;
  final String status;
  final String? approvalRequestId;
  final String? paidDate;
  final String? paidReference;
  final String? paidBy;
  final String createdAt;
  final String createdBy;
  final String updatedAt;
  final String? updatedBy;

  PaymentRequestResponse({
    required this.id,
    required this.requestNo,
    required this.requestType,
    required this.sourceType,
    this.sourceId,
    this.payeePartnerId,
    required this.payeeName,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.bankName,
    this.accountHolder,
    this.accountNumber,
    this.branchCode,
    this.accountType,
    this.invoiceNo,
    this.externalReference,
    this.paymentReason,
    this.notes,
    this.requestedPaymentDate,
    required this.status,
    this.approvalRequestId,
    this.paidDate,
    this.paidReference,
    this.paidBy,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  // Compatibility getters for UI
  String get recipient => payeeName;
  String get reference => externalReference ?? '';
  String get dueDate => requestedPaymentDate ?? '';
  String get number => requestNo;
  String get createdDate => createdAt;
  String get instructionId => requestNo;

  factory PaymentRequestResponse.fromJson(Map<String, dynamic> json) {
    return PaymentRequestResponse(
      id: (json['id'] ?? '').toString(),
      requestNo: (json['requestNo'] ?? '').toString(),
      requestType: (json['requestType'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? '').toString(),
      sourceId: json['sourceId']?.toString(),
      payeePartnerId: json['payeePartnerId']?.toString(),
      payeeName: (json['payeeName'] ?? '').toString(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: (json['currency'] ?? 'ZAR').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      bankName: json['bankName']?.toString(),
      accountHolder: json['accountHolder']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      branchCode: json['branchCode']?.toString(),
      accountType: json['accountType']?.toString(),
      invoiceNo: json['invoiceNo']?.toString(),
      externalReference: json['externalReference']?.toString(),
      paymentReason: json['paymentReason']?.toString(),
      notes: json['notes']?.toString(),
      requestedPaymentDate: json['requestedPaymentDate']?.toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      approvalRequestId: json['approvalRequestId']?.toString(),
      paidDate: json['paidDate']?.toString(),
      paidReference: json['paidReference']?.toString(),
      paidBy: json['paidBy']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestNo': requestNo,
      'requestType': requestType,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'payeePartnerId': payeePartnerId,
      'payeeName': payeeName,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'bankName': bankName,
      'accountHolder': accountHolder,
      'accountNumber': accountNumber,
      'branchCode': branchCode,
      'accountType': accountType,
      'invoiceNo': invoiceNo,
      'externalReference': externalReference,
      'paymentReason': paymentReason,
      'notes': notes,
      'requestedPaymentDate': requestedPaymentDate,
      'status': status,
      'approvalRequestId': approvalRequestId,
      'paidDate': paidDate,
      'paidReference': paidReference,
      'paidBy': paidBy,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }
}

typedef PaymentRequestSummary = PaymentRequestResponse;
typedef PaymentRequestDetail = PaymentRequestResponse;

class PaymentRequestStatusHistoryEntity {
  final String id;
  final String paymentRequestId;
  final String oldStatus;
  final String newStatus;
  final String? comment;
  final String changedAt;
  final String changedBy;

  PaymentRequestStatusHistoryEntity({
    required this.id,
    required this.paymentRequestId,
    required this.oldStatus,
    required this.newStatus,
    this.comment,
    required this.changedAt,
    required this.changedBy,
  });

  factory PaymentRequestStatusHistoryEntity.fromJson(Map<String, dynamic> json) {
    return PaymentRequestStatusHistoryEntity(
      id: (json['id'] ?? '').toString(),
      paymentRequestId: (json['paymentRequestId'] ?? '').toString(),
      oldStatus: (json['oldStatus'] ?? '').toString(),
      newStatus: (json['newStatus'] ?? '').toString(),
      comment: json['comment']?.toString(),
      changedAt: (json['changedAt'] ?? '').toString(),
      changedBy: (json['changedBy'] ?? '').toString(),
    );
  }
}

class BankReport {
  final String instructionId;
  final String groupStatus;
  final Map<String, dynamic> groupHeader;
  final Map<String, dynamic> originalGroupHeader;
  final List<dynamic> statusReasonInformation;

  BankReport({
    required this.instructionId,
    required this.groupStatus,
    required this.groupHeader,
    required this.originalGroupHeader,
    required this.statusReasonInformation,
  });

  factory BankReport.fromJson(Map<String, dynamic> json) {
    return BankReport(
      instructionId: (json['instructionId'] ?? '').toString(),
      groupStatus: (json['groupStatus'] ?? '').toString(),
      groupHeader: Map<String, dynamic>.from(json['groupHeader'] ?? {}),
      originalGroupHeader: Map<String, dynamic>.from(json['originalGroupHeader'] ?? {}),
      statusReasonInformation: List<dynamic>.from(json['statusReasonInformation'] ?? []),
    );
  }
}
