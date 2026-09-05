import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_trust.dart';
import '../services/case_trust_service.dart';
import 'trust_receipt_preview_dialog.dart';
import 'package:mawa_erp/core/errors/app_error.dart';
import '../../../core/utils/app_date_utils.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class CaseTrustAccountTab extends StatefulWidget {
  final String caseId;
  const CaseTrustAccountTab({super.key, required this.caseId});

  @override
  State<CaseTrustAccountTab> createState() => _CaseTrustAccountTabState();
}

class _CaseTrustAccountTabState extends State<CaseTrustAccountTab> {
  final CaseTrustService _trustService = CaseTrustService();
  CaseTrustBalance? _balance;
  List<CaseTrustTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _trustService.getTrustBalance(widget.caseId);
      final transactions = await _trustService.getTrustTransactions(widget.caseId);
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    }
  }

  String _formatCents(int cents) {
    return NumberFormat.currency(symbol: 'R ', locale: 'en_ZA').format(cents / 100);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_balance == null) return const Center(child: Text('Failed to load trust account info'));

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildActions(),
          const SizedBox(height: 24),
          const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        _buildBalanceCard(),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildSmallCard('Total Received', _formatCents(_balance!.totalReceivedCents), Colors.green),
            _buildSmallCard('Business Transfers', _formatCents(_balance!.totalTransferredCents), Colors.blue),
            _buildSmallCard('Refunded', _formatCents(_balance!.totalRefundedCents), Colors.orange),
            _buildSmallCard('Third Party', _formatCents(_balance!.totalPaidOutCents), Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[700]!]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Trust Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            _formatCents(_balance!.availableBalanceCents),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(Icons.add_chart, 'Receive', Colors.green, _showReceiveFundsDialog),
        _buildActionButton(Icons.swap_horiz, 'Transfer', Colors.blue, _showTransferToBusinessDialog),
        _buildActionButton(Icons.keyboard_return, 'Refund', Colors.orange, _showRefundClientDialog),
        _buildActionButton(Icons.payments_outlined, 'Third Party', Colors.purple, _showPayThirdPartyDialog),
        _buildActionButton(Icons.refresh, 'Refresh', Colors.grey, _fetchData),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: _transactions.map((tx) => _buildTransactionCard(tx)).toList(),
    );
  }

  Widget _buildTransactionCard(CaseTrustTransaction tx) {
    final bool isPositive = tx.direction == 'IN';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tx.reversed ? Colors.red[100]! : Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (tx.reversed ? Colors.grey : (isPositive ? Colors.green : Colors.red)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.reversed ? Icons.history : (isPositive ? Icons.arrow_downward : Icons.arrow_upward),
                  color: tx.reversed ? Colors.grey : (isPositive ? Colors.green : Colors.red),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.transactionType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(tx.transactionNo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? "+" : "-"}${_formatCents(tx.amountCents)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tx.reversed ? Colors.grey : (isPositive ? Colors.green : Colors.red),
                    ),
                  ),
                  if (tx.reversed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                      child: const Text('REVERSED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  _buildDetailRow('Date', AppDateUtils.displayDateTimePattern(tx.transactionDate, 'yyyy-MM-dd HH:mm', fallback: '-')),
                  _buildDetailRow('Method', tx.paymentMethod ?? '-'),
                  _buildDetailRow('Ref No', tx.referenceNo ?? '-'),
                  if (tx.payeeName != null) _buildDetailRow('Payee', tx.payeeName!),
                  _buildDetailRow('Balance After', _formatCents(tx.balanceAfterCents)),
                  if (tx.description != null && tx.description!.isNotEmpty)
                    _buildDetailRow('Description', tx.description!),
                  if (tx.transactionType == 'TRUST_RECEIPT' && !tx.reversed) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => TrustReceiptPreviewDialog(transaction: tx),
                        ),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Trust Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          foregroundColor: Colors.green[700],
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                  if (tx.reversed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reversal Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                          Text('Reason: ${tx.reversalReason ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                          Text('By: ${tx.reversedBy ?? 'N/A'} at ${AppDateUtils.displayDateTimePattern(tx.reversedAt, 'yyyy-MM-dd HH:mm')}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  if (!tx.reversed) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReverseTransactionDialog(tx),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Reverse Transaction'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  void _showReceiveFundsDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final bankRefController = TextEditingController();
    final descController = TextEditingController();
    final receivedByController = TextEditingController();
    String paymentMethod = 'EFT';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Receive Trust Funds'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (Rand)', prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid amount' : null,
                  ),
                  SearchableDropdownFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: ['CASH', 'EFT', 'CARD', 'BANK_TRANSFER', 'OTHER'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setDialogState(() => paymentMethod = v!),
                  ),
                  TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference No'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: bankRefController, decoration: const InputDecoration(labelText: 'Bank Reference')),
                  TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                  TextFormField(controller: receivedByController, decoration: const InputDecoration(labelText: 'Received By')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final req = CaseTrustReceiptRequest(
                      amountCents: (double.parse(amountController.text) * 100).toInt(),
                      paymentMethod: paymentMethod,
                      referenceNo: refController.text,
                      bankReference: bankRefController.text,
                      description: descController.text,
                      receivedBy: receivedByController.text,
                      transactionDate: DateTime.now(),
                    );
                    final tx = await _trustService.receiveTrustFunds(widget.caseId, req);
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchData();
                      showDialog(
                        context: context,
                        builder: (context) => TrustReceiptPreviewDialog(transaction: tx),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferToBusinessDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final invoiceIdController = TextEditingController();
    final descController = TextEditingController();
    final transferredByController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer to Business'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (Rand)', prefixText: 'R '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final amount = (double.tryParse(v ?? '') ?? 0) * 100;
                    if (amount <= 0) return 'Enter valid amount';
                    if (amount > _balance!.availableBalanceCents) return 'Insufficient trust funds';
                    return null;
                  },
                ),
                TextFormField(controller: invoiceIdController, decoration: const InputDecoration(labelText: 'Invoice ID'), validator: (v) => v!.isEmpty ? 'Required' : null),
                TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                TextFormField(controller: transferredByController, decoration: const InputDecoration(labelText: 'Transferred By')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final req = CaseTrustBusinessTransferRequest(
                    amountCents: (double.parse(amountController.text) * 100).toInt(),
                    relatedInvoiceId: invoiceIdController.text,
                    description: descController.text,
                    transferredBy: transferredByController.text,
                  );
                  await _trustService.transferToBusiness(widget.caseId, req);
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                }
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _showRefundClientDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final bankRefController = TextEditingController();
    final descController = TextEditingController();
    final refundedByController = TextEditingController();
    String paymentMethod = 'EFT';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Refund Client'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (Rand)', prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final amount = (double.tryParse(v ?? '') ?? 0) * 100;
                      if (amount <= 0) return 'Enter valid amount';
                      if (amount > _balance!.availableBalanceCents) return 'Insufficient trust funds';
                      return null;
                    },
                  ),
                  SearchableDropdownFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: ['CASH', 'EFT', 'CARD', 'BANK_TRANSFER', 'OTHER'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setDialogState(() => paymentMethod = v!),
                  ),
                  TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference No')),
                  TextFormField(controller: bankRefController, decoration: const InputDecoration(labelText: 'Bank Reference')),
                  TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                  TextFormField(controller: refundedByController, decoration: const InputDecoration(labelText: 'Refunded By')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final req = CaseTrustRefundRequest(
                      amountCents: (double.parse(amountController.text) * 100).toInt(),
                      paymentMethod: paymentMethod,
                      referenceNo: refController.text,
                      bankReference: bankRefController.text,
                      description: descController.text,
                      refundedBy: refundedByController.text,
                    );
                    await _trustService.refundClient(widget.caseId, req);
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                  }
                }
              },
              child: const Text('Confirm Refund'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayThirdPartyDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final payeeController = TextEditingController();
    final refController = TextEditingController();
    final bankRefController = TextEditingController();
    final descController = TextEditingController();
    final paidByController = TextEditingController();
    String paymentMethod = 'EFT';
    bool createDisbursement = true;
    String disbursementType = 'OTHER';
    bool billableDisbursement = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pay Third Party'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (Rand)', prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final amount = (double.tryParse(v ?? '') ?? 0) * 100;
                      if (amount <= 0) return 'Enter valid amount';
                      if (amount > _balance!.availableBalanceCents) return 'Insufficient trust funds';
                      return null;
                    },
                  ),
                  TextFormField(controller: payeeController, decoration: const InputDecoration(labelText: 'Payee Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  SearchableDropdownFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: ['CASH', 'EFT', 'CARD', 'BANK_TRANSFER', 'OTHER'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setDialogState(() => paymentMethod = v!),
                  ),
                  TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference No')),
                  TextFormField(controller: bankRefController, decoration: const InputDecoration(labelText: 'Bank Reference')),
                  TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                  TextFormField(controller: paidByController, decoration: const InputDecoration(labelText: 'Paid By')),
                  SwitchListTile(
                    title: const Text('Create Disbursement', style: TextStyle(fontSize: 14)),
                    value: createDisbursement,
                    onChanged: (v) => setDialogState(() => createDisbursement = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (createDisbursement) ...[
                    SearchableDropdownFormField<String>(
                      value: disbursementType,
                      decoration: const InputDecoration(labelText: 'Disbursement Type'),
                      items: ['SHERIFF', 'COURT_FEE', 'TRAVEL', 'PRINTING', 'POSTAGE', 'ADVOCATE', 'EXPERT', 'OTHER'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setDialogState(() => disbursementType = v!),
                    ),
                    SwitchListTile(
                      title: const Text('Billable to Client', style: TextStyle(fontSize: 14)),
                      value: billableDisbursement,
                      onChanged: (v) => setDialogState(() => billableDisbursement = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final req = CaseTrustThirdPartyPaymentRequest(
                      amountCents: (double.parse(amountController.text) * 100).toInt(),
                      payeeName: payeeController.text,
                      paymentMethod: paymentMethod,
                      referenceNo: refController.text,
                      bankReference: bankRefController.text,
                      description: descController.text,
                      paidBy: paidByController.text,
                      createDisbursement: createDisbursement,
                      disbursementType: disbursementType,
                      billableDisbursement: billableDisbursement,
                    );
                    await _trustService.payThirdParty(widget.caseId, req);
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                  }
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReverseTransactionDialog(CaseTrustTransaction tx) {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    final reversedByController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse Transaction'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to reverse ${tx.transactionNo} (${_formatCents(tx.amountCents)})?', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason for Reversal'),
                validator: (v) => v!.isEmpty ? 'Reason is required' : null,
              ),
              TextFormField(controller: reversedByController, decoration: const InputDecoration(labelText: 'Reversed By')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final req = CaseTrustReverseTransactionRequest(
                    reversalReason: reasonController.text,
                    reversedBy: reversedByController.text,
                  );
                  await _trustService.reverseTransaction(widget.caseId, tx.id, req);
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reverse Now'),
          ),
        ],
      ),
    );
  }
}
