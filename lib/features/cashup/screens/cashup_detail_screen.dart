import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/attachment_section.dart';
import '../models/cashup.dart';
import '../services/cashup_service.dart';
import '../../settings/services/pos_printing_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class CashupDetailScreen extends StatefulWidget {
  final String cashupId;
  const CashupDetailScreen({super.key, required this.cashupId});

  @override
  State<CashupDetailScreen> createState() => _CashupDetailScreenState();
}

class _CashupDetailScreenState extends State<CashupDetailScreen> {
  final CashupService _cashupService = CashupService();
  Cashup? _cashup;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isClosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cashup = await _cashupService.getCashupById(widget.cashupId);

      if (!mounted) return;
      setState(() {
        _cashup = cashup;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForApproval() async {
    if (_cashup == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Cashup'),
        content: const Text('Are you sure you want to submit this cashup for verification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SUBMIT')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      await _cashupService.submitForApproval(_cashup!.id, {
        'requesterId': userId,
        'comments': 'Submitted from mawa cashup detail screen',
      });

      String? printWarning;
      try {
        await PosPrintingService().queueCashup(_cashup!.id);
      } catch (printError) {
        printWarning = friendlyErrorMessage(printError);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printWarning == null
                  ? 'Cashup submitted and cashup slip queued for printing.'
                  : 'Cashup submitted, but the cashup slip could not be queued: $printWarning',
            ),
            backgroundColor: printWarning == null ? Colors.green : Colors.orange,
          ),
        );
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to submit: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _closeCashup() async {
    if (_cashup == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cashup / Close Cashup'),
        content: const Text('Close this cashup and move it to Awaiting Deposits? No more receipts can be added after it is closed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLOSE CASHUP')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isClosing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await _cashupService.closeCashup(_cashup!.id, actionBy: prefs.getString('userId'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cashup closed and moved to Awaiting Deposits.'), backgroundColor: Colors.green),
      );
      await _fetchDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  bool _canCloseCashup(Cashup cashup) => cashup.status.toUpperCase() == 'OPEN' && cashup.depositRequired;

  bool _canSubmitCashup(Cashup cashup) {
    final status = cashup.status.toUpperCase();
    if (!cashup.depositRequired) return status == 'OPEN' || status == 'AWAITING_DEPOSITS';
    return (status == 'AWAITING_DEPOSITS' || status == 'COMPLETED') && cashup.deposits.isNotEmpty;
  }

  bool _canEditCashup(Cashup cashup) {
    final status = cashup.status.toUpperCase();
    return status == 'AWAITING_DEPOSITS' || status == 'COMPLETED';
  }

  Future<void> _showDepositDialog() async {
    if (_cashup == null) return;

    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    String? selectedBankName;
    final notesController = TextEditingController();
    String paymentMethod = 'CASH';
    DateTime depositDate = DateTime.now();
    String? attachmentFile;
    String? attachmentExtension;
    String? attachmentName;
    String? validationError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Deposit'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: 'R ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'CARD', child: Text('Card')),
                      DropdownMenuItem(value: 'EFT', child: Text('EFT')),
                      DropdownMenuItem(value: 'BANK_DEPOSIT', child: Text('Bank Deposit')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => paymentMethod = value ?? 'CASH'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Deposit Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(depositDate)),
                    trailing: TextButton(
                      child: const Text('CHANGE'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: depositDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setDialogState(() => depositDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField(
                    field: 'BANK-NAME',
                    label: 'Bank Name',
                    icon: Icons.account_balance_outlined,
                    value: selectedBankName,
                    onChanged: (value) =>
                        setDialogState(() => selectedBankName = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PROOF OF DEPOSIT *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const [
                          'pdf',
                          'jpg',
                          'jpeg',
                          'png',
                          'doc',
                          'docx',
                        ],
                        withData: true,
                      );
                      if (picked == null || picked.files.isEmpty) return;
                      final file = picked.files.single;
                      if (file.bytes == null || file.bytes!.isEmpty) {
                        setDialogState(() {
                          validationError = 'The selected attachment could not be read.';
                        });
                        return;
                      }
                      setDialogState(() {
                        attachmentName = file.name;
                        attachmentExtension = file.extension ??
                            (file.name.contains('.')
                                ? file.name.split('.').last
                                : 'bin');
                        attachmentFile = base64Encode(file.bytes!);
                        validationError = null;
                      });
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      attachmentName == null
                          ? 'SELECT ATTACHMENT'
                          : 'CHANGE: $attachmentName',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (attachmentName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      attachmentName!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                  amountController.text.trim().replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) {
                  setDialogState(() => validationError = 'A valid amount is required.');
                  return;
                }
                if (attachmentFile == null || attachmentExtension == null) {
                  setDialogState(() =>
                      validationError = 'A proof-of-deposit attachment is required.');
                  return;
                }
                Navigator.pop(context, {
                  'amountCents': (amount * 100).round(),
                  'paymentMethod': paymentMethod,
                  'depositDate': DateFormat('yyyy-MM-dd').format(depositDate),
                  'referenceNo': referenceController.text.trim(),
                  'bankName': selectedBankName,
                  'notes': notesController.text.trim(),
                  'attachmentFile': attachmentFile,
                  'attachmentExtension': attachmentExtension,
                  'attachmentDocumentType': 'DEPOSIT-PROOF',
                });
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();

    if (result == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      result['createdBy'] = prefs.getString('userId') ?? '';
      await _cashupService.createDeposit(_cashup!.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deposit created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Failed to create deposit: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_cashup != null ? 'Cashup #${_cashup!.cashupNo}' : 'Cashup Details'),
        actions: [
          if (_cashup != null && _canCloseCashup(_cashup!))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isClosing ? null : _closeCashup,
                icon: _isClosing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.point_of_sale_outlined, size: 18),
                label: const Text('CASHUP / CLOSE'),
              ),
            ),
          if (_cashup != null && _canSubmitCashup(_cashup!))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _submitForApproval,
                icon: _isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
                label: const Text('SUBMIT'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load cashup details', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final cashup = _cashup!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryHeader(cashup, colorScheme),
          const SizedBox(height: 16),
          _buildInfoSection(cashup),
          const SizedBox(height: 16),
          _buildPaymentsSection(cashup, colorScheme),
          const SizedBox(height: 16),
          cashup.depositRequired
              ? _buildDepositsSection(cashup, colorScheme)
              : _buildDepositNotRequiredSection(cashup, colorScheme),
          const SizedBox(height: 16),
          AttachmentSection(
            objectId: widget.cashupId,
            documentTypeField: 'DOCUMENT-TYPE-CASHUP',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(Cashup cashup, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Total Collected', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'R ${cashup.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cashup.status.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Cashup cashup) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CASHUP INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.numbers_outlined, 'Cashup Number', cashup.cashupNo.toString()),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_available, 'Date', cashup.cashupDate),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.devices_outlined, 'Device', cashup.deviceId),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, 'Cashier', cashup.cashierDisplayName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.receipt_long_outlined, 'Receipt Count', cashup.receiptCount.toString()),
            if (cashup.isManualReceiptBook) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.menu_book_outlined, 'Receipt Book', cashup.receiptBookNo),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.format_list_numbered_outlined,
                'Receipt Range',
                '${cashup.receiptFromNo} - ${cashup.receiptToNo}',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.payments_outlined, 'Manual Amount', 'R ${(cashup.manualAmountCents / 100).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.receipt_outlined, 'Receipt Total', 'R ${(cashup.receiptTotalCents / 100).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.balance_outlined, 'Variance', 'R ${(cashup.varianceCents / 100).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.badge_outlined, 'Employee Responsible', cashup.employeeResponsibleName.isEmpty ? cashup.employeeResponsibleId : cashup.employeeResponsibleName),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.place_outlined, 'Area', cashup.areaName.isEmpty ? cashup.areaCode : cashup.areaName),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildDepositNotRequiredSection(Cashup cashup, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEPOSIT NOT REQUIRED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'EFT payments use an individual cashup and are submitted directly for approval after payment processing.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositsSection(Cashup cashup, ColorScheme colorScheme) {
    final canEdit = _canEditCashup(cashup);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('DEPOSITS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                ),
                if (canEdit)
                  TextButton.icon(
                    onPressed: _showDepositDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('ADD DEPOSIT'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _depositMetric('Collected', cashup.totalAmount)),
                Expanded(child: _depositMetric('Deposited', cashup.depositTotalAmount)),
                Expanded(child: _depositMetric('Balance', cashup.depositBalanceAmount)),
              ],
            ),
            const SizedBox(height: 12),
            if (cashup.deposits.isEmpty)
              Text('No deposits captured yet.', style: TextStyle(color: Colors.grey[600]))
            else
              ...cashup.deposits.map((deposit) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.account_balance_outlined, color: colorScheme.primary, size: 20),
                    ),
                    title: Text('R ${deposit.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text([
                      deposit.depositDate,
                      deposit.paymentMethod,
                      if (deposit.referenceNo.isNotEmpty) deposit.referenceNo,
                    ].where((value) => value.isNotEmpty).join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'View proof of deposit',
                          icon: const Icon(Icons.attachment_outlined),
                          onPressed: () => _showDepositProof(deposit),
                        ),
                        if (canEdit)
                          IconButton(
                            tooltip: 'Delete deposit',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteDeposit(deposit),
                          ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _depositMetric(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text('R ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _showDepositProof(CashupDeposit deposit) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Proof of Deposit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: AttachmentSection(
                      objectId: deposit.id,
                      readOnly: true,
                      documentTypeField: 'DOCUMENT-TYPE-DEPOSIT',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDeposit(CashupDeposit deposit) async {
    if (_cashup == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deposit'),
        content: Text('Delete deposit of R ${deposit.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _cashupService.deleteDeposit(_cashup!.id, deposit.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit deleted')));
      _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to delete deposit: $e')), backgroundColor: Colors.red));
    }
  }

  Widget _buildPaymentsSection(Cashup cashup, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('PAYMENT BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ),
        ...cashup.payments.map((p) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.payments_outlined, color: colorScheme.primary, size: 20),
            ),
            title: Text(p.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${p.paymentCount} payments'),
            trailing: Text(
              'R ${p.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16),
            ),
          ),
        )),
      ],
    );
  }
}
