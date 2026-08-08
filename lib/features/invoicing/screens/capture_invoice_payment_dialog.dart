import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_error.dart';
import '../../membership/models/payment_batch_response.dart';
import '../../settings/services/pos_printing_service.dart';
import '../models/invoice_detail.dart';
import '../services/invoice_service.dart';

class CaptureInvoicePaymentDialog extends StatefulWidget {
  final InvoiceDetail invoice;

  const CaptureInvoicePaymentDialog({
    super.key,
    required this.invoice,
  });

  @override
  State<CaptureInvoicePaymentDialog> createState() =>
      _CaptureInvoicePaymentDialogState();
}

class _CaptureInvoicePaymentDialogState
    extends State<CaptureInvoicePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'CASH';
  DateTime _paymentDate = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.invoice.balanceAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
      initialDate: _paymentDate,
    );
    if (selected != null) setState(() => _paymentDate = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'unknown';
      final amountCents =
          (double.parse(_amountController.text.trim().replaceAll(',', '.')) * 100)
              .round();

      final response = await InvoiceService().capturePayment(
        widget.invoice.id,
        {
          'amountCents': amountCents,
          'paymentDate': DateFormat('yyyy-MM-dd').format(_paymentDate),
          'paymentMethod': _paymentMethod,
          'reference': _referenceController.text.trim(),
          'notes': _notesController.text.trim(),
          'createdBy': userId,
          'employeeResponsible': userId,
          'deviceId': prefs.getString('deviceId') ?? 'ERP-ONLINE',
          'terminalId': prefs.getString('terminalId'),
          'location': prefs.getString('location'),
        },
      );

      await _queueReceipt(response);
      if (mounted) Navigator.of(context).pop(response);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Payment failed: $error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _queueReceipt(PaymentBatchResponse response) async {
    if (response.receipts.isEmpty) return;
    final failures = <String>[];
    for (final receipt in response.receipts) {
      try {
        await PosPrintingService().queueReceipt(receipt.id);
      } catch (_) {
        failures.add(receipt.receiptNo);
      }
    }
    if (failures.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment recorded, but ${failures.length} receipt(s) could not be queued for printing.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payments_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('Capture payment • ${widget.invoice.number}')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(.32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _fact('Invoice', widget.invoice.number),
                      _fact('Customer', widget.invoice.customerName),
                      _fact(
                        'Outstanding',
                        'R ${widget.invoice.balanceAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'R ',
                    helperText:
                        'Maximum R ${widget.invoice.balanceAmount.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (amount == null || amount <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    if ((amount * 100).round() > widget.invoice.balanceCents) {
                      return 'Amount exceeds the outstanding invoice balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(value: 'EFT', child: Text('EFT')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _paymentMethod = value!),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A posted receipt will be created, allocated to this invoice '
                  'and included in the normal ERP online cashup.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_outlined),
          label: Text(_submitting ? 'Recording...' : 'Record & Print'),
        ),
      ],
    );
  }

  Widget _fact(String label, String value) => SizedBox(
        width: 135,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
