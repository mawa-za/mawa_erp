import 'package:intl/intl.dart';

class CaseBillingSummary {
  final String? caseId;
  final String? caseNo;
  final String? title;
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
    this.caseId,
    this.caseNo,
    this.title,
    required this.totalTimeMinutes,
    required this.unbilledTimeMinutes,
    required this.totalFeesCents,
    required this.unbilledFeesCents,
    required this.totalDisbursementsCents,
    required this.unbilledDisbursementsCents,
    required this.totalBillableCents,
    required this.totalBilledCents,
    required this.balanceCents,
  });

  factory CaseBillingSummary.fromJson(Map<String, dynamic> json) {
    return CaseBillingSummary(
      caseId: json['caseId']?.toString(),
      caseNo: json['caseNo']?.toString(),
      title: json['title']?.toString(),
      totalTimeMinutes: json['totalTimeMinutes'] ?? 0,
      unbilledTimeMinutes: json['unbilledTimeMinutes'] ?? 0,
      totalFeesCents: json['totalFeesCents'] ?? 0,
      unbilledFeesCents: json['unbilledFeesCents'] ?? 0,
      totalDisbursementsCents: json['totalDisbursementsCents'] ?? 0,
      unbilledDisbursementsCents: json['unbilledDisbursementsCents'] ?? 0,
      totalBillableCents: json['totalBillableCents'] ?? 0,
      totalBilledCents: json['totalBilledCents'] ?? 0,
      balanceCents: json['balanceCents'] ?? 0,
    );
  }

  String _formatCents(int cents) {
    final formatter = NumberFormat.currency(symbol: 'R ', decimalDigits: 2);
    return formatter.format(cents / 100);
  }

  String get totalFeesFormatted => _formatCents(totalFeesCents);
  String get unbilledFeesFormatted => _formatCents(unbilledFeesCents);
  String get totalDisbursementsFormatted => _formatCents(totalDisbursementsCents);
  String get unbilledDisbursementsFormatted => _formatCents(unbilledDisbursementsCents);
  String get totalBillableFormatted => _formatCents(totalBillableCents);
  String get totalBilledFormatted => _formatCents(totalBilledCents);
  String get balanceFormatted => _formatCents(balanceCents);
}
