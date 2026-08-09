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
  final String? approvalSource;
  final String? approvalReference;
  final bool approvalInherited;
  final String? paymentPurpose;
  final String? debtorAccountId;
  final String? bankIntegration;
  final String? fnbInstructionId;
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
    this.approvalSource,
    this.approvalReference,
    this.approvalInherited = false,
    this.paymentPurpose,
    this.debtorAccountId,
    this.bankIntegration,
    this.fnbInstructionId,
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
  String get instructionId => fnbInstructionId ?? '';

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
      approvalSource: json['approvalSource']?.toString(),
      approvalReference: json['approvalReference']?.toString(),
      approvalInherited: json['approvalInherited'] == true,
      paymentPurpose: json['paymentPurpose']?.toString(),
      debtorAccountId: json['debtorAccountId']?.toString(),
      bankIntegration: json['bankIntegration']?.toString(),
      fnbInstructionId: json['fnbInstructionId']?.toString(),
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
      'approvalSource': approvalSource,
      'approvalReference': approvalReference,
      'approvalInherited': approvalInherited,
      'paymentPurpose': paymentPurpose,
      'debtorAccountId': debtorAccountId,
      'bankIntegration': bankIntegration,
      'fnbInstructionId': fnbInstructionId,
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

class PaymentDisbursementAttempt {
  final String id;
  final String paymentRequestId;
  final int attemptNo;
  final String provider;
  final String status;
  final String? instructionId;
  final String? providerStatus;
  final String? failureCode;
  final String? failureMessage;
  final bool bankReportAvailable;
  final String? bankReportRetrievedAt;
  final String? submittedAt;
  final String? lastCheckedAt;
  final String? completedAt;

  const PaymentDisbursementAttempt({
    required this.id,
    required this.paymentRequestId,
    required this.attemptNo,
    required this.provider,
    required this.status,
    this.instructionId,
    this.providerStatus,
    this.failureCode,
    this.failureMessage,
    this.bankReportAvailable = false,
    this.bankReportRetrievedAt,
    this.submittedAt,
    this.lastCheckedAt,
    this.completedAt,
  });

