class CaseTrustBalance {
  final String caseId;
  final String clientPartnerId;
  final String currency;
  final int totalReceivedCents;
  final int totalTransferredCents;
  final int totalRefundedCents;
  final int totalPaidOutCents;
  final int availableBalanceCents;

  CaseTrustBalance({
    required this.caseId,
    required this.clientPartnerId,
    required this.currency,
    required this.totalReceivedCents,
    required this.totalTransferredCents,
    required this.totalRefundedCents,
    required this.totalPaidOutCents,
    required this.availableBalanceCents,
  });

  factory CaseTrustBalance.fromJson(Map<String, dynamic> json) {
    return CaseTrustBalance(
      caseId: (json['caseId'] ?? '').toString(),
      clientPartnerId: (json['clientPartnerId'] ?? '').toString(),
      currency: (json['currency'] ?? 'ZAR').toString(),
      totalReceivedCents: (json['totalReceivedCents'] as num?)?.toInt() ?? 0,
      totalTransferredCents: (json['totalTransferredCents'] as num?)?.toInt() ?? 0,
      totalRefundedCents: (json['totalRefundedCents'] as num?)?.toInt() ?? 0,
      totalPaidOutCents: (json['totalPaidOutCents'] as num?)?.toInt() ?? 0,
      availableBalanceCents: (json['availableBalanceCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class CaseTrustTransaction {
  final String id;
  final String caseId;
  final String clientPartnerId;
  final String transactionNo;
  final String transactionType;
  final String direction;
  final int amountCents;
  final int balanceAfterCents;
  final String? paymentMethod;
  final String? referenceNo;
  final String? bankReference;
  final String? payeeName;
  final String? description;
  final String? relatedInvoiceId;
  final String? relatedReceiptId;
  final String? relatedTransactionId;
  final DateTime? transactionDate;
  final bool reversed;
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? reversalReason;
  final DateTime? createdAt;
  final String? createdBy;

  CaseTrustTransaction({
    required this.id,
    required this.caseId,
    required this.clientPartnerId,
    required this.transactionNo,
    required this.transactionType,
    required this.direction,
    required this.amountCents,
    required this.balanceAfterCents,
    this.paymentMethod,
    this.referenceNo,
    this.bankReference,
    this.payeeName,
    this.description,
    this.relatedInvoiceId,
    this.relatedReceiptId,
    this.relatedTransactionId,
    this.transactionDate,
    required this.reversed,
    this.reversedAt,
    this.reversedBy,
    this.reversalReason,
    this.createdAt,
    this.createdBy,
  });

  factory CaseTrustTransaction.fromJson(Map<String, dynamic> json) {
    return CaseTrustTransaction(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      clientPartnerId: (json['clientPartnerId'] ?? '').toString(),
      transactionNo: (json['transactionNo'] ?? '').toString(),
      transactionType: (json['transactionType'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      balanceAfterCents: (json['balanceAfterCents'] as num?)?.toInt() ?? 0,
      paymentMethod: json['paymentMethod']?.toString(),
      referenceNo: json['referenceNo']?.toString(),
      bankReference: json['bankReference']?.toString(),
      payeeName: json['payeeName']?.toString(),
      description: json['description']?.toString(),
      relatedInvoiceId: json['relatedInvoiceId']?.toString(),
      relatedReceiptId: json['relatedReceiptId']?.toString(),
      relatedTransactionId: json['relatedTransactionId']?.toString(),
      transactionDate: json['transactionDate'] != null ? DateTime.tryParse(json['transactionDate']) : null,
      reversed: json['reversed'] ?? false,
      reversedAt: json['reversedAt'] != null ? DateTime.tryParse(json['reversedAt']) : null,
      reversedBy: json['reversedBy']?.toString(),
      reversalReason: json['reversalReason']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
    );
  }
}

class CaseTrustReceiptRequest {
  final int amountCents;
  final String paymentMethod;
  final String referenceNo;
  final String? bankReference;
  final String? description;
  final String? receivedBy;
  final DateTime transactionDate;

  CaseTrustReceiptRequest({
    required this.amountCents,
    required this.paymentMethod,
    required this.referenceNo,
    this.bankReference,
    this.description,
    this.receivedBy,
    required this.transactionDate,
  });

  Map<String, dynamic> toJson() => {
    'amountCents': amountCents,
    'paymentMethod': paymentMethod,
    'referenceNo': referenceNo,
    'bankReference': bankReference,
    'description': description,
    'receivedBy': receivedBy,
    'transactionDate': transactionDate.toIso8601String(),
  };
}

class CaseTrustBusinessTransferRequest {
  final int amountCents;
  final String? relatedInvoiceId;
  final String? description;
  final String? transferredBy;

  CaseTrustBusinessTransferRequest({
    required this.amountCents,
    this.relatedInvoiceId,
    this.description,
    this.transferredBy,
  });

  Map<String, dynamic> toJson() => {
    'amountCents': amountCents,
    'relatedInvoiceId': relatedInvoiceId,
    'description': description,
    'transferredBy': transferredBy,
  };
}

class CaseTrustRefundRequest {
  final int amountCents;
  final String paymentMethod;
  final String? referenceNo;
  final String? bankReference;
  final String? description;
  final String? refundedBy;

  CaseTrustRefundRequest({
    required this.amountCents,
    required this.paymentMethod,
    this.referenceNo,
    this.bankReference,
    this.description,
    this.refundedBy,
  });

  Map<String, dynamic> toJson() => {
    'amountCents': amountCents,
    'paymentMethod': paymentMethod,
    'referenceNo': referenceNo,
    'bankReference': bankReference,
    'description': description,
    'refundedBy': refundedBy,
  };
}

class CaseTrustThirdPartyPaymentRequest {
  final int amountCents;
  final String payeeName;
  final String paymentMethod;
  final String? bankReference;
  final String? referenceNo;
  final String? description;
  final String? paidBy;
  final bool createDisbursement;
  final String? disbursementType;
  final bool billableDisbursement;

  CaseTrustThirdPartyPaymentRequest({
    required this.amountCents,
    required this.payeeName,
    required this.paymentMethod,
    this.bankReference,
    this.referenceNo,
    this.description,
    this.paidBy,
    this.createDisbursement = false,
    this.disbursementType,
    this.billableDisbursement = false,
  });

  Map<String, dynamic> toJson() => {
    'amountCents': amountCents,
    'payeeName': payeeName,
    'paymentMethod': paymentMethod,
    'bankReference': bankReference,
    'referenceNo': referenceNo,
    'description': description,
    'paidBy': paidBy,
    'createDisbursement': createDisbursement,
    'disbursementType': disbursementType,
    'billableDisbursement': billableDisbursement,
  };
}

class CaseTrustReverseTransactionRequest {
  final String reversalReason;
  final String? reversedBy;

  CaseTrustReverseTransactionRequest({
    required this.reversalReason,
    this.reversedBy,
  });

  Map<String, dynamic> toJson() => {
    'reversalReason': reversalReason,
    'reversedBy': reversedBy,
  };
}
