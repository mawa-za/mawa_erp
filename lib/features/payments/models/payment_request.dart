class PaymentRequestSummary {
  final String id;
  final String recipient;
  final String paymentReason;
  final String reference;
  final double amount;
  final String dueDate;
  final String paymentMethod;
  final String status;
  final String transactionNumber;
  final String dateCreated;

  PaymentRequestSummary({
    required this.id,
    required this.recipient,
    required this.paymentReason,
    required this.reference,
    required this.amount,
    required this.dueDate,
    required this.paymentMethod,
    required this.status,
    required this.transactionNumber,
    required this.dateCreated,
  });

  factory PaymentRequestSummary.fromJson(Map<String, dynamic> json) {
    return PaymentRequestSummary(
      id: json['id'] ?? '',
      recipient: json['recipient'] ?? '',
      paymentReason: json['paymentReason'] ?? '',
      reference: json['reference'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      dueDate: json['dueDate'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
      status: json['status'] ?? '',
      transactionNumber: json['transactionNumber'] ?? '',
      dateCreated: json['dateCreated'] ?? '',
    );
  }
}

class PaymentRequestDetail {
  final String id;
  final String number;
  final String reference;
  final double amount;
  final String dueDate;
  final String createdDate;
  final String instructionId;
  final String status; // Added status
  final Map<String, dynamic> paymentReason;
  final Map<String, dynamic> paymentMethod;
  final Map<String, dynamic> branch;
  final Map<String, dynamic> createdBy;
  final Map<String, dynamic> recipient;
  final Map<String, dynamic>? employeeResponsible;

  PaymentRequestDetail({
    required this.id,
    required this.number,
    required this.reference,
    required this.amount,
    required this.dueDate,
    required this.createdDate,
    required this.instructionId,
    required this.status,
    required this.paymentReason,
    required this.paymentMethod,
    required this.branch,
    required this.createdBy,
    required this.recipient,
    this.employeeResponsible,
  });

  factory PaymentRequestDetail.fromJson(Map<String, dynamic> json) {
    return PaymentRequestDetail(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      reference: json['reference'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      dueDate: json['dueDate'] ?? '',
      createdDate: json['createdDate'] ?? '',
      instructionId: json['instructionId'] ?? '',
      status: json['status'] ?? 'NEW',
      paymentReason: json['paymentReason'] ?? {},
      paymentMethod: json['paymentMethod'] ?? {},
      branch: json['branch'] ?? {},
      createdBy: json['createdBy'] ?? {},
      recipient: json['recipient'] ?? {},
      employeeResponsible: json['employeeResponsible'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'reference': reference,
      'amount': amount,
      'dueDate': dueDate,
      'createdDate': createdDate,
      'status': status,
      'recipient': recipient,
    };
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
      instructionId: json['instructionId'] ?? '',
      groupStatus: json['groupStatus'] ?? '',
      groupHeader: json['groupHeader'] ?? {},
      originalGroupHeader: json['originalGroupHeader'] ?? {},
      statusReasonInformation: json['statusReasonInformation'] ?? [],
    );
  }
}
