import 'package:intl/intl.dart';

class CaseBillingSummary {
  final String caseId;
  final String caseNo;
  final String title;
  final int totalTimeMinutes;
  final int unbilledTimeMinutes;
  final int totalFeesCents;
  final int unbilledFeesCents;
  final int totalDisbursementsCents;
  final int unbilledDisbursementsCents;
  final int totalBillableCents;
  final int totalBilledCents;
  final int balanceCents;

  CaseBillingSummary({
    required this.caseId,
    required this.caseNo,
    required this.title,
    this.totalTimeMinutes = 0,
    this.unbilledTimeMinutes = 0,
    this.totalFeesCents = 0,
    this.unbilledFeesCents = 0,
    this.totalDisbursementsCents = 0,
    this.unbilledDisbursementsCents = 0,
    this.totalBillableCents = 0,
    this.totalBilledCents = 0,
    this.balanceCents = 0,
  });

  factory CaseBillingSummary.fromJson(Map<String, dynamic> json) {
    return CaseBillingSummary(
      caseId: (json['caseId'] ?? '').toString(),
      caseNo: (json['caseNo'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      totalTimeMinutes: (json['totalTimeMinutes'] as num?)?.toInt() ?? 0,
      unbilledTimeMinutes: (json['unbilledTimeMinutes'] as num?)?.toInt() ?? 0,
      totalFeesCents: (json['totalFeesCents'] as num?)?.toInt() ?? 0,
      unbilledFeesCents: (json['unbilledFeesCents'] as num?)?.toInt() ?? 0,
      totalDisbursementsCents: (json['totalDisbursementsCents'] as num?)?.toInt() ?? 0,
      unbilledDisbursementsCents: (json['unbilledDisbursementsCents'] as num?)?.toInt() ?? 0,
      totalBillableCents: (json['totalBillableCents'] as num?)?.toInt() ?? 0,
      totalBilledCents: (json['totalBilledCents'] as num?)?.toInt() ?? 0,
      balanceCents: (json['balanceCents'] as num?)?.toInt() ?? 0,
    );
  }

  String _formatCents(int cents) {
    return 'R ${(cents / 100).toStringAsFixed(2)}';
  }

  String get formattedTotalFees \u003d\u003e _formatCents(totalFeesCents);
  String get formattedTotalDisbursements \u003d\u003e _formatCents(totalDisbursementsCents);
  String get formattedTotalBillable \u003d\u003e _formatCents(totalBillableCents);
  String get formattedTotalBilled \u003d\u003e _formatCents(totalBilledCents);
  String get formattedBalance \u003d\u003e _formatCents(balanceCents);
  String get formattedUnbilledFees \u003d\u003e _formatCents(unbilledFeesCents);
  String get formattedUnbilledDisbursements \u003d\u003e _formatCents(unbilledDisbursementsCents);
}
