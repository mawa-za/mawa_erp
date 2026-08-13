import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../../employment/services/employment_service.dart';
import '../../partners/models/partner.dart';
import '../../settings/models/manual_receipt_book.dart';
import '../../settings/services/manual_receipt_book_service.dart';
import '../models/membership_detail.dart';
import '../services/membership_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class CaptureManualPremiumReceiptDialog extends StatefulWidget {
  final MembershipDetail membership;
  final Partner member;
  const CaptureManualPremiumReceiptDialog({super.key, required this.membership, required this.member});

  @override
  State<CaptureManualPremiumReceiptDialog> createState() => _CaptureManualPremiumReceiptDialogState();
}

class _CaptureManualPremiumReceiptDialogState extends State<CaptureManualPremiumReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _number = TextEditingController();
  final _reason = TextEditingController();
  final _attachmentId = TextEditingController();
  final _notes = TextEditingController();

  List<ManualReceiptBook> _books = const [];
  List<Map<String, dynamic>> _employees = const [];
  List<FieldOption> _areas = const [];
  String? _bookNo;
  String? _collectorEmployeeId;
  String? _locationAreaCode;
  DateTime _originalDate = DateTime.now();
  String _mode = 'LEGACY_CATCH_UP';
  String? _paymentMethod;
  String? _periodYYYYMM;
  bool _loadingOptions = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.membership.premium.toStringAsFixed(2);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        ManualReceiptBookService().list(activeOnly: true),
        EmploymentService().list(status: 'ACTIVE'),
        FieldService().getOptionsByField('SALES-AREA'),
      ]);
      if (!mounted) return;
      final books = results[0] as List<ManualReceiptBook>;
      final employees = results[1] as List<Map<String, dynamic>>;
      final areas = results[2] as List<FieldOption>;
      final employeeIds = employees.map(_employeePartnerId).where((id) => id.isNotEmpty).toSet();
      final areaCodes = areas.map((area) => area.code).toSet();
      final firstBook = books.isEmpty ? null : books.first;
      setState(() {
        _books = books;
        _employees = employees;
        _areas = areas;
        _bookNo = firstBook?.receiptBookNo;
        _collectorEmployeeId = employeeIds.contains(firstBook?.assignedEmployeeId)
            ? firstBook?.assignedEmployeeId
            : null;
        _locationAreaCode = areaCodes.contains(firstBook?.assignedAreaCode)
            ? firstBook?.assignedAreaCode
            : null;
        _loadingOptions = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadingOptions = false; _error = friendlyErrorMessage(e); });
    }
  }

  List<String> get _paymentPeriods {
    final now = DateTime.now();
    final dateText = widget.membership.startDate ??
        widget.membership.joinDate ??
        widget.membership.createdAt;
    final parsedStart = dateText == null ? null : DateTime.tryParse(dateText);
    final startYear = parsedStart?.year ?? now.year - 10;
    final periods = <String>[];
    for (var year = startYear; year <= now.year + 1; year++) {
      for (var month = 1; month <= 12; month++) {
        periods.add('$year${month.toString().padLeft(2, '0')}');
      }
    }
    return periods.reversed.toList();
  }

  String _formatPaymentPeriod(String period) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final year = int.tryParse(period.substring(0, 4));
    final month = int.tryParse(period.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) return period;
    return '${months[month - 1]} $year';
  }

  String _employeePartnerId(Map<String, dynamic> record) {
    final employee = record['employee'];
    return employee is Map ? (employee['id'] ?? '').toString() : '';
  }

  String _employeeName(Map<String, dynamic> record) {
    final employee = record['employee'];
    if (employee is! Map) return (record['employeeNumber'] ?? '').toString();
    final names = [employee['name2'], employee['name3'], employee['name1']]
        .map((value) => (value ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return names.isEmpty
        ? (record['employeeNumber'] ?? _employeePartnerId(record)).toString()
        : names.join(' ');
  }

  ManualReceiptBook? get _selectedBook {
    for (final book in _books) {
      if (book.receiptBookNo == _bookNo) return book;
    }
    return null;
  }

  String? _validateReceiptNumber(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null) return 'Enter a numeric receipt number';
    final book = _selectedBook;
    final from = int.tryParse(book?.receiptFromNo ?? '');
    final to = int.tryParse(book?.receiptToNo ?? '');
    if (from != null && number < from) return 'Below book range ($from – ${book!.receiptToNo})';
    if (to != null && number > to) return 'Above book range (${book!.receiptFromNo} – $to)';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await MembershipService().captureManualPremiumReceipt(
        membershipId: widget.membership.id,
        amountCents: (double.parse(_amount.text.replaceAll(',', '.')) * 100).round(),
        paymentMethod: _paymentMethod!,
        periodYYYYMM: _periodYYYYMM!,
        originalReceiptDate: _originalDate,
        receiptBookNo: _bookNo!,
        manualReceiptNo: _number.text.trim(),
        originalCollectorEmployeeId: _collectorEmployeeId!,
        locationAreaCode: _locationAreaCode!,
        captureMode: _mode,
        lateCaptureReason: _reason.text.trim(),
        proofAttachmentId: _attachmentId.text.trim(),
        createdBy: prefs.getString('userId') ?? 'unknown',
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyErrorMessage(e); });
    }
  }

  @override
  void dispose() {
    for (final controller in [_amount, _number, _reason, _attachmentId, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capture Manual Premium Receipt'),
      content: SizedBox(
        width: 600,
        child: _loadingOptions
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${widget.member.fullName} • ${widget.membership.membershipNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (_books.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No active manual receipt book exists. Maintain a receipt book under System Configuration before capturing a manual receipt.'),
                        ),
                      ),
                    SearchableDropdownFormField<String>(
                      value: _mode,
                      decoration: const InputDecoration(labelText: 'Capture type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'LEGACY_CATCH_UP', child: Text('Outstanding legacy receipt')),
                        DropdownMenuItem(value: 'MANUAL_EMERGENCY', child: Text('Post-go-live emergency receipt')),
                      ],
                      onChanged: (value) => setState(() => _mode = value!),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: SearchableDropdownFormField<String>(
                          value: _bookNo,
                          decoration: const InputDecoration(labelText: 'Receipt book number *', border: OutlineInputBorder()),
                          items: _books.map((book) => DropdownMenuItem(
                            value: book.receiptBookNo,
                            child: Text('${book.receiptBookNo} (${book.rangeLabel})'),
                          )).toList(),
                          onChanged: (value) {
                            ManualReceiptBook? book;
                            for (final item in _books) {
                              if (item.receiptBookNo == value) { book = item; break; }
                            }
                            final employeeIds = _employees.map(_employeePartnerId).where((id) => id.isNotEmpty).toSet();
                            final areaCodes = _areas.map((area) => area.code).toSet();
                            setState(() {
                              _bookNo = value;
                              _collectorEmployeeId = employeeIds.contains(book?.assignedEmployeeId)
                                  ? book?.assignedEmployeeId
                                  : null;
                              _locationAreaCode = areaCodes.contains(book?.assignedAreaCode)
                                  ? book?.assignedAreaCode
                                  : null;
                              _number.clear();
                            });
                          },
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _number,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Receipt number *', border: OutlineInputBorder()),
                          validator: _validateReceiptNumber,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Original receipt date'),
                      subtitle: Text('${_originalDate.year}-${_originalDate.month.toString().padLeft(2, '0')}-${_originalDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _originalDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _originalDate = date);
                      },
                    ),
                    SearchableDropdownFormField<String>(
                      value: _periodYYYYMM,
                      decoration: const InputDecoration(
                        labelText: 'Payment period *',
                        helperText: 'Select the membership premium period this manual receipt pays.',
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentPeriods
                          .map((period) => DropdownMenuItem(value: period, child: Text(_formatPaymentPeriod(period))))
                          .toList(),
                      onChanged: (value) => setState(() => _periodYYYYMM = value),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          readOnly: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount', helperText: 'Amount is fixed to the membership monthly premium.', prefixText: 'R ', border: OutlineInputBorder()),
                          validator: (value) {
                            final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
                            return amount == null || amount <= 0 ? 'Enter a valid amount' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
                          items: const ['CASH', 'CARD', 'EFT', 'OTHER']
                              .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) => setState(() => _paymentMethod = value),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      value: _collectorEmployeeId,
                      decoration: const InputDecoration(labelText: 'Original collector/cashier *', border: OutlineInputBorder()),
                      items: _employees.map((record) {
                        final id = _employeePartnerId(record);
                        return DropdownMenuItem<String>(value: id, child: Text(_employeeName(record)));
                      }).where((item) => item.value != null && item.value!.isNotEmpty).toList(),
                      onChanged: (value) => setState(() => _collectorEmployeeId = value),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      value: _locationAreaCode,
                      decoration: const InputDecoration(labelText: 'Location/branch (SALES-AREA) *', border: OutlineInputBorder()),
                      items: _areas.map((area) => DropdownMenuItem(value: area.code, child: Text(area.description))).toList(),
                      onChanged: (value) => setState(() => _locationAreaCode = value),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    if (_mode == 'MANUAL_EMERGENCY') ...[
                      const SizedBox(height: 12),
                      TextFormField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Emergency/late capture reason', border: OutlineInputBorder()), validator: _required),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _attachmentId,
                        decoration: const InputDecoration(
                          labelText: 'Carbon-copy proof attachment ID',
                          helperText: 'Upload the proof under Documents first, then enter its attachment ID.',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ]),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || _loadingOptions || _books.isEmpty ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Capture and update membership'),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}
