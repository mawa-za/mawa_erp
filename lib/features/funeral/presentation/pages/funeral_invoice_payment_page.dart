import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/invoice_payment_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/utils/formatters.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralInvoicePaymentPage extends StatefulWidget {
  final String invoiceId;

  const FuneralInvoicePaymentPage({super.key, required this.invoiceId});

  @override
  State<FuneralInvoicePaymentPage> createState() => _FuneralInvoicePaymentPageState();
}

class _FuneralInvoicePaymentPageState extends State<FuneralInvoicePaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = FuneralApi();
  bool _isLoading = false;

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.CASH;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = (double.parse(_amountController.text) * 100).toInt();
      final request = InvoicePaymentRequestDto(
        amountCents: amount,
        paymentMethod: _selectedMethod,
        reference: _referenceController.text,
      );

      await _api.capturePayment(widget.invoiceId, request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment captured successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Invoice ID: ${widget.invoiceId}', 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (Rand)',
                        border: OutlineInputBorder(),
                        prefixText: 'R ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PaymentMethod>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: PaymentMethod.values.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.name),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedMethod = v);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('Confirm Payment'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}
