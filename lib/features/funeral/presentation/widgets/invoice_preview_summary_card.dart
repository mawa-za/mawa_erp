import 'package:flutter/material.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_enums.dart';
import 'funeral_money_text.dart';

class InvoicePreviewSummaryCard extends StatelessWidget {
  final List<FuneralInvoicePreviewLineDto> lines;
  final ValueChanged<String>? onInvoiceTap;

  const InvoicePreviewSummaryCard({
    super.key,
    required this.lines,
    this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = lines.fold<int>(0, (sum, item) => sum + item.amountCents);
    final societyPortion = lines
        .where((l) =>
            l.entityType == InvoiceEntityType.BURIAL_SOCIETY ||
            l.entityType == InvoiceEntityType.GROUP_SOCIETY)
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
                            if (line.invoiceId != null && line.invoiceId!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: onInvoiceTap == null
                                    ? null
                                    : () => onInvoiceTap!(line.invoiceId!),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 15,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        line.invoiceNo?.isNotEmpty == true
                                            ? line.invoiceNo!
                                            : 'Open invoice',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      if (line.invoiceStatus?.isNotEmpty == true) ...[
                                        const SizedBox(width: 7),
                                        Text(
                                          line.invoiceStatus!.replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
