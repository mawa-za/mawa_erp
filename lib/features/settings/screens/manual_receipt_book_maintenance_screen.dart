import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../../employment/services/employment_service.dart';
import '../models/manual_receipt_book.dart';
import '../services/manual_receipt_book_service.dart';

class ManualReceiptBookMaintenanceScreen extends StatefulWidget {
  const ManualReceiptBookMaintenanceScreen({super.key});

  @override
  State<ManualReceiptBookMaintenanceScreen> createState() => _ManualReceiptBookMaintenanceScreenState();
}

class _ManualReceiptBookMaintenanceScreenState extends State<ManualReceiptBookMaintenanceScreen> {
  final _service = ManualReceiptBookService();
  List<ManualReceiptBook> _books = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final books = await _service.list();
      if (mounted) setState(() { _books = books; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _edit([ManualReceiptBook? book]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ManualReceiptBookDialog(book: book, service: _service),
    );
    if (result == true) await _load();
  }

  Future<void> _close(ManualReceiptBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close receipt book'),
        content: Text('Close ${book.receiptBookNo}? New manual receipts and cashups cannot be captured against it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLOSE BOOK')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deactivate(book.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Receipt Book Maintenance'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('ADD RECEIPT BOOK'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _books.isEmpty
                  ? const Center(child: Text('No manual receipt books have been maintained.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _books.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(book.active ? Icons.menu_book_outlined : Icons.book_outlined),
                            ),
                            title: Text(book.receiptBookNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text([
                              if (book.description.isNotEmpty) book.description,
                              'Range: ${book.rangeLabel}',
                              if (book.assignedEmployeeName != null) 'Employee: ${book.assignedEmployeeName}',
                              if (book.assignedAreaName != null) 'Area: ${book.assignedAreaName}',
                            ].join('\n')),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(label: Text(book.status)),
                                IconButton(onPressed: () => _edit(book), icon: const Icon(Icons.edit_outlined)),
                                if (book.active)
                                  IconButton(onPressed: () => _close(book), icon: const Icon(Icons.block_outlined)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ManualReceiptBookDialog extends StatefulWidget {
  final ManualReceiptBook? book;
  final ManualReceiptBookService service;

  const _ManualReceiptBookDialog({this.book, required this.service});

  @override
  State<_ManualReceiptBookDialog> createState() => _ManualReceiptBookDialogState();
}

class _ManualReceiptBookDialogState extends State<_ManualReceiptBookDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bookNo;
  late final TextEditingController _description;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _notes;
  List<Map<String, dynamic>> _employees = const [];
  List<FieldOption> _areas = const [];
  String? _employeeId;
  String? _areaCode;
  String _status = 'ACTIVE';
  DateTime _effectiveFrom = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _bookNo = TextEditingController(text: book?.receiptBookNo ?? '');
    _description = TextEditingController(text: book?.description ?? '');
    _from = TextEditingController(text: book?.receiptFromNo ?? '');
    _to = TextEditingController(text: book?.receiptToNo ?? '');
    _notes = TextEditingController(text: book?.notes ?? '');
    _employeeId = book?.assignedEmployeeId;
    _areaCode = book?.assignedAreaCode;
    _status = book?.status ?? 'ACTIVE';
    if (book?.effectiveFrom != null) _effectiveFrom = DateTime.tryParse(book!.effectiveFrom!) ?? DateTime.now();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        EmploymentService().list(status: 'ACTIVE'),
        FieldService().getOptionsByField('SALES-AREA'),
      ]);
      if (mounted) setState(() {
        _employees = results[0] as List<Map<String, dynamic>>;
        _areas = results[1] as List<FieldOption>;
        final employeeIds = _employees.map(_employeePartnerId).where((id) => id.isNotEmpty).toSet();
        final areaCodes = _areas.map((area) => area.code).toSet();
        if (!employeeIds.contains(_employeeId)) _employeeId = null;
        if (!areaCodes.contains(_areaCode)) _areaCode = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
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
    return names.isEmpty ? (record['employeeNumber'] ?? _employeePartnerId(record)).toString() : names.join(' ');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final from = _from.text.trim();
    final to = _to.text.trim();
    if ((from.isEmpty) != (to.isEmpty)) {
      setState(() => _error = 'Receipt From and Receipt To must be supplied together.');
      return;
    }
    if (from.isNotEmpty && int.parse(from) > int.parse(to)) {
      setState(() => _error = 'Receipt From cannot be greater than Receipt To.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final payload = <String, dynamic>{
      'receiptBookNo': _bookNo.text.trim(),
      'description': _description.text.trim(),
      'receiptFromNo': _from.text.trim().isEmpty ? null : _from.text.trim(),
      'receiptToNo': _to.text.trim().isEmpty ? null : _to.text.trim(),
      'assignedEmployeeId': _employeeId,
      'assignedAreaCode': _areaCode,
      'status': _status,
      'active': _status == 'ACTIVE',
      'effectiveFrom': DateFormat('yyyy-MM-dd').format(_effectiveFrom),
      'notes': _notes.text.trim(),
    };
    try {
      if (widget.book == null) {
        await widget.service.create(payload);
      } else {
        await widget.service.update(widget.book!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _bookNo.dispose(); _description.dispose(); _from.dispose(); _to.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.book == null ? 'Add Manual Receipt Book' : 'Edit Manual Receipt Book'),
      content: SizedBox(
        width: 580,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _bookNo,
                        readOnly: widget.book != null,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Receipt Book Number *', border: OutlineInputBorder()),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _from, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Receipt From', border: OutlineInputBorder()), validator: _numberOrBlank)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _to, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Receipt To', border: OutlineInputBorder()), validator: _numberOrBlank)),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _employeeId,
                        decoration: const InputDecoration(labelText: 'Assigned Employee', border: OutlineInputBorder()),
                        items: _employees.map((record) {
                          final id = _employeePartnerId(record);
                          return DropdownMenuItem(value: id, child: Text(_employeeName(record)));
                        }).where((item) => item.value != null && item.value!.isNotEmpty).toList(),
                        onChanged: (value) => setState(() => _employeeId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _areaCode,
                        decoration: const InputDecoration(labelText: 'Assigned SALES-AREA', border: OutlineInputBorder()),
                        items: _areas.map((area) => DropdownMenuItem(value: area.code, child: Text(area.description))).toList(),
                        onChanged: (value) => setState(() => _areaCode = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                        items: const ['ACTIVE', 'CLOSED', 'CANCELLED', 'LOST']
                            .map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Effective From'),
                        subtitle: Text(DateFormat('yyyy-MM-dd').format(_effectiveFrom)),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _effectiveFrom,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _effectiveFrom = picked);
                        },
                      ),
                      TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('SAVE')),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  String? _numberOrBlank(String? value) => value != null && value.trim().isNotEmpty && int.tryParse(value.trim()) == null ? 'Digits only' : null;
}
