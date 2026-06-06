import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/case_trust.dart';
import '../services/case_trust_pdf_service.dart';

class TrustReceiptPreviewDialog extends StatelessWidget {
  final CaseTrustTransaction transaction;

  const TrustReceiptPreviewDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: const Text('Trust Receipt Preview'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => CaseTrustPdfService().generateTrustReceiptPdf(transaction),
                canChangePageFormat: false,
                canChangeOrientation: false,
                previewPageMargin: const EdgeInsets.all(16),
                onPrinted: (context) => _showSnackBar(context, 'Receipt printed'),
                onShared: (context) => _showSnackBar(context, 'Receipt shared'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
