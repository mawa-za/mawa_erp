import 'package:intl/intl.dart';

class CaseDisbursement {
  final String id;
  final String caseId;
  final DateTime disbursementDate;
  final String disbursementType;
  final String description;
  final int amountCents;
  final bool billable;
  final bool billed;
  final String? invoiceId;
  final DateTime createdAt;
  final String? createdBy;

  CaseDisbursement({
    required this.id,
    required this.caseId,
    required this.disbursementDate,
    required this.disbursementType,
    required this.description,
    required this.amountCents,
    required this.billable,
    required this.billed,
    this.invoiceId,
    required this.createdAt,
    this.createdBy,
  });

  factory CaseDisbursement.fromJson(Map<String, dynamic> json) {
    return CaseDisbursement(
      id: json['id']?.toString() ?? '',
      caseId: json['caseId']?.toString() ?? '',
      disbursementDate: json['disbursementDate'] != null ? DateTime.parse(json['disbursementDate']) : (json['date'] != null ? DateTime.parse(json['date']) : DateTime.now()),
      disbursementType: json['disbursementType']?.toString() ?? json['type']?.toString() ?? 'OTHER',
      description: json['description']?.toString() ?? '',
      amountCents: json['amountCents'] ?? 0,
      billable: json['billable'] ?? true,
      billed: json['billed'] ?? false,
      invoiceId: json['invoiceId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'disbursementDate': disbursementDate.toIso8601String(),
      'disbursementType': disbursementType,
      'description': description,
      'amountCents': amountCents,
      'billable': billable,
      'billed': billed,
      'invoiceId': invoiceId,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  String get amountFormatted {
    final formatter = NumberFormat.currency(symbol: 'R ', decimalDigits: 2);
    return formatter.format(amountCents / 100);
  }
}

class CreateCaseDisbursementRequest {
  final DateTime disbursementDate;
  final String disbursementType;
  final String description;
  final int amountCents;
  final bool billable;

  CreateCaseDisbursementRequest({
    required this.disbursementDate,
    required this.disbursementType,
    required this.description,
    required this.amountCents,
    required this.billable,
  });

  Map<String, dynamic> toJson() {
    return {
      'disbursementDate': disbursementDate.toIso8601String(),
      'disbursementType': disbursementType,
      'description': description,
      'amountCents': amountCents,
      'billable': billable,
    };
  }
}
