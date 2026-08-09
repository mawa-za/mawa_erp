import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../services/employment_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class EmploymentManagementScreen extends StatefulWidget {
  const EmploymentManagementScreen({super.key});

  @override
  State<EmploymentManagementScreen> createState() => _EmploymentManagementScreenState();
}

class _EmploymentManagementScreenState extends State<EmploymentManagementScreen> {
  final EmploymentService _service = EmploymentService();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _employees = const [];
  List<Map<String, dynamic>> _actions = const [];
  List<Map<String, dynamic>> _history = const [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_section == 0) {
        _employees = await _service.list(status: _status, query: _search.text);
      } else if (_section == 1) {
        _actions = await _service.listActions();
      } else {
        _history = await _service.history();
      }
    } catch (error) {
      _error = friendlyErrorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hire() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmploymentFormDialog(service: _service),
    );
    if (changed == true) {
      setState(() => _section = 1);
      await _load();
    }
  }

  Future<void> _edit(Map<String, dynamic> record) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmploymentFormDialog(service: _service, record: record),
    );
    if (changed == true) await _load();
  }

  Future<void> _action(Map<String, dynamic> record, String actionType) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmploymentActionDialog(
        service: _service,
        record: record,
        actionType: actionType,
      ),
    );
    if (changed == true) {
      setState(() => _section = 1);
      await _load();
    }
  }

  Future<void> _openBanking(Map<String, dynamic> record) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmployeeBankingDialog(
        employmentId: (record['id'] ?? '').toString(),
        service: _service,
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banking details submitted for approval.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width >= 1200 ? 32.0 : width >= 700 ? 24.0 : 16.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employment Management'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _section == 0
          ? FloatingActionButton.extended(
              onPressed: _hire,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Hire Employee'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
            child: Column(
              children: [
                _hero(context),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.badge_outlined), label: Text('Employees')),
                    ButtonSegment(value: 1, icon: Icon(Icons.approval_outlined), label: Text('Employment Actions')),
                    ButtonSegment(value: 2, icon: Icon(Icons.history_rounded), label: Text('History')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) {
                    setState(() => _section = value.first);
                    _load();
                  },
                ),
                const SizedBox(height: 16),
                if (_section == 0) _employeeTools(),
                Expanded(child: _content()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
          ),
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.groups_2_outlined, size: 46, color: scheme.onPrimaryContainer),
            const SizedBox(
              width: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee lifecycle control centre', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Hire, suspend, reinstate, terminate and rehire employees through controlled approvals. Employee numbers are allocated only after final hire approval.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeTools() {
    return Column(
      children: [
        TextField(
          controller: _search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            labelText: 'Search employee number, name, identity or position',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['ALL', 'ACTIVE', 'SUSPENDED', 'TERMINATED']
                .map((status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: _status == status,
                        onSelected: (_) {
                          setState(() => _status = status);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
    }
    if (_section == 0) return _employeeList();
    if (_section == 1) return _actionList();
    return _historyList();
  }

  Widget _employeeList() {
    if (_employees.isEmpty) return const Center(child: Text('No employee records found.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
        itemCount: _employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final record = _employees[index];
          final employee = _map(record['employee']);
          final status = (record['status'] ?? '').toString().toUpperCase();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(radius: 25, child: Icon(Icons.badge_outlined)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_employeeName(employee), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('${record['employeeNumber'] ?? 'Number pending'} • ${_positionLabel(record)}'),
                      const SizedBox(height: 3),
                      Text('${record['startDate'] ?? '-'} to ${record['endDate'] ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  _statusChip(status),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'details' && employee['id'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PartnerDetailScreen(
                          partnerId: employee['id'].toString(), title: 'Employee Details')));
                      } else if (value == 'edit') {
                        _edit(record);
                      } else if (value == 'banking') {
                        _openBanking(record);
                      } else {
                        _action(record, value);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'details', child: Text('Employee details')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit employment details')),
                      const PopupMenuItem(value: 'banking', child: Text('Banking details')),
                      if (status == 'ACTIVE') const PopupMenuItem(value: 'SUSPEND', child: Text('Request suspension')),
                      if (status == 'SUSPENDED') const PopupMenuItem(value: 'REINSTATE', child: Text('Request reinstatement')),
                      if (status == 'ACTIVE' || status == 'SUSPENDED')
                        const PopupMenuItem(value: 'TERMINATE', child: Text('Request termination')),
                      if (status == 'TERMINATED') const PopupMenuItem(value: 'REHIRE', child: Text('Request rehire')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionList() {
    if (_actions.isEmpty) return const Center(child: Text('No employment actions found.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final action = _actions[index];
          final employee = _map(action['employee']);
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: CircleAvatar(child: Icon(_actionIcon((action['actionType'] ?? '').toString()))),
              title: Text('${action['requestNumber'] ?? '-'} • ${_label(action['actionType'])}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${_employeeName(employee)}\nEffective ${action['effectiveDate'] ?? '-'} • ${action['reason'] ?? ''}'),
              ),
              isThreeLine: true,
              trailing: _statusChip((action['status'] ?? '').toString()),
            ),
          );
        },
      ),
    );
  }

  Widget _historyList() {
    if (_history.isEmpty) return const Center(child: Text('No employment history found.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final event = _history[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.history_toggle_off_rounded)),
              title: Text(_label(event['eventType']), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                'Employment ${event['employmentId'] ?? '-'} • ${event['effectiveDate'] ?? '-'}\n'
                '${event['oldStatus'] ?? '—'} → ${event['newStatus'] ?? '—'} • ${event['reason'] ?? ''}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    final color = normalized.contains('APPROVED') || normalized == 'ACTIVE'
        ? scheme.primaryContainer
        : normalized.contains('REJECT') || normalized == 'TERMINATED'
            ? scheme.errorContainer
            : scheme.secondaryContainer;
    return Chip(label: Text(_label(normalized)), backgroundColor: color, visualDensity: VisualDensity.compact);
  }

  IconData _actionIcon(String action) => switch (action.toUpperCase()) {
        'HIRE' => Icons.person_add_alt_1_rounded,
        'SUSPEND' => Icons.pause_circle_outline_rounded,
        'TERMINATE' => Icons.person_off_outlined,
        'REHIRE' => Icons.replay_circle_filled_outlined,
        'REINSTATE' => Icons.play_circle_outline_rounded,
        _ => Icons.approval_outlined,
      };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _employeeName(Map<String, dynamic> employee) {
    final values = [employee['name2'], employee['name3'], employee['name1']]
        .map((value) => (value ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return values.isEmpty ? 'Unknown employee' : values.join(' ');
  }

  static String _positionLabel(Map<String, dynamic> record) {
    final description = (record['positionDescription'] ?? '').toString().trim();
    return description.isNotEmpty ? description : _label(record['position']);
  }

  static String _label(dynamic value) {
    final text = (value ?? '').toString().replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (text.isEmpty) return 'Not specified';
    return text.split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}').join(' ');
  }
}

class _EmploymentFormDialog extends StatefulWidget {
  final EmploymentService service;
  final Map<String, dynamic>? record;
  const _EmploymentFormDialog({required this.service, this.record});

  @override
  State<_EmploymentFormDialog> createState() => _EmploymentFormDialogState();
}

class _EmploymentFormDialogState extends State<_EmploymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  Partner? _partner;
  String? _type;
  String? _position;
  String? _branch;
  String? _department;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;

  bool get editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record ?? const <String, dynamic>{};
    _type = _optionCode(record['type']);
    _position = _optionCode(record['position']);
    _branch = _optionCode(record['branch']);
    _department = _optionCode(record['department']);
    _startDate = DateTime.tryParse((record['startDate'] ?? '').toString()) ?? DateTime.now();
    _endDate = DateTime.tryParse((record['endDate'] ?? '').toString());
    if (record['employee'] is Map) _partner = Partner.fromJson(Map<String, dynamic>.from(record['employee'] as Map));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _selectPartner() async {
    final partner = await showDialog<Partner>(context: context, builder: (_) => const _PartnerPickerDialog());
    if (partner != null) setState(() => _partner = partner);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!editing && _partner == null) {
      _message('Select the person being hired.');
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      if (!editing) 'partnerId': _partner!.id,
      'type': _type,
      'position': _position,
      'branch': _branch,
      'department': _department,
      if (!editing) 'startDate': _date(_startDate),
      if (!editing) 'effectiveDate': _date(_startDate),
      if (!editing && _endDate != null) 'endDate': _date(_endDate!),
      if (!editing) 'reason': _reason.text.trim(),
    };
    try {
      if (editing) {
        await widget.service.update(widget.record!['id'].toString(), payload);
      } else {
        await widget.service.requestHire(payload);
      }
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(editing ? 'Edit Employment Details' : 'Submit Hire Request'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!editing)
                _notice(
                  Icons.auto_awesome_outlined,
                  'The employee number and live employment record will be created only after final approval.',
                ),
              if (editing)
                _notice(
                  Icons.lock_outline_rounded,
                  'Employee number and employment-period dates are protected. Use approved lifecycle actions to suspend, terminate or rehire.',
                ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                title: Text(_partner?.fullName ?? 'Select employee'),
                subtitle: Text(editing
                    ? (widget.record?['employeeNumber'] ?? '').toString()
                    : (_partner?.number ?? 'Choose an existing business partner')),
                trailing: editing ? null : OutlinedButton(onPressed: _selectPartner, child: const Text('Select')),
              ),
              const SizedBox(height: 12),
              AppDropdownField(
                field: 'EMPLOYMENT-TYPE', label: 'Employment Type', value: _type,
                onChanged: (value) => setState(() => _type = value),
                validator: (value) => value == null || value.isEmpty ? 'Employment type is required' : null,
              ),
              const SizedBox(height: 12),
              AppDropdownField(
                field: 'EMPLOYMENT-POSITION', label: 'Position', value: _position,
                onChanged: (value) => setState(() => _position = value),
                validator: (value) => value == null || value.isEmpty ? 'Position is required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppDropdownField(field: 'BRANCH', label: 'Branch', value: _branch, onChanged: (value) => setState(() => _branch = value))),
                const SizedBox(width: 12),
                Expanded(child: AppDropdownField(field: 'DEPARTMENT', label: 'Department', value: _department, onChanged: (value) => setState(() => _department = value))),
              ]),
              if (!editing) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dateButton('Start date', _startDate, (value) => setState(() => _startDate = value))),
                  const SizedBox(width: 12),
                  Expanded(child: _dateButton('End date', _endDate, (value) => setState(() => _endDate = value), optional: true)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason for hire'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Reason is required' : null,
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(editing ? Icons.save_outlined : Icons.approval_outlined),
          label: Text(_saving ? 'Saving...' : editing ? 'Save Changes' : 'Submit for Approval'),
        ),
      ],
    );
  }

  Widget _notice(IconData icon, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(text))]),
      );

  Widget _dateButton(String label, DateTime? value, ValueChanged<DateTime> changed, {bool optional = false}) {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        if (selected != null) changed(selected);
      },
      icon: const Icon(Icons.event_outlined),
      label: Text(value == null && optional ? '$label: Open ended' : '$label: ${_date(value!)}'),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  static String? _optionCode(dynamic value) {
    if (value is Map) return (value['code'] ?? '').toString();
    final text = (value ?? '').toString();
    return text.isEmpty ? null : text;
  }
}

