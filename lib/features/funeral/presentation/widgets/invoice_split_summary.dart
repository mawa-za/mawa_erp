import 'package:flutter/material.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/utils/formatters.dart';

class InvoiceSplitSummary extends StatelessWidget {
  final List<FuneralInvoicePreviewLineDto> lines;
  final ValueChanged<String>? onInvoiceTap;

  const InvoiceSplitSummary({
    super.key,
    required this.lines,
    this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<int>(0, (sum, item) => sum + item.amountCents);
    final approvedCover = lines
        .where((l) =>
            l.entityType == InvoiceEntityType.BURIAL_SOCIETY ||
            l.entityType == InvoiceEntityType.GROUP_SOCIETY)
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final familyBalance = lines
        .where((l) => l.entityType == InvoiceEntityType.FAMILY_REP)
        .fold<int>(0, (sum, item) => sum + item.amountCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invoice Split Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        ...lines.map((line) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.entityName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          line.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (line.invoiceId != null && line.invoiceId!.isNotEmpty)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onInvoiceTap == null
                                ? null
                                : () => onInvoiceTap!(line.invoiceId!),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    line.invoiceNo?.isNotEmpty == true
                                        ? line.invoiceNo!
                                        : 'Open invoice',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (line.invoiceStatus?.isNotEmpty == true) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      line.invoiceStatus!.replaceAll('_', ' '),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            'Invoice will be created when final invoices are generated.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    Formatters.formatCentsAsRand(line.amountCents),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
