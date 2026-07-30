import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/api_client.dart';
import '../models/invoice_detail.dart';
import '../../partners/models/partner.dart';
import '../services/invoice_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class InvoicePdfPreviewScreen extends StatefulWidget {
  final String? invoiceId;
  final InvoiceDetail? invoice;
  final Partner? partner;

  const InvoicePdfPreviewScreen({
    super.key,
    this.invoiceId,
    this.invoice,
    this.partner,
  }) : assert(invoiceId != null || invoice != null);

  @override
  State<InvoicePdfPreviewScreen> createState() => _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState extends State<InvoicePdfPreviewScreen> {
  InvoiceDetail? _invoice;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _invoice = widget.invoice;
    } else {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient().get('/v2/invoice/${widget.invoiceId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _invoice = InvoiceDetail.fromJson(data);
      } else {
        _error = friendlyErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'The invoice could not be loaded. Please try again.',
        );
      }
    } catch (e) {
      _error = friendlyErrorMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice != null ? 'Invoice ${_invoice!.number}' : 'Invoice Preview'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_invoice == null) {
      return const Center(child: Text('No invoice data available'));
    }

    return PdfPreview(
      build: (format) => InvoiceService().getInvoicePdf(_invoice!.id),
      onPrinted: (context) => _showSnackBar(context, 'Invoice printed'),
      onShared: (context) => _showSnackBar(context, 'Invoice shared'),
      canChangePageFormat: false,
      canChangeOrientation: false,
      previewPageMargin: const EdgeInsets.all(16),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
