import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../data/models/generate_funeral_invoices_response_dto.dart';
import '../widgets/invoice_split_summary.dart';

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
      final claims = await _api.getClaims(widget.serviceRequestId);
      
      // In a production app, we would call the preview endpoint here.
      // Since it requires a full request DTO, we might need to fetch the service request first.
      
      setState(() {
        _claims = claims;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _generateInvoices() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.generateInvoices({'funeralServiceId': widget.serviceRequestId});
      if (mounted) {
        await _showGeneratedInvoices(response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _showGeneratedInvoices(GenerateFuneralInvoicesResponseDto response) async {
    final invoices = response.invoices;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invoices Generated'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Funeral Service: ${response.funeralServiceId}'),
              const SizedBox(height: 8),
              Text('Invoices: ${response.invoiceIds.length}'),
              const SizedBox(height: 16),
              if (invoices.isEmpty)
                const Text('Open the generated invoices from the Invoice module.')
              else
                ...invoices.map(
                  (invoice) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(invoice.invoiceNo.isEmpty ? invoice.invoiceId : invoice.invoiceNo),
                    subtitle: Text('Total: ${_formatCents(invoice.totalCents)} • ${invoice.status}'),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.push('/invoices/${invoice.invoiceId}/preview');
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (response.invoiceIds.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open First Invoice'),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/invoices/${response.invoiceIds.first}/preview');
              },
            ),
        ],
      ),
    );
  }

  String _formatCents(int cents) => 'R${(cents / 100).toStringAsFixed(2)}';

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
                  
                  InvoiceSplitSummary(lines: _previewLines),
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: hasPendingClaims ? null : _generateInvoices,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Generate Final Invoices'),
                  ),
                ],
              ),
            ),
    );
  }
}
