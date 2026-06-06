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
      hourlyRateCents: (json['hourlyRateCents'] as num?)?.toInt() ?? 0,
      fixedFeeCents: (json['fixedFeeCents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] ?? 'ZAR').toString(),
      billable: json['billable'] ?? true,
      totalTimeMinutes: (json['totalTimeMinutes'] as num?)?.toInt() ?? 0,
      totalFeesCents: (json['totalFeesCents'] as num?)?.toInt() ?? 0,
      totalDisbursementsCents: (json['totalDisbursementsCents'] as num?)?.toInt() ?? 0,
      totalBillableCents: (json['totalBillableCents'] as num?)?.toInt() ?? 0,
      totalBilledCents: (json['totalBilledCents'] as num?)?.toInt() ?? 0,
      balanceCents: (json['balanceCents'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
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
