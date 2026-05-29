import 'package:intl/intl.dart';

class CaseTimeEntry {
  final String id;
  final String caseId;
  final String? taskId;
  final DateTime entryDate;
  final String userId;
  final String description;
  final int minutes;
  final int hourlyRateCents;
  final int amountCents;
  final bool billable;
  final bool billed;
  final String? invoiceId;
  final DateTime? createdAt;
  final String? createdBy;

  CaseTimeEntry({
    required this.id,
    required this.caseId,
    this.taskId,
    required this.entryDate,
    required this.userId,
    required this.description,
    required this.minutes,
    required this.hourlyRateCents,
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

  factory CaseTimeEntry.fromJson(Map<String, dynamic> json) {
    return CaseTimeEntry(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      taskId: json['taskId']?.toString(),
      entryDate: _parseDate(json['entryDate']) ?? DateTime.now(),
      userId: (json['userId'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      hourlyRateCents: (json['hourlyRateCents'] as num?)?.toInt() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      billable: json['billable'] ?? true,
      billed: json['billed'] ?? false,
      invoiceId: json['invoiceId']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(symbol: 'R ', locale: 'en_ZA');
    return formatter.format(amountCents / 100);
  }
}

class CreateCaseTimeEntryRequest {
  final String? taskId;
  final DateTime entryDate;
  final String userId;
  final String description;
  final int minutes;
  final int hourlyRateCents;
  final bool billable;

  CreateCaseTimeEntryRequest({
    this.taskId,
    required this.entryDate,
    required this.userId,
    required this.description,
    required this.minutes,
    required this.hourlyRateCents,
    this.billable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'entryDate': DateFormat('yyyy-MM-dd').format(entryDate),
      'userId': userId,
      'description': description,
      'minutes': minutes,
      'hourlyRateCents': hourlyRateCents,
      'billable': billable,
    };
  }
}
