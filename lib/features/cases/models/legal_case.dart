import 'package:intl/intl.dart';

class LegalCase {
  final String id;
  final String caseNo;
  final String title;
  final String? clientPartnerId;
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

  // Extra fields for UI if provided by API
  final String? clientPartnerName;
  final String? assignedToName;

  LegalCase({
    required this.id,
    required this.caseNo,
    required this.title,
    this.clientPartnerId,
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
    required this.hourlyRateCents,
    required this.fixedFeeCents,
    required this.currency,
    required this.billable,
    required this.totalTimeMinutes,
    required this.totalFeesCents,
    required this.totalDisbursementsCents,
    required this.totalBillableCents,
    required this.totalBilledCents,
    required this.balanceCents,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientPartnerName,
    this.assignedToName,
  });

  factory LegalCase.fromJson(Map<String, dynamic> json) {
    return LegalCase(
      id: json['id']?.toString() ?? '',
      caseNo: json['caseNo']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      clientPartnerId: json['clientPartnerId']?.toString(),
      caseType: json['caseType']?.toString() ?? 'OTHER',
      caseCategory: json['caseCategory']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'OPEN',
      priority: json['priority']?.toString() ?? 'NORMAL',
      assignedTo: json['assignedTo']?.toString(),
      openedDate: json['openedDate'] != null ? DateTime.tryParse(json['openedDate']) : null,
      closedDate: json['closedDate'] != null ? DateTime.tryParse(json['closedDate']) : null,
      courtName: json['courtName']?.toString(),
      courtCaseNo: json['courtCaseNo']?.toString(),
      forumType: json['forumType']?.toString(),
      nextAppearanceDate: json['nextAppearanceDate'] != null ? DateTime.tryParse(json['nextAppearanceDate']) : null,
      billingType: json['billingType']?.toString() ?? 'HOURLY',
      hourlyRateCents: json['hourlyRateCents'] ?? 0,
      fixedFeeCents: json['fixedFeeCents'] ?? 0,
      currency: json['currency']?.toString() ?? 'ZAR',
      billable: json['billable'] ?? true,
      totalTimeMinutes: json['totalTimeMinutes'] ?? 0,
      totalFeesCents: json['totalFeesCents'] ?? 0,
      totalDisbursementsCents: json['totalDisbursementsCents'] ?? 0,
      totalBillableCents: json['totalBillableCents'] ?? 0,
      totalBilledCents: json['totalBilledCents'] ?? 0,
      balanceCents: json['balanceCents'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      updatedBy: json['updatedBy']?.toString(),
      clientPartnerName: json['clientPartnerName']?.toString(),
      assignedToName: json['assignedToName']?.toString(),
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
      'createdAt': createdAt?.toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  String get balanceFormatted {
    final formatter = NumberFormat.currency(symbol: 'R ', decimalDigits: 2);
    return formatter.format(balanceCents / 100);
  }
}

class CreateLegalCaseRequest {
  final String title;
  final String clientPartnerId;
  final String caseType;
  final String? caseCategory;
  final String? description;
  final String status;
  final String priority;
  final String? assignedTo;
  final DateTime? openedDate;
  final String? courtName;
  final String? courtCaseNo;
  final String? forumType;
  final String billingType;
  final int hourlyRateCents;
  final int fixedFeeCents;
  final String currency;
  final bool billable;

  CreateLegalCaseRequest({
    required this.title,
    required this.clientPartnerId,
    required this.caseType,
    this.caseCategory,
    this.description,
    this.status = 'OPEN',
    required this.priority,
    this.assignedTo,
    this.openedDate,
    this.courtName,
    this.courtCaseNo,
    this.forumType,
    required this.billingType,
    this.hourlyRateCents = 0,
    this.fixedFeeCents = 0,
    this.currency = 'ZAR',
    this.billable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'clientPartnerId': clientPartnerId,
      'caseType': caseType,
      'caseCategory': caseCategory,
      'description': description,
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo,
      'openedDate': openedDate?.toIso8601String(),
      'courtName': courtName,
      'courtCaseNo': courtCaseNo,
      'forumType': forumType,
      'billingType': billingType,
      'hourlyRateCents': hourlyRateCents,
      'fixedFeeCents': fixedFeeCents,
      'currency': currency,
      'billable': billable,
    };
  }
}
