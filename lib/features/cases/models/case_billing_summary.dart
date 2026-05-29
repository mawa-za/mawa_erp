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
      caseId: json['caseId'] ?? '',
      caseNo: json['caseNo'] ?? '',
      title: json['title'] ?? '',
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
    final formatter = NumberFormat.currency(symbol: 'R ', locale: 'en_ZA');
    return formatter.format(cents / 100);
  }

  String get formattedTotalFees => _formatCents(totalFeesCents);
  String get formattedTotalDisbursements => _formatCents(totalDisbursementsCents);
  String get formattedTotalBillable => _formatCents(totalBillableCents);
  String get formattedTotalBilled => _formatCents(totalBilledCents);
  String get formattedBalance => _formatCents(balanceCents);
  String get formattedUnbilledFees => _formatCents(unbilledFeesCents);
  String get formattedUnbilledDisbursements => _formatCents(unbilledDisbursementsCents);
}
