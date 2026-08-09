import 'package:flutter/material.dart';

import '../../../invoicing/models/invoice_detail.dart';
import '../../../invoicing/screens/capture_invoice_payment_dialog.dart';
import '../../../invoicing/services/invoice_service.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/utils/formatters.dart';

class FuneralInvoicePaymentPage extends StatefulWidget {
  final String invoiceId;

  const FuneralInvoicePaymentPage({super.key, required this.invoiceId});

  @override
  State<FuneralInvoicePaymentPage> createState() =>
      _FuneralInvoicePaymentPageState();
}

class _FuneralInvoicePaymentPageState extends State<FuneralInvoicePaymentPage> {
  bool _loading = true;
  String? _error;
  InvoiceDetail? _invoice;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await InvoiceService().getInvoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _invoice = InvoiceDetail.fromJson(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(
          error,
          fallback: 'The funeral invoice could not be loaded.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _capturePayment() async {
    final invoice = _invoice;
    if (invoice == null || invoice.balanceCents <= 0) return;

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CaptureInvoicePaymentDialog(invoice: invoice),
    );
    if (result == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment recorded against invoice ${invoice.number} and added to cashup.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Funeral Invoice Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 42, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadInvoice,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildInvoiceCard(colorScheme),
    );
  }

  Widget _buildInvoiceCard(ColorScheme colorScheme) {
    final invoice = _invoice!;
    final canPay = invoice.balanceCents > 0 &&
        ['ISSUED', 'PARTIALLY_PAID', 'OVERDUE'].contains(
          invoice.status.toUpperCase().replaceAll('-', '_'),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.receipt_long_outlined,
                            color: colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice ${invoice.number}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              invoice.customerName,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          invoice.status
                              .replaceAll('_', ' ')
                              .replaceAll('-', ' '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _metric('Invoice total',
                          Formatters.formatCentsAsRand(invoice.totalCents)),
                      _metric('Paid',
                          Formatters.formatCentsAsRand(invoice.paidCents)),
                      _metric('Outstanding',
                          Formatters.formatCentsAsRand(invoice.balanceCents),
                          emphasized: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!canPay)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        invoice.balanceCents <= 0
                            ? 'This invoice is fully paid.'
                            : 'Payment can be captured once the invoice is issued/approved.',
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canPay ? _capturePayment : null,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Capture Invoice Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {bool emphasized = false}) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 20 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
