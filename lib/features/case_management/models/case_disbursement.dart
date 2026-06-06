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
  final DateTime? createdAt;
  final String? createdBy;

  CaseDisbursement({
    required this.id,
    required this.caseId,
    required this.disbursementDate,
    required this.disbursementType,
    required this.description,
    required this.amountCents,
    this.billable = true,
    this.billed = false,
    this.invoiceId,
    this.createdAt,
    this.createdBy,
  });

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    if (date is List) {
      if (date.length >= 3) {
        try {
          return DateTime(
            (date[0] as num).toInt(),
            (date[1] as num).toInt(),
            (date[2] as num).toInt(),
            date.length >= 4 ? (date[3] as num).toInt() : 0,
            date.length >= 5 ? (date[4] as num).toInt() : 0,
            date.length >= 6 ? (date[5] as num).toInt() : 0,
          );
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  factory CaseDisbursement.fromJson(Map<String, dynamic> json) {
    return CaseDisbursement(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      disbursementDate: _parseDate(json['disbursementDate']) ?? DateTime.now(),
      disbursementType: (json['disbursementType'] ?? 'OTHER').toString(),
      description: (json['description'] ?? '').toString(),
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      billable: json['billable'] ?? true,
      billed: json['billed'] ?? false,
      invoiceId: json['invoiceId']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'disbursementDate': DateFormat('yyyy-MM-dd').format(disbursementDate),
      'disbursementType': disbursementType,
      'description': description,
      'amountCents': amountCents,
      'billable': billable,
      'billed': billed,
      'invoiceId': invoiceId,
    };
  }

  String get formattedAmount {
    return 'R ${(amountCents / 100).toStringAsFixed(2)}';
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
    this.billable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'disbursementDate': DateFormat('yyyy-MM-dd').format(disbursementDate),
      'disbursementType': disbursementType,
      'description': description,
      'amountCents': amountCents,
      'billable': billable,
    };
  }
}