class _EmploymentActionDialog extends StatefulWidget {
  final EmploymentService service;
  final Map<String, dynamic> record;
  final String actionType;
  const _EmploymentActionDialog({required this.service, required this.record, required this.actionType});

  @override
  State<_EmploymentActionDialog> createState() => _EmploymentActionDialogState();
}

class _EmploymentActionDialogState extends State<_EmploymentActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _effectiveDate;
  DateTime? _expectedReturnDate;
  DateTime? _endDate;
  String? _type;
  String? _position;
  String? _branch;
  String? _department;
  bool _affectsPayroll = false;
  bool _suspendAccess = false;
  bool _saving = false;
  int _attachmentCount = 0;
  late final String _attachmentObjectId;

  bool get isRehire => widget.actionType == 'REHIRE';
  bool get documentsRequired => widget.actionType == 'SUSPEND' || widget.actionType == 'TERMINATE';

  @override
  void initState() {
    super.initState();
    _attachmentObjectId = 'EMPLOYMENT-ACTION-${DateTime.now().microsecondsSinceEpoch}';
    final previousEnd = DateTime.tryParse((widget.record['endDate'] ?? '').toString());
    _effectiveDate = isRehire && previousEnd != null ? previousEnd.add(const Duration(days: 1)) : DateTime.now();
    _type = _optionCode(widget.record['type']);
    _position = _optionCode(widget.record['position']);
    _branch = _optionCode(widget.record['branch']);
    _department = _optionCode(widget.record['department']);
    _affectsPayroll = widget.actionType == 'TERMINATE' || widget.actionType == 'SUSPEND';
    _suspendAccess = widget.actionType == 'TERMINATE';
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (documentsRequired && _attachmentCount == 0) {
      _message('Upload at least one supporting document.');
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'effectiveDate': _date(_effectiveDate),
      'reason': _reason.text.trim(),
      'affectsPayroll': _affectsPayroll,
      'suspendSystemAccess': _suspendAccess,
      if (_expectedReturnDate != null) 'expectedReturnDate': _date(_expectedReturnDate!),
      if (isRehire) 'type': _type,
      if (isRehire) 'position': _position,
      if (isRehire) 'branch': _branch,
      if (isRehire) 'department': _department,
      if (isRehire && _endDate != null) 'endDate': _date(_endDate!),
      if (_attachmentCount > 0) 'attachmentObjectIds': [_attachmentObjectId],
    };
    try {
      await widget.service.requestAction(widget.record['id'].toString(), widget.actionType, payload);
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
    final employee = widget.record['employee'] is Map ? Map<String, dynamic>.from(widget.record['employee'] as Map) : <String, dynamic>{};
    final name = _EmploymentManagementScreenState._employeeName(employee);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('${_EmploymentManagementScreenState._label(widget.actionType)} Request'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${widget.record['employeeNumber'] ?? '-'} • ${_EmploymentManagementScreenState._positionLabel(widget.record)}'),
              ),
              const Divider(),
              _dateButton('Effective date', _effectiveDate, (value) => setState(() => _effectiveDate = value)),
              if (widget.actionType == 'SUSPEND') ...[
                const SizedBox(height: 10),
                _dateButton('Expected return date', _expectedReturnDate, (value) => setState(() => _expectedReturnDate = value), optional: true),
              ],
              if (isRehire) ...[
                const SizedBox(height: 12),
                AppDropdownField(field: 'EMPLOYMENT-TYPE', label: 'Employment Type', value: _type, onChanged: (value) => setState(() => _type = value), validator: _required),
                const SizedBox(height: 12),
                AppDropdownField(field: 'EMPLOYMENT-POSITION', label: 'Position', value: _position, onChanged: (value) => setState(() => _position = value), validator: _required),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AppDropdownField(field: 'BRANCH', label: 'Branch', value: _branch, onChanged: (value) => setState(() => _branch = value))),
                  const SizedBox(width: 12),
                  Expanded(child: AppDropdownField(field: 'DEPARTMENT', label: 'Department', value: _department, onChanged: (value) => setState(() => _department = value))),
                ]),
                const SizedBox(height: 12),
                _dateButton('New employment end date', _endDate, (value) => setState(() => _endDate = value), optional: true),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLines: 4,
                decoration: InputDecoration(labelText: '${_EmploymentManagementScreenState._label(widget.actionType)} reason'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Reason is required' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _affectsPayroll,
                onChanged: (value) => setState(() => _affectsPayroll = value),
                title: const Text('Affects payroll'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _suspendAccess,
                onChanged: (value) => setState(() => _suspendAccess = value),
                title: const Text('Suspend system access after approval'),
              ),
              const SizedBox(height: 8),
              Text(documentsRequired ? 'Supporting documents (required)' : 'Supporting documents', style: const TextStyle(fontWeight: FontWeight.w800)),
              AttachmentSection(
                objectId: _attachmentObjectId,
                onAttachmentCountChanged: (count) => _attachmentCount = count,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.approval_outlined),
          label: Text(_saving ? 'Submitting...' : 'Submit for Approval'),
        ),
      ],
    );
  }

  Widget _dateButton(String label, DateTime? value, ValueChanged<DateTime> changed, {bool optional = false}) => OutlinedButton.icon(
        onPressed: () async {
          final selected = await showDatePicker(context: context, firstDate: DateTime(1950), lastDate: DateTime(2100), initialDate: value ?? DateTime.now());
          if (selected != null) changed(selected);
        },
        icon: const Icon(Icons.event_outlined),
        label: Text(value == null && optional ? '$label: Not specified' : '$label: ${_date(value!)}'),
      );

  String? _required(String? value) => value == null || value.isEmpty ? 'Required' : null;
  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  static String? _optionCode(dynamic value) {
    if (value is Map) return (value['code'] ?? '').toString();
    final text = (value ?? '').toString();
    return text.isEmpty ? null : text;
  }
}

