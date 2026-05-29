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

  factory CaseTimeEntry.fromJson(Map<String, dynamic> json) {
    return CaseTimeEntry(
      id: json['id'] ?? '',
      caseId: json['caseId'] ?? '',
      taskId: json['taskId'],
      entryDate: _parseDate(json['entryDate']) ?? DateTime.now(),
      userId: json['userId'] ?? '',
      description: json['description'] ?? '',
      minutes: json['minutes'] ?? 0,
      hourlyRateCents: json['hourlyRateCents'] ?? 0,
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
      'taskId': taskId,
      'entryDate': DateFormat('yyyy-MM-dd').format(entryDate),
      'userId': userId,
      'description': description,
      'minutes': minutes,
      'hourlyRateCents': hourlyRateCents,
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
