import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_invoice_preview_request_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../widgets/invoice_split_summary.dart';
import '../../../invoicing/screens/invoice_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralInvoicePreviewPage extends StatefulWidget {
  final String serviceRequestId;

  const FuneralInvoicePreviewPage({super.key, required this.serviceRequestId});

  @override
  State<FuneralInvoicePreviewPage> createState() => _FuneralInvoicePreviewPageState();
}

class _FuneralInvoicePreviewPageState extends State<FuneralInvoicePreviewPage> {
  final _api = FuneralApi();
  List<FuneralInvoicePreviewLineDto> _previewLines = [];
  List<FuneralClaimDto> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getClaims(widget.serviceRequestId),
        _api.getInvoicePreview(
          FuneralInvoicePreviewRequestDto(
            funeralServiceId: widget.serviceRequestId,
          ),
        ),
      ]);

      setState(() {
        _claims = results[0] as List<FuneralClaimDto>;
        _previewLines = results[1] as List<FuneralInvoicePreviewLineDto>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    }
  }

  Future<void> _generateInvoices() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.generateInvoices({
        'funeralServiceId': widget.serviceRequestId,
      });
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Final Invoices Ready'),
          content: Text(
            '${response.invoiceIds.length} invoice(s) are ready. Existing invoices were updated instead of duplicated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay on Preview'),
            ),
            if (response.invoiceIds.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/funeral/invoice/${response.invoiceIds.first}/payment');
                },
                child: const Text('Proceed to Payments'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingClaims = _claims.any((c) => c.status == ClaimStatus.PENDING);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (hasPendingClaims)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Some claims are still pending. Final invoices should only be generated after claim approval.',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  InvoiceSplitSummary(
                    lines: _previewLines,
                    onInvoiceTap: (invoiceId) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
                        ),
                      );
                      if (mounted) await _loadData();
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: hasPendingClaims ? null : _generateInvoices,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: Icon(
                      _previewLines.any(
                        (line) => line.invoiceId == null || line.invoiceId!.isEmpty,
                      )
                          ? Icons.receipt_long_outlined
                          : Icons.sync_rounded,
                    ),
                    label: Text(
                      _previewLines.any(
                        (line) => line.invoiceId == null || line.invoiceId!.isEmpty,
                      )
                          ? 'Generate Final Invoices'
                          : 'Update Final Invoices',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