class _EmployeeBankingDialog extends StatefulWidget {
  final String employmentId;
  final EmploymentService service;

  const _EmployeeBankingDialog({required this.employmentId, required this.service});

  @override
  State<_EmployeeBankingDialog> createState() => _EmployeeBankingDialogState();
}

class _EmployeeBankingDialogState extends State<_EmployeeBankingDialog> {
  final _key = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  List<Map<String, dynamic>> _accounts = const [];
  String? _bankName;
  String? _accountType;
  String? _editingId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final accounts = await widget.service.getBankDetails(widget.employmentId);
      if (mounted) setState(() => _accounts = accounts);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _edit(Map<String, dynamic> bank) {
    setState(() {
      _editingId = bank['id']?.toString();
      _holder.text = (bank['accountHolder'] ?? '').toString();
      _account.text = (bank['accountNumber'] ?? '').toString();
      _bankName = bank['bankName']?.toString();
      _accountType = bank['accountType']?.toString();
    });
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (_bankName == null || _accountType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select bank name and account type.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.submitBankDetails(widget.employmentId, {
        if (_editingId != null) 'id': _editingId,
        'accountHolder': _holder.text.trim(),
        'accountNumber': _account.text.trim(),
        'bankName': _bankName,
        'accountType': _accountType,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Employee Banking Details'),
      content: SizedBox(
        width: 620,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _key,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Existing approved details remain active until the submitted change is approved. The universal branch code is assigned automatically from the selected bank.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      if (_accounts.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('CURRENT AND PREVIOUS DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ..._accounts.map((bank) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                (bank['status'] ?? '').toString().toUpperCase() == 'ACTIVE'
                                    ? Icons.verified_rounded
                                    : Icons.history_rounded,
                              ),
                              title: Text('${bank['bankName'] ?? '-'} • ${bank['accountNumber'] ?? '-'}'),
                              subtitle: Text('${bank['accountHolder'] ?? '-'} • ${bank['accountType'] ?? '-'} • Universal branch ${bank['branchCode'] ?? '-'} • ${bank['status'] ?? '-'}'),
                              trailing: (bank['status'] ?? '').toString().toUpperCase() == 'ACTIVE'
                                  ? IconButton(
                                      tooltip: 'Submit a change',
                                      onPressed: () => _edit(bank),
                                      icon: const Icon(Icons.edit_outlined),
                                    )
                                  : null,
                            )),
                      ],
                      const Divider(height: 28),
                      Text(_editingId == null ? 'NEW BANKING DETAILS' : 'CHANGE BANKING DETAILS',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _holder,
                        decoration: const InputDecoration(labelText: 'Account Holder'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      AppDropdownField(
                        field: 'BANK-NAME',
                        label: 'Bank Name',
                        value: _bankName,
                        onChanged: (value) => setState(() => _bankName = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _account,
                        decoration: const InputDecoration(labelText: 'Account Number'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null || !RegExp(r'^\d{5,20}$').hasMatch(value.trim())
                            ? 'Enter 5 to 20 numeric digits'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      AppDropdownField(
                        field: 'BANK-ACCOUNT-TYPE',
                        label: 'Account Type',
                        value: _accountType,
                        onChanged: (value) => setState(() => _accountType = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.approval_outlined),
          label: const Text('Submit for Approval'),
        ),
      ],
    );
  }
}

class _PartnerPickerDialog extends StatefulWidget {
  const _PartnerPickerDialog();

  @override
  State<_PartnerPickerDialog> createState() => _PartnerPickerDialogState();
}

class _PartnerPickerDialogState extends State<_PartnerPickerDialog> {
  final TextEditingController _query = TextEditingController();
  List<Partner> _partners = const [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final partners = await PartnerService().getPartners(query: _query.text);
      if (mounted) setState(() => _partners = partners.take(100).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select existing person to hire'),
      content: SizedBox(
        width: 600,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Name, partner number or identity number',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _partners.length,
                      itemBuilder: (_, index) {
                        final partner = _partners[index];
                        return ListTile(
                          title: Text(partner.fullName),
                          subtitle: Text(
                            '${partner.number} ${partner.identityNumber}'.trim(),
                          ),
                          onTap: () => Navigator.pop(context, partner),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
