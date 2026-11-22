import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mawa_erp/core/api_client.dart';
import 'package:mawa_erp/core/widgets/partner_search_dropdown.dart';
import 'package:mawa_erp/features/partners/models/partner.dart';

/// Finance review ledger. No payment or credit is ever inferred from billing
/// status; posting to ERP is a separate authorised operation.
class PlatformBillingRevenueScreen extends StatefulWidget {
  const PlatformBillingRevenueScreen({super.key});

  @override
  State<PlatformBillingRevenueScreen> createState() => _PlatformBillingRevenueScreenState();
}

class _PlatformBillingRevenueScreenState extends State<PlatformBillingRevenueScreen> {
  Future<List<Map<String, dynamic>>>? _invoices;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _invoices = _fetch());
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final response = await ApiClient().get('/v2/platform-billing/revenue');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Operator revenue retrieval failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw FormatException('Unexpected revenue response');
    return decoded.map((entry) => Map<String, dynamic>.from(entry as Map)).toList();
  }

  String _money(dynamic cents, String currency) {
    final value = (num.tryParse('$cents') ?? 0) / 100;
    return '$currency ${value.toStringAsFixed(2)}';
  }

  Future<void> _post(Map<String, dynamic> row) async {
    final id = row['sourceInvoiceId'];
    Partner? partner;
    final taxController = TextEditingController();
    try {
      final shouldPost = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text('Post ${row['sourceInvoiceNumber']} to ERP'),
            content: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ${_money(row['totalCents'], row['currency']?.toString() ?? '')}'),
                  const SizedBox(height: 12),
                  const Text('Choose the operator-company CUSTOMER partner matching the billed tenant. '
                      'This creates an ERP invoice and may trigger Xero synchronisation.'),
                  const SizedBox(height: 16),
                  PartnerSearchDropdown(
                    role: 'CUSTOMER',
                    label: 'ERP customer partner',
                    onPartnerSelected: (value) => update(() => partner = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taxController,
                    onChanged: (_) => update(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reviewed Xero tax type (required if taxable)',
                      helperText: 'Use the exact mapped Xero tax code for this operator company',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Paid and void statuses require separate reconciliation. '
                    'This action does not invent a customer payment or credit note.'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: partner == null ||
                        ((num.tryParse('${row['taxCents']}') ?? 0) > 0 && taxController.text.trim().isEmpty)
                    ? null : () => Navigator.pop(dialogContext, true),
                child: const Text('Create ERP invoice'),
              ),
            ],
          ),
        ),
      );
      if (shouldPost != true || partner == null || !mounted) return;
      final response = await ApiClient().post(
        '/v2/platform-billing/revenue/$id/post',
        body: {'partnerId': partner!.id, 'xeroTaxType': taxController.text.trim()},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Posting failed (${response.statusCode}): ${response.body}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${row['sourceInvoiceNumber']} posted; verify Xero queue and reconciliation.')),
        );
        _reload();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      taxController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform SaaS Billing Revenue'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh ledger', onPressed: _reload),
      ]),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _invoices,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: SelectableText('${snapshot.error}'));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text(
            'No billing invoices imported yet. Sync operator revenue from the MAWA Admin Billing Console.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final isPosted = (row['erpInvoiceId']?.toString().isNotEmpty ?? false);
              final isVoid = row['sourceStatus'] == 'VOID';
              return Card(child: ExpansionTile(
                title: Text('${row['sourceInvoiceNumber']}  •  ${row['sourceTenantId']}'),
                subtitle: Text('${row['sourceStatus']} • ${row['accountingState']} '
                    '• ${_money(row['totalCents'], row['currency']?.toString() ?? '')}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Central billing ID: ${row['sourceInvoiceId']}'),
                      Text('ERP invoice: ${row['erpInvoiceId'] ?? 'Not posted'}'),
                      Text('Source total excluding tax: ${_money(row['subtotalCents'], row['currency']?.toString() ?? '')}'),
                      Text('Tax: ${_money(row['taxCents'], row['currency']?.toString() ?? '')}'),
                      const SizedBox(height: 12),
                      if (!isPosted && !isVoid) FilledButton.icon(
                        onPressed: () => _post(row),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Review and post to ERP'),
                      ),
                      if (isVoid) const Text('VOID: credit reconciliation required; no new ERP invoice can be posted.'),
                      if (row['sourceStatus'] == 'PAID') const Text('PAID: reconcile payment with bank/Xero separately.'),
                    ]),
                  ),
                ],
              ));
            },
          );
        },
      ),
    );
  }
}
