import 'case_time_entry.dart';
import 'case_disbursement.dart';

class CaseInvoicePreview {
  final String caseId;
  final String caseNo;
  final String title;
  final String clientPartnerId;
  final List<CaseTimeEntry> timeEntries;
  final List<CaseDisbursement> disbursements;
  final int totalFeesCents;
  final int totalDisbursementsCents;
  final int totalInvoiceCents;

  CaseInvoicePreview({
    required this.caseId,
    required this.caseNo,
    required this.title,
    required this.clientPartnerId,
    required this.timeEntries,
    required this.disbursements,
    required this.totalFeesCents,
    required this.totalDisbursementsCents,
    required this.totalInvoiceCents,
  });

  factory CaseInvoicePreview.fromJson(Map<String, dynamic> json) {
    return CaseInvoicePreview(
      caseId: (json['caseId'] ?? '').toString(),
      caseNo: (json['caseNo'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      clientPartnerId: (json['clientPartnerId'] ?? '').toString(),
      timeEntries: (json['timeEntries'] as List? ?? [])
          .map((e) => CaseTimeEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      disbursements: (json['disbursements'] as List? ?? [])
          .map((e) => CaseDisbursement.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalFeesCents: (json['totalFeesCents'] as num?)?.toInt() ?? 0,
      totalDisbursementsCents: (json['totalDisbursementsCents'] as num?)?.toInt() ?? 0,
      totalInvoiceCents: (json['totalInvoiceCents'] as num?)?.toInt() ?? 0,
    );
  }
}
