import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../models/membership_detail.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../models/payment_batch_response.dart';
import '../models/receipt_response.dart';
import '../../../core/services/bluetooth_print_service.dart';
import '../../../core/services/setting_service.dart';
import '../../settings/services/pos_printing_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class CapturePremiumPaymentDialog extends StatefulWidget {
  final MembershipDetail membership;
  final Partner member;

  const CapturePremiumPaymentDialog({
    super.key,
    required this.membership,
    required this.member,
  });

  @override
  State<CapturePremiumPaymentDialog> createState() => _CapturePremiumPaymentDialogState();
}

class _CapturePremiumPaymentDialogState extends State<CapturePremiumPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _paymentMethod;
  bool _isSubmitting = false;
  bool _isLoadingUnpaid = true;
  List<Map<String, dynamic>> _unpaidPremiums = [];
  String? _selectedPeriodYYYYMM;
  PaymentBatchResponse? _successResponse;
  String? _error;
  String? _printWarning;
  int _maxPremiumMonths = 3;

  BluetoothDevice? _selectedDevice;
  final BluetoothPrintService _printService = BluetoothPrintService();

  final List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'CASH', 'icon': Icons.payments_outlined},
    {'value': 'CARD', 'icon': Icons.credit_card_outlined},
    {'value': 'EFT', 'icon': Icons.account_balance_outlined},
    {'value': 'OTHER', 'icon': Icons.more_horiz_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnpaidPremiums();
    _loadPaymentLimit();
    _initBluetooth();
  }


  Future<void> _loadPaymentLimit() async {
    try {
      final settings = await SettingService().getSettings();
      final match = settings.where((s) =>
          s.type.trim().toUpperCase() == 'MEMBERSHIP' &&
          s.attribute.trim().toUpperCase() == 'MAX_PREMIUM_PAYMENT_MONTHS');
      final configured = match.isEmpty ? null : int.tryParse(match.first.value.trim());
      if (mounted && configured != null && configured > 0) {
        setState(() => _maxPremiumMonths = configured);
      }
    } catch (_) {
      // Safe default remains 3 months when no tenant configuration exists.
    }
  }

  int get _maximumPaymentCents => widget.membership.premiumCents * _maxPremiumMonths;

  int? get _selectedOutstandingBalanceCents {
    if (_selectedPeriodYYYYMM == null) return null;
    for (final premium in _unpaidPremiums) {
      if (premium['periodYYYYMM']?.toString() == _selectedPeriodYYYYMM) {
        return (premium['balanceCents'] as num?)?.toInt() ?? 0;
      }
    }
    return null;
  }

  String? get _paymentAmountHelperText {
    if (_unpaidPremiums.length > 1) {
      final selectedBalance = _selectedOutstandingBalanceCents;
      if (selectedBalance == null) {
        return 'Select an outstanding premium month above.';
      }
      return 'Selected month outstanding: R ${(selectedBalance / 100).toStringAsFixed(2)}';
    }
    return widget.membership.premiumCents > 0
        ? 'Maximum $_maxPremiumMonths months: R ${(_maximumPaymentCents / 100).toStringAsFixed(2)}'
        : null;
  }

  Future<void> _initBluetooth() async {
    try {
      final devices = await _printService.getDevices();
      if (devices.isNotEmpty) {
        setState(() {
          _selectedDevice = devices.first;
        });
      }
    } catch (e) {
      debugPrint('Error initializing bluetooth: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnpaidPremiums() async {
    try {
      final unpaid = await MembershipService().getUnpaidPremiums(widget.membership.id);
      if (mounted) {
        setState(() {
          _unpaidPremiums = unpaid;
          _selectedPeriodYYYYMM = unpaid.length == 1
              ? unpaid.first['periodYYYYMM']?.toString()
              : null;
          _isLoadingUnpaid = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnpaid = false);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final printerStatus = await PosPrintingService().receiptPrinterAvailability();
    if (!mounted) return;
    if (!printerStatus.online) {
      final continueWithoutPrinting = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Receipt printer offline'),
          content: Text(
            '${printerStatus.message}\n\n'
            'The payment can still be processed, but MAWA will not be able to print the receipt automatically. '
            'Use another device with an online printer or process a manual payment if a printed receipt is required.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('PROCESS WITHOUT PRINTING'),
            ),
          ],
        ),
      );
      if (continueWithoutPrinting != true) return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? 'unknown';
      final deviceId = prefs.getString('deviceId') ?? 'ERP-ONLINE';

      final double amount = double.parse(_amountController.text);
      final int amountCents = (amount * 100).round();

      final response = await MembershipService().createMembershipPremiumPayment(
        membershipId: widget.membership.id,
        paymentMethod: _paymentMethod!,
        amountCents: amountCents,
        createdBy: userId,
        periodYYYYMM: _unpaidPremiums.length > 1 ? _selectedPeriodYYYYMM : null,
        deviceId: deviceId,
        terminalId: prefs.getString('terminalId'),
        location: prefs.getString('location'),
        employeeResponsible: userId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final printFailures = <String>[];
      for (final receipt in response.receipts) {
        try {
          await PosPrintingService().queueReceipt(receipt.id);
        } catch (error) {
          printFailures.add(receipt.receiptNo);
        }
      }

      if (!mounted) return;
      setState(() {
        _successResponse = response;
        _printWarning = printFailures.isEmpty
            ? null
            : '${printFailures.length} receipt(s) could not be queued automatically. Use the print button next to the receipt to retry.';
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(e);
        _isSubmitting = false;
      });
    }
  }

  Future<void> _printReceipt(ReceiptResponse receipt) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt queued for printing...'), duration: Duration(seconds: 1)),
        );
      }
      await PosPrintingService().queueReceipt(receipt.id, reprint: receipt.printCount > 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt queued for the configured Windows printer'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (cloudError) {
      if (!mounted) return;
      final useBluetooth = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Windows printing unavailable'),
          content: Text('$cloudError\n\nPrint directly to a paired Bluetooth printer instead?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Bluetooth')),
          ],
        ),
      );
      if (useBluetooth != true) return;
      try {
        if (_selectedDevice == null) {
          final devices = await _printService.getDevices();
          if (devices.isEmpty) throw AppException('No Bluetooth printers found. Pair a printer in device settings.');
          if (!mounted) return;
          final device = await showDialog<BluetoothDevice>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Bluetooth printer'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(devices[index].name ?? 'Unknown'),
                    subtitle: Text(devices[index].address ?? ''),
                    onTap: () => Navigator.pop(context, devices[index]),
                  ),
                ),
              ),
            ),
          );
          if (device == null) return;
          setState(() => _selectedDevice = device);
        }
        final printData =
            await PosPrintingService().getReceiptPrintData(receipt.id);
        await _printService.printMembershipReceipt(
          printData,
          device: _selectedDevice,
        );
        try {
          await PosPrintingService().confirmDirectPrint(receipt.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt printed over Bluetooth')),
            );
          }
        } catch (acknowledgementError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Receipt printed, but MAWA could not record the print: $acknowledgementError'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage('Bluetooth print failed: $e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_successResponse != null) {
      return _buildSuccessContent(colorScheme);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(colorScheme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMembershipSummary(colorScheme),
                      const SizedBox(height: 24),
                      if (_unpaidPremiums.isNotEmpty) ...[
                        _buildUnpaidPremiumsSection(colorScheme),
                        const SizedBox(height: 24),
                      ],
                      Text('PAYMENT DETAILS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Payment Amount',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.attach_money_outlined),
                          prefixText: 'R ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                          helperText: _paymentAmountHelperText,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) return 'Invalid amount';
                          final amountCents = (amount * 100).round();
                          if (widget.membership.premiumCents > 0 && amountCents > _maximumPaymentCents) {
                            return 'Maximum is $_maxPremiumMonths months (R ${(_maximumPaymentCents / 100).toStringAsFixed(2)})';
                          }
                          if (_unpaidPremiums.length > 1 && _selectedOutstandingBalanceCents != null) {
                            final balanceCents = _selectedOutstandingBalanceCents!;
                            if (amountCents > balanceCents) {
                              return 'Amount exceeds the selected month outstanding balance of R ${(balanceCents / 100).toStringAsFixed(2)}';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SearchableDropdownFormField<String>(
                        value: _paymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Payment Method',
                          prefixIcon: const Icon(Icons.wallet_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                        ),
                        items: _paymentMethods.map((m) => DropdownMenuItem(
                          value: m['value'] as String,
                          child: Row(
                            children: [
                              Icon(m['icon'] as IconData, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(m['value'] as String),
                            ],
                          ),
                        )).toList(),
                        onChanged: (value) => setState(() => _paymentMethod = value),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FD),
                        ),
                        maxLines: 2,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.2))),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting || _isLoadingUnpaid ? null : _submitPayment,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('POST PAYMENT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.add_card_outlined, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Process Premium Payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text('Membership Payment', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipSummary(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.person_outline, 'Member', widget.member.fullName),
          const Divider(height: 24),
          _summaryRow(Icons.badge_outlined, 'Member No', widget.member.number),
          const Divider(height: 24),
          _summaryRow(Icons.numbers_outlined, 'Membership No', widget.membership.membershipNo),
          if (widget.membership.paidUpToPeriod != null) ...[
            const Divider(height: 24),
            _summaryRow(Icons.event_available_outlined, 'Paid Up To', widget.membership.paidUpToPeriod!),
          ],
        ],
      ),
    );
  }

  Widget _buildUnpaidPremiumsSection(ColorScheme colorScheme) {
    final requiresSelection = _unpaidPremiums.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OUTSTANDING PERIODS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2)),
        const SizedBox(height: 12),
        if (requiresSelection) ...[
          SearchableDropdownFormField<String>(
            value: _selectedPeriodYYYYMM,
            decoration: InputDecoration(
              labelText: 'Premium Month',
              helperText: 'Select the outstanding month this payment must be allocated to.',
              prefixIcon: const Icon(Icons.calendar_month_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FD),
            ),
            items: _unpaidPremiums.map((premium) {
              final period = premium['periodYYYYMM']?.toString() ?? '';
              final balanceCents = (premium['balanceCents'] as num?)?.toInt() ?? 0;
              return DropdownMenuItem<String>(
                value: period,
                child: Text('${_formatPeriod(period)} — R ${(balanceCents / 100).toStringAsFixed(2)}'),
              );
            }).toList(),
            isExpanded: true,
            onChanged: (value) => setState(() => _selectedPeriodYYYYMM = value),
            validator: (value) => value == null || value.isEmpty
                ? 'Select the premium month to process'
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Column(
            children: _unpaidPremiums.map((p) {
              final period = p['periodYYYYMM']?.toString() ?? '-';
              final amount = ((p['balanceCents'] as num?)?.toInt() ?? 0) / 100.0;
              final isSelected = period == _selectedPeriodYYYYMM;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (requiresSelection) ...[
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18,
                        color: isSelected ? colorScheme.primary : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(_formatPeriod(period), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text('R ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSuccessContent(ColorScheme colorScheme) {
    final response = _successResponse!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Payment Successful!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 8),
            Text('Batch No: ${response.paymentBatchNo}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (response.paidUpToPeriod != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withOpacity(0.1))),
                child: Text('NEW PAID UP TO: ${response.paidUpToPeriod}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              ),
            const SizedBox(height: 24),
            if (_printWarning != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_disabled_outlined, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_printWarning!, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Align(alignment: Alignment.centerLeft, child: Text('RECEIPTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2))),
            const SizedBox(height: 12),
            ...response.receipts.map((r) => _buildReceiptItem(r, colorScheme)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptItem(ReceiptResponse receipt, ColorScheme colorScheme) {
    String period = receipt.allocations.isNotEmpty ? receipt.allocations.first.periodYYYYMM : '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.description_outlined, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.receiptNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text('Period: ${_formatPeriod(period)} • R ${receipt.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.print_outlined, size: 20),
            onPressed: () => _printReceipt(receipt),
            tooltip: 'Reprint Receipt',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.secondaryContainer.withOpacity(0.5),
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriod(String period) {
    if (period.length != 6) return period;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final year = period.substring(0, 4);
    final month = int.tryParse(period.substring(4, 6)) ?? 0;
    return (month >= 1 && month <= 12) ? '${months[month - 1]} $year' : period;
  }
}
