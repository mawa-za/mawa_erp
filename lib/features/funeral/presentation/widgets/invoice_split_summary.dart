import 'package:flutter/material.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/utils/formatters.dart';

class InvoiceSplitSummary extends StatelessWidget {
  final List<FuneralInvoicePreviewLineDto> lines;

  const InvoiceSplitSummary({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<int>(0, (sum, item) => sum + item.amountCents);
    final approvedCover = lines
        .where((l) => l.entityType == InvoiceEntityType.BURIAL_SOCIETY)
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final familyBalance = lines
        .where((l) => l.entityType == InvoiceEntityType.FAMILY_REP)
        .fold<int>(0, (sum, item) => sum + item.amountCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invoice Split Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.entityName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(line.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(Formatters.formatCentsAsRand(line.amountCents)),
                ],
              ),
            )),
        const Divider(height: 32),
        _buildTotalRow('Total Funeral Cost', total, isBold: true),
        _buildTotalRow('Total Approved Cover', approvedCover, color: Colors.green),
        _buildTotalRow('Family Balance Due', familyBalance, color: Colors.red, isBold: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, int amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            Formatters.formatCentsAsRand(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
