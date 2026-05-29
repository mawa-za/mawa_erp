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
        return DateTime(
          date[0], // year
          date[1], // month
          date[2], // day
          date.length >= 4 ? date[3] : 0, // hour
          date.length >= 5 ? date[4] : 0, // minute
          date.length >= 6 ? date[5] : 0, // second
          date.length >= 7 ? (date[6] ~/ 1000000) : 0, // millisecond
        );
      }
    }
    return null;
  }

  factory CaseDisbursement.fromJson(Map<String, dynamic> json) {
    return CaseDisbursement(
      id: json['id'] ?? '',
      caseId: json['caseId'] ?? '',
      disbursementDate: _parseDate(json['disbursementDate']) ?? DateTime.now(),
      disbursementType: json['disbursementType'] ?? 'OTHER',
      description: json['description'] ?? '',
      amountCents: json['amountCents'] ?? 0,
      billable: json['billable'] ?? true,
      billed: json['billed'] ?? false,
      invoiceId: json['invoiceId'],
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy'],
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
    final formatter = NumberFormat.currency(symbol: 'R ', locale: 'en_ZA');
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
