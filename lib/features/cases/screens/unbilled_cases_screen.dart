import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';

class UnbilledCasesScreen extends StatefulWidget {
  const UnbilledCasesScreen({super.key});

  @override
  State<UnbilledCasesScreen> createState() => _UnbilledCasesScreenState();
}

class _UnbilledCasesScreenState extends State<UnbilledCasesScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  List<LegalCase> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUnbilledCases();
  }

  Future<void> _fetchUnbilledCases() async {
    setState(() => _isLoading = true);
    try {
      final cases = await _caseService.getUnbilledCases();
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCents(int cents) {
    return NumberFormat.currency(symbol: 'R ', locale: 'en_ZA').format(cents / 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Unbilled Matters', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cases.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cases.length,
                  itemBuilder: (context, index) {
                    final c = _cases[index];
                    return _buildUnbilledCard(c);
                  },
                ),
    );
  }

  Widget _buildUnbilledCard(LegalCase c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => context.push('/cases/${c.id}'),
            title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(c.caseNo, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(_formatCents(c.balanceCents), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactInfo('Fees', _formatCents(c.totalFeesCents)),
                _buildCompactInfo('Disbursements', _formatCents(c.totalDisbursementsCents)),
                ElevatedButton.icon(
                  onPressed: () => _showInvoicePreview(c.id),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                  label: const Text('Preview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showInvoicePreview(String caseId) async {
    try {
      final preview = await _caseService.getInvoicePreview(caseId);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Invoice Preview: ${preview.caseNo}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Entries', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...preview.timeEntries.map((e) => ListTile(
                    dense: true,
                    title: Text(e.description),
                    trailing: Text(_formatCents(e.amountCents)),
                  )),
                  const SizedBox(height: 16),
                  const Text('Disbursements', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...preview.disbursements.map((d) => ListTile(
                    dense: true,
                    title: Text(d.description),
                    trailing: Text(_formatCents(d.amountCents)),
                  )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(_formatCents(preview.totalInvoiceCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                await _caseService.generateInvoice(caseId);
                if (mounted) {
                  Navigator.pop(context);
                  _fetchUnbilledCases();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice generated successfully')));
                }
              },
              child: const Text('Generate Invoice'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No unbilled matters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Everything is up to date.', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
