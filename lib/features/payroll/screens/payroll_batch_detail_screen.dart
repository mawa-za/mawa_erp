import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../models/payroll_batch.dart';
import '../services/payroll_service.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import 'payroll_batch_create_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PayrollBatchDetailScreen extends StatefulWidget {
  final String batchId;
  const PayrollBatchDetailScreen({super.key, required this.batchId});

  @override
  State<PayrollBatchDetailScreen> createState() => _PayrollBatchDetailScreenState();
}

class _PayrollBatchDetailScreenState extends State<PayrollBatchDetailScreen> {
  final _service = PayrollService();
  final _approvalService = ApprovalService();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  PayrollBatchDetail? _batch;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _service.getPayrollBatch(widget.batchId);
      setState(() {
        _batch = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage('Failed to load details: $e');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForApproval() async {
    if (_batch == null) return;

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final submission = ApprovalSubmission(
        approvalType: 'PAYROLL_BATCH',
        referenceId: _batch!.id,
        referenceNo: _batch!.batchNo,
        title: 'Payroll batch ${_batch!.batchNo} - ${_batch!.payPeriod} - ${_batch!.items.length} employees',
        description: 'Approval requested for ${_batch!.items.length} salary payments for period ${_batch!.payPeriod}. Total: R ${_calculateTotal()}',
        requesterId: userId,
        payloadJson: jsonEncode({
          'batchNumber': _batch!.batchNo,
          'description': _batch!.description,
          'payPeriod': _batch!.payPeriod,
          'paymentDate': _batch!.paymentDate,
          'status': _batch!.status,
          'employeeCount': _batch!.items.length,
          'totalAmountCents': (_batch!.totalAmount * 100).round(),
          'employees': _batch!.items.map((item) => item.toJson()).toList(),
          'batchId': _batch!.id,
          'attachmentObjectIds': [_batch!.id],
        }),
      );

      await _approvalService.submitApproval(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll batch submitted for approval'), backgroundColor: Colors.green),
        );
        _fetchDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _previewPrintout() async {
    if (_batch == null) return;
    try {
      final bytes = Uint8List.fromList(await _service.getVerificationPrintout(_batch!.id));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Payroll Verification ${_batch!.batchNo}')),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName: 'payroll-verification-${_batch!.batchNo}.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Unable to generate verification printout: $e'))),
      );
    }
  }

  Future<void> _refreshBankReport() async {
    if (_batch == null || (_batch!.fnbInstructionId ?? '').isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final refreshed = await _service.refreshBankReport(_batch!.id);
      if (mounted) setState(() => _batch = refreshed);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Unable to retrieve bank report: $e'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  Future<void> _viewBankReport() async {
    final raw = _batch?.bankReportJson;
    if (raw == null || raw.trim().isEmpty) return;
    String display = raw;
    try {
      display = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bank Report ${_batch!.batchNo}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(display, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_batch?.batchNo ?? 'Batch Details'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_batch != null)
            IconButton(
              tooltip: 'Verification printout',
              onPressed: _previewPrintout,
              icon: const Icon(Icons.print_rounded),
            ),
          if (_batch != null && (_batch!.status == 'NEW' || _batch!.status == 'DRAFT')) ...[
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PayrollBatchCreateScreen(batchId: _batch!.id),
                  ),
                );
                if (result == true) _fetchDetail();
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('EDIT'),
            ),
            TextButton.icon(
              onPressed: _isSubmitting ? null : _submitForApproval,
              icon: _isSubmitting 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
              label: const Text('SUBMIT'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDetail,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_batch == null) return const Center(child: Text('No data found'));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(colorScheme),
                const SizedBox(height: 16),
                _buildBankSubmissionCard(colorScheme),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'PAYMENT ITEMS (${_batch!.items.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600], letterSpacing: 1.0),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _batch!.items[index];
                return _buildItemCard(item, colorScheme);
              },
              childCount: _batch!.items.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(_batch!.status),
              Text(
                _batch!.payPeriod,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _batch!.description,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          if (_batch!.notes.isNotEmpty)
            Text(
              _batch!.notes,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoItem('PAYMENT DATE', _batch!.paymentDate, Icons.calendar_month_rounded),
              const Spacer(),
              _buildInfoItem('TOTAL VALUE', 'R ${_calculateTotal()}', Icons.payments_rounded, isAmount: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankSubmissionCard(ColorScheme colorScheme) {
    final instruction = _batch!.fnbInstructionId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('BANK SUBMISSION', style: TextStyle(fontWeight: FontWeight.bold))),
              if ((instruction ?? '').isNotEmpty)
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _refreshBankReport,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('REFRESH REPORT'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Message status', _batch!.bankMessageStatus),
          _buildDetailRow('Instruction ID', instruction ?? 'Not submitted'),
          _buildDetailRow('Bank report status', _batch!.bankReportStatus ?? 'Not available'),
          if ((_batch!.bankReportReason ?? '').isNotEmpty)
            _buildDetailRow('Bank report reason', _batch!.bankReportReason!),
          if ((_batch!.bankSubmittedAt ?? '').isNotEmpty)
            _buildDetailRow('Submitted at', _batch!.bankSubmittedAt!),
          if ((_batch!.bankReportJson ?? '').isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _viewBankReport,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('VIEW FULL REPORT'),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'The approved payroll is submitted as one bank instruction containing one creditor transaction per employee.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _calculateTotal() {
    double total = 0;
    for (var item in _batch!.items) {
      total += item.amount;
    }
    return total.toStringAsFixed(2);
  }

  Widget _buildInfoItem(String label, String value, IconData icon, {bool isAmount = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: isAmount ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAmount) ...[Icon(icon, size: 14, color: Colors.grey[400]), const SizedBox(width: 4)],
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isAmount ? colorScheme.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PROCESSED': case 'APPROVED': case 'PAID': color = Colors.green; break;
      case 'REJECTED': case 'FAILED': color = Colors.red; break;
      case 'CANCELLED': color = Colors.grey; break;
      case 'PENDING': case 'PENDING_APPROVAL': case 'NEW': case 'DRAFT': color = Colors.orange; break;
      case 'PROCESSING': case 'SUBMITTED': color = Colors.blue; break;
      default: color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' ').replaceAll('-', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItemCard(PayrollItem item, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Text(
            item.employeeName?.substring(0, 1).toUpperCase() ?? 'E',
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          item.employeeName ?? 'Unknown Employee',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          item.employeeNo ?? 'No ID',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          'R ${item.amount.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: colorScheme.primary),
        ),
        children: [
          const Divider(),
          _buildDetailRow('Account Holder', item.accountHolderName ?? '-'),
          _buildDetailRow('Bank Name', item.bankName ?? '-'),
          _buildDetailRow('Account Number', item.accountNo ?? '-'),
          _buildDetailRow('Account Type', item.accountType ?? '-'),
          _buildDetailRow('Universal Branch Code', item.branchCode ?? '-'),
          _buildDetailRow('Reference', item.paymentReference ?? '-'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
