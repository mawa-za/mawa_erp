import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import '../models/payment_request.dart';
import '../services/payment_request_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PaymentRequestDetailScreen extends StatefulWidget {
  final String paymentId;
  const PaymentRequestDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentRequestDetailScreen> createState() => _PaymentRequestDetailScreenState();
}

class _PaymentRequestDetailScreenState extends State<PaymentRequestDetailScreen> {
  final _service = PaymentRequestService();
  final _approvalService = ApprovalService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  PaymentRequestResponse? _detail;
  List<PaymentRequestStatusHistoryEntity> _history = [];
  List<PaymentDisbursementAttempt> _attempts = [];
  BankReport? _bankReport;
  bool _isBankReportLoading = false;
  String? _bankReportMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getPaymentRequestById(widget.paymentId),
        _service.getPaymentRequestHistory(widget.paymentId),
        _service.getPaymentAttempts(widget.paymentId),
      ]);

      _detail = results[0] as PaymentRequestResponse;
      _history = results[1] as List<PaymentRequestStatusHistoryEntity>;
      _attempts = results[2] as List<PaymentDisbursementAttempt>;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      await _loadBankReport();
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage('An error occurred: $e');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForApproval() async {
    if (_detail == null) return;
    setState(() => _isActionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final submission = ApprovalSubmission(
        approvalType: 'PAYMENT_REQUEST',
        referenceId: _detail!.id,
        referenceNo: _detail!.requestNo,
        title: 'Payment request ${_detail!.requestNo} - ${_detail!.payeeName} - ${_detail!.currency} ${_detail!.amount.toStringAsFixed(2)}',
        description: 'Approval requested for payment to ${_detail!.payeeName} for ${_detail!.currency} ${_detail!.amount.toStringAsFixed(2)}',
        requesterId: userId,
        payloadJson: jsonEncode(_detail!.toJson()),
      );

      // We call the unified approval submission endpoint
      await _approvalService.submitApproval(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for approval successfully')));
        _fetchData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed: $e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this payment request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YES, CANCEL', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _service.cancelPaymentRequest(_detail!.id, comment: "Cancelled by user via Mobile App");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        _fetchData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed: $e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _loadBankReport() async {
    if (_detail == null || !(_detail!.fnbInstructionId?.isNotEmpty ?? false)) {
      if (mounted) {
        setState(() {
          _bankReport = null;
          _bankReportMessage = 'The bank report becomes available after FNB accepts the payment instruction.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isBankReportLoading = true;
        _bankReportMessage = null;
      });
    }
    try {
      var report = await _service.getTypedBankReport(widget.paymentId);
      if (report == null) {
        try {
          report = await _service.refreshTypedBankReport(widget.paymentId);
          _attempts = await _service.getPaymentAttempts(widget.paymentId);
        } catch (e) {
          _bankReportMessage = friendlyErrorMessage(
            e,
            fallback: 'FNB has not returned a bank report yet. MAWA will continue checking automatically.',
          );
        }
      }
      if (mounted) {
        setState(() {
          _bankReport = report;
          _bankReportMessage = report == null
              ? (_bankReportMessage ??
                  'FNB has not returned a bank report yet. MAWA will continue checking automatically.')
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bankReportMessage = friendlyErrorMessage(
            e,
            fallback: 'The bank report could not be loaded.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isBankReportLoading = false);
    }
  }

  Future<void> _refreshBankReport() async {
    if (_detail == null) return;
    setState(() {
      _isBankReportLoading = true;
      _bankReportMessage = null;
    });
    try {
      final report = await _service.refreshTypedBankReport(_detail!.id);
      final attempts = await _service.getPaymentAttempts(_detail!.id);
      if (mounted) {
        setState(() {
          _bankReport = report;
          _attempts = attempts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank report refreshed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bankReportMessage = friendlyErrorMessage(
            e,
            fallback: 'The FNB bank report is not available yet.',
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_bankReportMessage!),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBankReportLoading = false);
    }
  }

  Future<void> _sendToBank() async {
    if (_detail == null) return;
    setState(() => _isActionLoading = true);
    try {
      await _service.sendToBank(_detail!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank payment queued successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                e,
                fallback: 'Unable to queue bank payment',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markAsPaid() async {
    final refController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark as Paid'),
          content: SizedBox(width: 520, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refController,
                decoration: const InputDecoration(labelText: 'Payment Reference', hintText: 'E.g. Bank Ref #'),
              ),
              const SizedBox(height: 16),
              AttachmentSection(objectId: widget.paymentId, documentTypeField: 'PAYMENT-PROOF-DOCUMENT-TYPE'),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Payment Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('MARK PAID'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _service.markAsPaid(_detail!.id, {
        "paidDate": DateFormat('yyyy-MM-dd').format(selectedDate),
        "paidReference": refController.text.trim(),
        "comment": "Marked as paid via Mobile App"
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request marked as PAID'), backgroundColor: Colors.green));
        _fetchData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed: $e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_detail != null ? 'Request #${_detail!.requestNo}' : 'Payment Detail'),
        actions: [
          if (_detail != null) ...[
            if (_detail!.status == 'DRAFT')
              IconButton(onPressed: _isActionLoading ? null : _submitForApproval, icon: const Icon(Icons.send_rounded), tooltip: 'Submit'),
            if (_detail!.status == 'APPROVED')
              IconButton(
                onPressed: _isActionLoading ? null : _sendToBank,
                icon: const Icon(Icons.account_balance_outlined),
                tooltip: 'Queue bank payment',
              ),
            if (_detail!.status == 'APPROVED' && _detail!.paymentMethod == 'MANUAL')
              IconButton(onPressed: _isActionLoading ? null : _markAsPaid, icon: const Icon(Icons.paid_outlined), tooltip: 'Mark Paid'),
            if (_detail!.status == 'DRAFT' || _detail!.status == 'PENDING_APPROVAL' || _detail!.status == 'PENDING')
              IconButton(onPressed: _isActionLoading ? null : _cancelRequest, icon: const Icon(Icons.cancel_outlined, color: Colors.red), tooltip: 'Cancel'),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
    if (_detail == null) return const Center(child: Text('No data found'));

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryHeader(colorScheme),
          const SizedBox(height: 24),
          _buildSectionTitle('General Information'),
          _buildInfoCard([
            _buildInfoRow('Reference', _detail!.externalReference ?? 'N/A'),
            _buildInfoRow('Payment Reason', _detail!.paymentReason ?? 'N/A'),
            _buildInfoRow('Payment Method', _detail!.paymentMethod),
            _buildInfoRow('Payment Request Type', _detail!.requestType),
            _buildInfoRow('Bank Integration', _detail!.bankIntegration ?? 'Not routed'),
            _buildInfoRow('Created Date', _detail!.createdAt),
            _buildInfoRow('Due Date', _detail!.requestedPaymentDate ?? 'N/A'),
            _buildInfoRow('Status', _detail!.status, isStatus: true),
            if (_detail!.approvalInherited)
              _buildInfoRow('Approval Source', _detail!.approvalSource ?? 'CLAIM_APPROVAL'),
            if (_detail!.fnbInstructionId?.isNotEmpty ?? false)
              _buildInfoRow('FNB Instruction', _detail!.fnbInstructionId!),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Recipient & Banking'),
          _buildInfoCard([
            _buildInfoRow('Payee Name', _detail!.payeeName),
            _buildInfoRow('Bank', _detail!.bankName ?? 'N/A'),
            _buildInfoRow('Account Holder', _detail!.accountHolder ?? 'N/A'),
            _buildInfoRow('Account Number', _detail!.accountNumber ?? 'N/A'),
            _buildInfoRow('Universal Branch Code', _detail!.branchCode ?? 'N/A'),
          ]),

          if (_detail!.status == 'PAID') ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Payment Completion'),
            _buildInfoCard([
              _buildInfoRow('Paid Date', _detail!.paidDate ?? 'N/A'),
              _buildInfoRow('Paid Reference', _detail!.paidReference ?? 'N/A'),
              _buildInfoRow('Paid By', _detail!.paidBy ?? 'N/A'),
            ]),
          ],

          if (_attempts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Disbursement Attempts'),
            _buildAttemptCard(),
          ],

          if (_shouldShowBankReportSection) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Bank Report'),
            _buildBankReportCard(),
          ],

          const SizedBox(height: 24),
          _buildSectionTitle('Status History'),
          _buildHistoryCard(),
          
          const SizedBox(height: 24),
          AttachmentSection(
            objectId: widget.paymentId,
            documentTypeField: 'DOCUMENT-TYPE-PAYMENT-REQUEST',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _history.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final h = _history[index];
          return ListTile(
            dense: true,
            title: Text('${h.oldStatus} → ${h.newStatus}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (h.comment != null) Text(h.comment!, style: const TextStyle(fontStyle: FontStyle.italic)),
                Text('By ${h.changedBy} on ${h.changedAt}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttemptCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _attempts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final attempt = _attempts[index];
          final failed = attempt.status == 'FAILED';
          final succeeded = attempt.status == 'SUCCEEDED';
          return ListTile(
            leading: Icon(
              failed ? Icons.error_outline : succeeded ? Icons.check_circle_outline : Icons.sync_rounded,
              color: failed ? Colors.red : succeeded ? Colors.green : Colors.blue,
            ),
            title: Text(
              '${attempt.provider} attempt ${attempt.attemptNo}: ${attempt.status.replaceAll('_', ' ')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attempt.providerStatus?.isNotEmpty ?? false)
                  Text('Bank status: ${attempt.providerStatus}'),
                if (attempt.instructionId?.isNotEmpty ?? false)
                  Text('Instruction: ${attempt.instructionId}'),
                if (attempt.bankReportAvailable)
                  Text('Bank report retrieved: ${attempt.bankReportRetrievedAt ?? 'Available'}'),
                if (attempt.failureMessage?.isNotEmpty ?? false)
                  Text(attempt.failureMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _shouldShowBankReportSection {
    if (_detail == null) return false;
    return (_detail!.bankIntegration ?? '').toUpperCase() == 'FNB' ||
        (_detail!.fnbInstructionId?.isNotEmpty ?? false) ||
        _attempts.isNotEmpty;
  }

  PaymentDisbursementAttempt? get _latestAttempt =>
      _attempts.isEmpty ? null : _attempts.last;

  Widget _buildBankReportCard() {
    final report = _bankReport;
    final latestAttempt = _latestAttempt;
    final status = (report?.groupStatus.isNotEmpty ?? false)
        ? report!.groupStatus.toUpperCase()
        : (latestAttempt?.providerStatus ?? latestAttempt?.status ?? 'PENDING').toUpperCase();
    final isRejected = {'RJCT', 'REJECTED', 'FAILED'}.contains(status);
    final isSuccessful = {'ACSC', 'ACCC', 'COMPLETED', 'COMPLETE', 'SUCCESS', 'SUCCEEDED', 'PAID'}.contains(status);
    final cardColor = isRejected
        ? Colors.red.shade50
        : isSuccessful
            ? Colors.green.shade50
            : Colors.orange.shade50;
    final borderColor = isRejected
        ? Colors.red.shade200
        : isSuccessful
            ? Colors.green.shade200
            : Colors.orange.shade200;
    final statusColor = isRejected
        ? Colors.red
        : isSuccessful
            ? Colors.green
            : Colors.orange.shade800;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRejected
                      ? Icons.error_outline
                      : isSuccessful
                          ? Icons.check_circle_outline
                          : Icons.schedule_outlined,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRejected
                        ? 'Bank rejected the payment ($status)'
                        : isSuccessful
                            ? 'Bank accepted the payment ($status)'
                            : 'Bank report pending ($status)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                IconButton(
                  onPressed: _isBankReportLoading ||
                          !(_detail!.fnbInstructionId?.isNotEmpty ?? false)
                      ? null
                      : _refreshBankReport,
                  icon: _isBankReportLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh bank report',
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              'Instruction ID',
              _detail!.fnbInstructionId ?? latestAttempt?.instructionId ?? 'Not assigned',
              isDark: true,
            ),
            _buildInfoRow(
              'Last checked',
              latestAttempt?.bankReportRetrievedAt ??
                  latestAttempt?.lastCheckedAt ??
                  'Not checked yet',
              isDark: true,
            ),
            if (report != null) ...[
              _buildInfoRow('Initiating Party', report.groupHeader?.initiatingPartyName ?? 'N/A', isDark: true),
              _buildInfoRow('Creation Time', report.groupHeader?.creationDateTime ?? 'N/A', isDark: true),
              if (report.originalPaymentInformation.isNotEmpty)
                _buildInfoRow(
                  'Payment Status',
                  report.originalPaymentInformation
                      .map((item) => item.paymentInformationStatus)
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(', '),
                  isDark: true,
                ),
              if (_reportReasons(report).isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Bank response details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ..._reportReasons(report).map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('• $reason', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                _bankReportMessage ??
                    'FNB has not returned a report yet. MAWA will continue checking automatically.',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _reportReasons(BankReport report) {
    final reasons = <String>[];
    void addReason(StatusReasonInformation reason) {
      final code = reason.reason?.trim() ?? '';
      final detail = reason.additionalInformation?.trim() ?? '';
      final text = [code, detail].where((value) => value.isNotEmpty).join(': ');
      if (text.isNotEmpty && !reasons.contains(text)) reasons.add(text);
    }

    for (final reason in report.statusReasonInformation) {
      addReason(reason);
    }
    for (final payment in report.originalPaymentInformation) {
      for (final reason in payment.statusReasonInformation) {
        addReason(reason);
      }
      for (final transaction in payment.transactionInfoAndStatus) {
        for (final reason in transaction.statusReasonInformation) {
          addReason(reason);
        }
      }
    }
    return reasons;
  }

  Widget _buildSummaryHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${_detail!.currency} ${_detail!.amount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(
              _detail!.requestType.replaceAll('_', ' '),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: children)),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSmall = false, bool isDark = false, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: isDark ? Colors.black54 : Colors.grey.shade600, fontSize: 12))),
          Expanded(
            flex: 3,
            child: isStatus
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(value).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getStatusColor(value).withOpacity(0.5)),
                    ),
                    child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _getStatusColor(value))),
                  ),
                )
              : Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 11 : 13, color: isDark ? Colors.black : Colors.black87), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': case 'PAID': return Colors.green;
      case 'REJECTED': case 'CANCELLED': return Colors.red;
      case 'PENDING_APPROVAL': case 'PENDING': return Colors.orange;
      case 'DRAFT': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
