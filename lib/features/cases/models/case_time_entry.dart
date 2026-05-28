import 'package:intl/intl.dart';

class CaseTimeEntry {
  final String id;
  final String caseId;
  final String? taskId;
  final DateTime entryDate;
  final String userId;
  final String? userName;
  final String description;
  final int minutes;
  final int hourlyRateCents;
  final int amountCents;
  final bool billable;
  final bool billed;
  final String? invoiceId;
  final DateTime createdAt;
  final String? createdBy;

  CaseTimeEntry({
    required this.id,
    required this.caseId,
    this.taskId,
    required this.entryDate,
    required this.userId,
    this.userName,
    required this.description,
    required this.minutes,
    required this.hourlyRateCents,
    required this.amountCents,
    required this.billable,
    required this.billed,
    this.invoiceId,
    required this.createdAt,
    this.createdBy,
  });

  factory CaseTimeEntry.fromJson(Map<String, dynamic> json) {
    return CaseTimeEntry(
      id: json['id']?.toString() ?? '',
      caseId: json['caseId']?.toString() ?? '',
      taskId: json['taskId']?.toString(),
      entryDate: json['entryDate'] != null ? DateTime.parse(json['entryDate']) : DateTime.now(),
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString(),
      description: json['description']?.toString() ?? '',
      minutes: json['minutes'] ?? 0,
      hourlyRateCents: json['hourlyRateCents'] ?? 0,
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
      'taskId': taskId,
      'entryDate': entryDate.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'description': description,
      'minutes': minutes,
      'hourlyRateCents': hourlyRateCents,
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
    required this.billable,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'entryDate': entryDate.toIso8601String(),
      'userId': userId,
      'description': description,
      'minutes': minutes,
      'hourlyRateCents': hourlyRateCents,
      'billable': billable,
    };
  }
}
