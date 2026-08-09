import 'package:flutter/material.dart';
import '../models/case_billing_summary.dart';

class CaseBillingCards extends StatelessWidget {
  final CaseBillingSummary summary;

  const CaseBillingCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 6 : (constraints.maxWidth > 800 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 1200 ? 1.8 : 2.2,
          children: [
            _buildSummaryCard('Total Time', '${summary.totalTimeMinutes}m', Colors.blueGrey, Icons.timer_outlined),
            _buildSummaryCard('Total Fees', summary.formattedTotalFees, Colors.blue, Icons.payments_outlined),
            _buildSummaryCard('Disbursements', summary.formattedTotalDisbursements, Colors.orange, Icons.receipt_long_outlined),
            _buildSummaryCard('Total Billable', summary.formattedTotalBillable, const Color(0xFFF20D1A), Icons.summarize_outlined),
            _buildSummaryCard('Total Billed', summary.formattedTotalBilled, Colors.green, Icons.check_circle_outline_rounded),
            _buildSummaryCard('Outstanding', summary.formattedBalance, Colors.red, Icons.account_balance_wallet_outlined),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
