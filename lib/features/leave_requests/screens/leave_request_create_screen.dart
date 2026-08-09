import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/attachment_section.dart';
import '../../employment/services/employment_service.dart';
import '../models/leave_request.dart';
import '../services/leave_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveRequestCreateScreen extends StatefulWidget {
  const LeaveRequestCreateScreen({super.key});

  @override
  State<LeaveRequestCreateScreen> createState() => _LeaveRequestCreateScreenState();
}

class _LeaveRequestCreateScreenState extends State<LeaveRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leaveService = LeaveService();
  final _employmentService = EmploymentService();
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  late final String _attachmentObjectId;

  List<Map<String, dynamic>> _employees = const [];
  List<Map<String, dynamic>> _leaveTypes = const [];
  Map<String, dynamic>? _employment;
  Map<String, dynamic>? _leaveType;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  LeaveRequestPreview? _preview;
  bool _loading = true;
  bool _calculating = false;
  bool _saving = false;
  int _attachmentCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _attachmentObjectId = 'LEAVE-REQUEST-DOC-${DateTime.now().microsecondsSinceEpoch}';
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _employmentService.list(status: 'ACTIVE'),
        _leaveService.getLeaveTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = values[0];
        _leaveTypes = values[1];
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _payload({bool includeAttachments = false}) => {
        if (_employment != null) 'employmentId': _employment!['id'],
        if (_employment?['employee'] is Map) 'employee': (_employment!['employee'] as Map)['id'],
        if (_leaveType != null) 'leaveTypeId': _leaveType!['id'],
        if (_leaveType != null) 'type': _leaveType!['code'],
        'startDate': _date(_start),
        'endDate': _date(_end),
        if (_amount.text.trim().isNotEmpty) 'requestedAmount': double.tryParse(_amount.text.trim()),
        if (_leaveType?['unit'] != null) 'unit': _leaveType!['unit'],
        'reason': _reason.text.trim(),
        if (includeAttachments && _attachmentCount > 0) 'attachmentObjectIds': [_attachmentObjectId],
      };

  Future<void> _calculate() async {
    if (_employment == null || _leaveType == null) {
      _message('Select an employee and leave type first.');
      return;
    }
    if (_end.isBefore(_start)) {
      _message('End date cannot be before start date.');
      return;
    }
    setState(() => _calculating = true);
    try {
      final preview = await _leaveService.preview(_payload());
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(() => _preview = null);
        _message(friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _calculate();
    final preview = _preview;
    if (preview == null || !preview.allowed) {
      _message(preview?.message.isNotEmpty == true ? preview!.message : 'The leave request is not allowed.');
      return;
    }
    if (preview.supportingDocumentRequired && _attachmentCount == 0) {
      _message('Upload the required supporting document.');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await _leaveService.createLeaveRequest(_payload(includeAttachments: true));
      await _leaveService.submitLeaveRequest(created.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(friendlyErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Leave Request')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ])),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('New Leave Request')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _header(),
                const SizedBox(height: 16),
                _section('Request details', Icons.event_available_outlined, [
                  DropdownButtonFormField<String>(
                    value: _employment?['id']?.toString(),
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: _employees.map((employment) => DropdownMenuItem(
                      value: employment['id'].toString(),
                      child: Text('${_employeeName(employment)} • ${employment['employeeNumber'] ?? '-'}'),
                    )).toList(),
                    onChanged: (id) => setState(() {
                      _employment = _employees.where((item) => item['id'].toString() == id).firstOrNull;
                      _preview = null;
                    }),
                    validator: (value) => value == null ? 'Employee is required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _leaveType?['id']?.toString(),
                    decoration: const InputDecoration(labelText: 'Leave type'),
                    items: _leaveTypes.map((type) => DropdownMenuItem(
                      value: type['id'].toString(),
                      child: Text('${type['name']} (${type['unit'] ?? 'DAYS'})'),
                    )).toList(),
                    onChanged: (id) => setState(() {
                      _leaveType = _leaveTypes.where((item) => item['id'].toString() == id).firstOrNull;
                      _amount.clear();
                      _preview = null;
                    }),
                    validator: (value) => value == null ? 'Leave type is required' : null,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 620;
                    final children = [
                      Expanded(child: _dateField('Start date', _start, (value) => setState(() { _start = value; if (_end.isBefore(value)) _end = value; _preview = null; }))),
                      const SizedBox(width: 12, height: 12),
                      Expanded(child: _dateField('End date', _end, (value) => setState(() { _end = value; _preview = null; }))),
                    ];
                    return narrow
                        ? Column(children: [SizedBox(width: double.infinity, child: _dateField('Start date', _start, (value) => setState(() { _start = value; if (_end.isBefore(value)) _end = value; _preview = null; }))), const SizedBox(height: 12), SizedBox(width: double.infinity, child: _dateField('End date', _end, (value) => setState(() { _end = value; _preview = null; })) )])
                        : Row(children: children);
                  }),
                  if (_leaveType?['allowHalfDay'] == true || (_leaveType?['unit'] ?? '').toString().toUpperCase() == 'HOURS') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Requested ${(_leaveType?['unit'] ?? 'amount').toString().toLowerCase()}',
                        helperText: 'Leave blank to use the calculated working time.',
                      ),
                      onChanged: (_) => setState(() => _preview = null),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Reason is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _calculating ? null : _calculate,
                      icon: _calculating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_outlined),
                      label: const Text('Calculate Leave'),
                    ),
                  ),
                ]),
                if (_preview != null) ...[
                  const SizedBox(height: 16),
                  _previewCard(_preview!),
                ],
                const SizedBox(height: 16),
                _section('Supporting documents', Icons.attach_file_rounded, [
                  Text(_preview?.supportingDocumentRequired == true
                      ? 'A supporting document is required under the selected leave profile.'
                      : 'Attach supporting documents where relevant.'),
                  AttachmentSection(
                    objectId: _attachmentObjectId,
                    onAttachmentCountChanged: (count) => _attachmentCount = count,
                  ),
                ]),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Submitting...' : 'Create & Submit for Approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.beach_access_outlined)),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Leave request', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Approvers are resolved automatically from the configured approval workflow. Working days and balances are calculated by MAWA.'),
            ])),
          ]),
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 18),
            ...children,
          ]),
        ),
      );

  Widget _previewCard(LeaveRequestPreview preview) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: preview.allowed ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(preview.allowed ? Icons.check_circle_outline : Icons.error_outline), const SizedBox(width: 8), Text(preview.allowed ? 'Leave calculation' : 'Request blocked', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
          const SizedBox(height: 14),
          Wrap(spacing: 24, runSpacing: 12, children: [
            _metric('Profile', preview.leaveProfileName),
            _metric('Calendar', preview.workingCalendarName),
            _metric('Requested', '${preview.requestedAmount.toStringAsFixed(2)} ${preview.unit.toLowerCase()}'),
            _metric('Available', preview.availableBalance.toStringAsFixed(2)),
            _metric('Projected', preview.projectedBalance.toStringAsFixed(2)),
            _metric('Assignment', preview.assignmentSource),
          ]),
          if (preview.message.isNotEmpty) ...[const SizedBox(height: 12), Text(preview.message)],
        ]),
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 3), Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700))]));

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> changed) => OutlinedButton.icon(
        onPressed: () async {
          final date = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: value);
          if (date != null) changed(date);
        },
        icon: const Icon(Icons.event_outlined),
        label: Text('$label: ${_date(value)}'),
      );

  String _employeeName(Map<String, dynamic> employment) {
    final employee = employment['employee'] is Map ? Map<String, dynamic>.from(employment['employee'] as Map) : <String, dynamic>{};
    final names = [employee['name2'], employee['name3'], employee['name1']]
        .map((value) => (value ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return names.isEmpty ? 'Unknown employee' : names.join(' ');
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
