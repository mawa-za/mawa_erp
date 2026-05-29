import 'package:intl/intl.dart';

class LegalCase {
  final String id;
  final String caseNo;
  final String title;
  final String clientPartnerId;
  final String caseType;
  final String? caseCategory;
  final String? description;
  final String status;
  final String priority;
  final String? assignedTo;
  final DateTime? openedDate;
  final DateTime? closedDate;
  final String? courtName;
  final String? courtCaseNo;
  final String? forumType;
  final DateTime? nextAppearanceDate;
  final String billingType;
  final int hourlyRateCents;
  final int fixedFeeCents;
  final String currency;
  final bool billable;
  final int totalTimeMinutes;
  final int totalFeesCents;
  final int totalDisbursementsCents;
  final int totalBillableCents;
  final int totalBilledCents;
  final int balanceCents;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  LegalCase({
    required this.id,
    required this.caseNo,
    required this.title,
    required this.clientPartnerId,
    required this.caseType,
    this.caseCategory,
    this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.openedDate,
    this.closedDate,
    this.courtName,
    this.courtCaseNo,
    this.forumType,
    this.nextAppearanceDate,
    required this.billingType,
    this.hourlyRateCents = 0,
    this.fixedFeeCents = 0,
    this.currency = 'ZAR',
    this.billable = true,
    this.totalTimeMinutes = 0,
    this.totalFeesCents = 0,
    this.totalDisbursementsCents = 0,
    this.totalBillableCents = 0,
    this.totalBilledCents = 0,
    this.balanceCents = 0,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    if (date is List) {
      if (date.length >= 3) {
        try {
          return DateTime(
            (date[0] as num).toInt(), // year
            (date[1] as num).toInt(), // month
            (date[2] as num).toInt(), // day
            date.length >= 4 ? (date[3] as num).toInt() : 0, // hour
            date.length >= 5 ? (date[4] as num).toInt() : 0, // minute
            date.length >= 6 ? (date[5] as num).toInt() : 0, // second
            date.length >= 7 ? ((date[6] as num).toInt() ~/ 1000000) : 0, // millisecond
          );
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  factory LegalCase.fromJson(Map<String, dynamic> json) {
    return LegalCase(
      id: (json['id'] ?? '').toString(),
      caseNo: (json['caseNo'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      clientPartnerId: (json['clientPartnerId'] ?? '').toString(),
      caseType: (json['caseType'] ?? '').toString(),
      caseCategory: json['caseCategory']?.toString(),
      description: json['description']?.toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      assignedTo: json['assignedTo']?.toString(),
      openedDate: _parseDate(json['openedDate']),
      closedDate: _parseDate(json['closedDate']),
      courtName: json['courtName']?.toString(),
      courtCaseNo: json['courtCaseNo']?.toString(),
      forumType: json['forumType']?.toString(),
      nextAppearanceDate: _parseDate(json['nextAppearanceDate']),
      billingType: (json['billingType'] ?? 'HOURLY').toString(),
      hourlyRateCents: (json['hourlyRateCents'] ?? 0) as int,
      fixedFeeCents: (json['fixedFeeCents'] ?? 0) as int,
      currency: (json['currency'] ?? 'ZAR').toString(),
      billable: json['billable'] ?? true,
      totalTimeMinutes: (json['totalTimeMinutes'] ?? 0) as int,
      totalFeesCents: (json['totalFeesCents'] ?? 0) as int,
      totalDisbursementsCents: (json['totalDisbursementsCents'] ?? 0) as int,
      totalBillableCents: (json['totalBillableCents'] ?? 0) as int,
      totalBilledCents: (json['totalBilledCents'] ?? 0) as int,
      balanceCents: (json['balanceCents'] ?? 0) as int,
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseNo': caseNo,
      'title': title,
      'clientPartnerId': clientPartnerId,
      'caseType': caseType,
      'caseCategory': caseCategory,
      'description': description,
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo,
      'openedDate': openedDate?.toIso8601String(),
      'closedDate': closedDate?.toIso8601String(),
      'courtName': courtName,
      'courtCaseNo': courtCaseNo,
      'forumType': forumType,
      'nextAppearanceDate': nextAppearanceDate?.toIso8601String(),
      'billingType': billingType,
      'hourlyRateCents': hourlyRateCents,
      'fixedFeeCents': fixedFeeCents,
      'currency': currency,
      'billable': billable,
      'totalTimeMinutes': totalTimeMinutes,
      'totalFeesCents': totalFeesCents,
      'totalDisbursementsCents': totalDisbursementsCents,
      'totalBillableCents': totalBillableCents,
      'totalBilledCents': totalBilledCents,
      'balanceCents': balanceCents,
    };
  }

  String get formattedBalance {
    final formatter = NumberFormat.currency(symbol: 'R ', locale: 'en_ZA');
    return formatter.format(balanceCents / 100);
  }
}

class CreateLegalCaseRequest {
  final String title;
  final String clientPartnerId;
  final String caseType;
  final String? caseCategory;
  final String? description;
  final String priority;
  final String? assignedTo;
  final DateTime openedDate;
  final String? courtName;
  final String? courtCaseNo;
  final String? forumType;
  final String billingType;
  final int hourlyRateCents;
  final int fixedFeeCents;
  final bool billable;

  CreateLegalCaseRequest({
    required this.title,
    required this.clientPartnerId,
    required this.caseType,
    this.caseCategory,
    this.description,
    this.priority = 'NORMAL',
    this.assignedTo,
    required this.openedDate,
    this.courtName,
    this.courtCaseNo,
    this.forumType,
    this.billingType = 'HOURLY',
    this.hourlyRateCents = 0,
    this.fixedFeeCents = 0,
    this.billable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'clientPartnerId': clientPartnerId,
      'caseType': caseType,
      'caseCategory': caseCategory,
      'description': description,
      'priority': priority,
      'assignedTo': assignedTo,
      'openedDate': DateFormat('yyyy-MM-dd').format(openedDate),
      'courtName': courtName,
      'courtCaseNo': courtCaseNo,
      'forumType': forumType,
      'billingType': billingType,
      'hourlyRateCents': hourlyRateCents,
      'fixedFeeCents': fixedFeeCents,
      'billable': billable,
    };
  }
}
