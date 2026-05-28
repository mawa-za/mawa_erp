import 'package:flutter/material.dart';
import '../models/case_billing_summary.dart';
import '../services/case_management_service.dart';

class CaseBillingTab extends StatefulWidget {
  final String caseId;
  final CaseBillingSummary? billingSummary;
  final VoidCallback onRefresh;

  const CaseBillingTab({
    super.key,
    required this.caseId,
    this.billingSummary,
    required this.onRefresh,
  });

  @override
  State<CaseBillingTab> createState() => _CaseBillingTabState();
}

class _CaseBillingTabState extends State<CaseBillingTab> {
  final CaseManagementService _caseService = CaseManagementService();
  bool _isRecalculating = false;

  Future<void> _recalculate() async {
    setState(() => _isRecalculating = true);
    try {
      await _caseService.recalculateBilling(widget.caseId);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing recalculated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recalculating: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.billingSummary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = widget.billingSummary!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(summary, colorScheme),
          const SizedBox(height: 24),
          _buildSectionTitle('Fees & Time'),
          const SizedBox(height: 12),
          _buildInfoRow('Total Time', '${summary.totalTimeMinutes} minutes'),
          _buildInfoRow('Unbilled Time', '${summary.unbilledTimeMinutes} minutes'),
          _buildInfoRow('Total Fees', summary.totalFeesFormatted),
          _buildInfoRow('Unbilled Fees', summary.unbilledFeesFormatted),
          const Divider(height: 32),
          _buildSectionTitle('Disbursements'),
          const SizedBox(height: 12),
          _buildInfoRow('Total Disbursements', summary.totalDisbursementsFormatted),
          _buildInfoRow('Unbilled Disbursements', summary.unbilledDisbursementsFormatted),
          const Divider(height: 32),
          _buildSectionTitle('Summary'),
          const SizedBox(height: 12),
          _buildInfoRow('Total Billable', summary.totalBillableFormatted, isBold: true),
          _buildInfoRow('Total Billed', summary.totalBilledFormatted),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isRecalculating ? null : _recalculate,
              icon: _isRecalculating 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
              label: const Text('Recalculate Billing'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(CaseBillingSummary summary, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Outstanding Balance',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            summary.balanceFormatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.black : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