  factory PaymentDisbursementAttempt.fromJson(Map<String, dynamic> json) {
    return PaymentDisbursementAttempt(
      id: (json['id'] ?? '').toString(),
      paymentRequestId: (json['paymentRequestId'] ?? '').toString(),
      attemptNo: (json['attemptNo'] as num?)?.toInt() ?? 0,
      provider: (json['provider'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      instructionId: json['instructionId']?.toString(),
      providerStatus: json['providerStatus']?.toString(),
      failureCode: json['failureCode']?.toString(),
      failureMessage: json['failureMessage']?.toString(),
      bankReportAvailable: json['bankReportAvailable'] == true,
      bankReportRetrievedAt: json['bankReportRetrievedAt']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
      lastCheckedAt: json['lastCheckedAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
    );
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
  final BankGroupHeader? groupHeader;
  final OriginalGroupHeader? originalGroupHeader;
  final List<StatusReasonInformation> statusReasonInformation;
  final List<OriginalPaymentInformation> originalPaymentInformation;

  BankReport({
    required this.instructionId,
    required this.groupStatus,
    this.groupHeader,
    this.originalGroupHeader,
    required this.statusReasonInformation,
    required this.originalPaymentInformation,
  });

  factory BankReport.fromJson(Map<String, dynamic> json) {
    return BankReport(
      instructionId: (json['instructionId'] ?? '').toString(),
      groupStatus: (json['groupStatus'] ?? '').toString(),
      groupHeader: json['groupHeader'] != null ? BankGroupHeader.fromJson(json['groupHeader']) : null,
      originalGroupHeader: json['originalGroupHeader'] != null ? OriginalGroupHeader.fromJson(json['originalGroupHeader']) : null,
      statusReasonInformation: (json['statusReasonInformation'] as List?)
          ?.map((e) => StatusReasonInformation.fromJson(e))
          .toList() ?? [],
      originalPaymentInformation: (json['originalPaymentInformation'] as List?)
          ?.map((e) => OriginalPaymentInformation.fromJson(e))
          .toList() ?? [],
    );
  }
}

class BankGroupHeader {
  final String? messageId;
  final String? creationDateTime;
  final String? initiatingPartyName;
  final String? initiatingPartyBIC;
  final int? totalNumberOfTransactions;
  final double? totalControlSum;

  BankGroupHeader({
    this.messageId,
    this.creationDateTime,
    this.initiatingPartyName,
    this.initiatingPartyBIC,
    this.totalNumberOfTransactions,
    this.totalControlSum,
  });

  factory BankGroupHeader.fromJson(Map<String, dynamic> json) {
    return BankGroupHeader(
      messageId: json['messageId']?.toString(),
      creationDateTime: json['creationDateTime']?.toString(),
      initiatingPartyName: json['initiatingPartyName']?.toString(),
      initiatingPartyBIC: json['initiatingPartyBIC']?.toString(),
      totalNumberOfTransactions: json['totalNumberOfTransactions'] as int?,
      totalControlSum: (json['totalControlSum'] as num?)?.toDouble(),
    );
  }
}

class OriginalGroupHeader {
  final String? originalMessageId;
  final String? originalCreationDateTime;
  final String? originalInitiatingPartyName;
  final String? originalInitiatingPartyBIC;
  final int? originalTotalNumberOfTransactions;
  final double? originalTotalControlSum;

  OriginalGroupHeader({
    this.originalMessageId,
    this.originalCreationDateTime,
    this.originalInitiatingPartyName,
    this.originalInitiatingPartyBIC,
    this.originalTotalNumberOfTransactions,
    this.originalTotalControlSum,
  });

  factory OriginalGroupHeader.fromJson(Map<String, dynamic> json) {
    return OriginalGroupHeader(
      originalMessageId: json['originalMessageId']?.toString(),
      originalCreationDateTime: json['originalCreationDateTime']?.toString(),
      originalInitiatingPartyName: json['originalInitiatingPartyName']?.toString(),
      originalInitiatingPartyBIC: json['originalInitiatingPartyBIC']?.toString(),
      originalTotalNumberOfTransactions: json['originalTotalNumberOfTransactions'] as int?,
      originalTotalControlSum: (json['originalTotalControlSum'] as num?)?.toDouble(),
    );
  }
}

class StatusReasonInformation {
  final String? reason;
  final String? additionalInformation;

  StatusReasonInformation({this.reason, this.additionalInformation});

  factory StatusReasonInformation.fromJson(Map<String, dynamic> json) {
    return StatusReasonInformation(
      reason: json['reason']?.toString(),
      additionalInformation: json['additionalInformation']?.toString(),
    );
  }
}

class OriginalPaymentInformation {
  final String? originalPaymentInformationId;
  final String? paymentInformationStatus;
  final List<StatusReasonInformation> statusReasonInformation;
  final List<TransactionInfoAndStatus> transactionInfoAndStatus;

  OriginalPaymentInformation({
    this.originalPaymentInformationId,
    this.paymentInformationStatus,
    required this.statusReasonInformation,
    required this.transactionInfoAndStatus,
  });

  factory OriginalPaymentInformation.fromJson(Map<String, dynamic> json) {
    return OriginalPaymentInformation(
      originalPaymentInformationId: json['originalPaymentInformationId']?.toString(),
      paymentInformationStatus: json['paymentInformationStatus']?.toString(),
      statusReasonInformation: (json['statusReasonInformation'] as List?)
          ?.map((e) => StatusReasonInformation.fromJson(e))
          .toList() ?? [],
      transactionInfoAndStatus: (json['transactionInfoAndStatus'] as List?)
          ?.map((e) => TransactionInfoAndStatus.fromJson(e))
          .toList() ?? [],
    );
  }
}

class TransactionInfoAndStatus {
  final String? originalEndToEndId;
  final String? transactionStatus;
  final List<StatusReasonInformation> statusReasonInformation;

  TransactionInfoAndStatus({
    this.originalEndToEndId,
    this.transactionStatus,
    required this.statusReasonInformation,
  });

  factory TransactionInfoAndStatus.fromJson(Map<String, dynamic> json) {
    return TransactionInfoAndStatus(
      originalEndToEndId: json['originalEndToEndId']?.toString(),
      transactionStatus: json['transactionStatus']?.toString(),
      statusReasonInformation: (json['statusReasonInformation'] as List?)
          ?.map((e) => StatusReasonInformation.fromJson(e))
          .toList() ?? [],
    );
  }
}
