import 'package:flutter/material.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import 'funeral_money_text.dart';

class InvoicePreviewSummaryCard extends StatelessWidget {
  final List<FuneralInvoicePreviewLineDto> lines;

  const InvoicePreviewSummaryCard({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = lines.fold<int>(0, (sum, item) => sum + item.amountCents);
    final societyPortion = lines
        .where((l) => l.entityType == InvoiceEntityType.BURIAL_SOCIETY)
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final familyPortion = lines
        .where((l) => l.entityType == InvoiceEntityType.FAMILY_REP)
        .fold<int>(0, (sum, item) => sum + item.amountCents);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost Split Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.entityName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              line.description,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      FuneralMoneyText(
                        cents: line.amountCents,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 32),
            _buildSummaryRow('Total Funeral Cost', total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildSummaryRow('Approved Cover Total', societyPortion, color: Colors.green, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildSummaryRow('Family Balance Due', familyPortion, color: Colors.red, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int cents, {Color? color, TextStyle? style}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        FuneralMoneyText(cents: cents, style: style?.copyWith(color: color) ?? TextStyle(color: color)),
      ],
    );
  }
}
