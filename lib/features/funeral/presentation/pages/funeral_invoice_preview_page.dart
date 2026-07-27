import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../widgets/invoice_split_summary.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    }
  }

  Future<void> _generateInvoices() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.generateInvoices({'serviceRequestId': widget.serviceRequestId});
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invoices Generated'),
            content: Text('Funeral Service: ${response.funeralServiceId}\nInvoices: ${response.invoiceIds.length}'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (response.invoiceIds.isNotEmpty) {
                    context.push('/funeral/invoice/${response.invoiceIds.first}/payment');
                  } else {
                    context.pop();
                  }
                },
                child: const Text('Proceed to Payments'),
              ),
            ],
          ),
        );
      }
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
