import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../services/employment_service.dart';

class EmploymentManagementScreen extends StatefulWidget {
  const EmploymentManagementScreen({super.key});

  @override
  State<EmploymentManagementScreen> createState() =>
      _EmploymentManagementScreenState();
}

class _EmploymentManagementScreenState
    extends State<EmploymentManagementScreen> {
  final EmploymentService _service = EmploymentService();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';

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
      final rows = await _service.list(status: _status, query: _search.text);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? record]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmploymentDialog(record: record, service: _service),
    );
    if (changed == true) await _load();
  }

  Future<void> _terminate(Map<String, dynamic> record) async {
    final employee = _employee(record);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terminate employment'),
        content: Text(
          'Terminate ${_employeeName(employee)}? The employee role will be removed and the employment end date set to today.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.terminate((record['id'] ?? '').toString());
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _rehire(Map<String, dynamic> record) async {
    final start = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (start == null) return;
    try {
      await _service.rehire(
        (record['id'] ?? '').toString(),
        startDate: DateFormat('yyyy-MM-dd').format(start),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Employment Management'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Hire Employee'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Search employees',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: ['ALL', 'ACTIVE', 'SUSPENDED', 'TERMINATED']
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: _status == status,
                        onSelected: (_) {
                          setState(() => _status = status);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No employee records found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final record = _rows[index];
          final employee = _employee(record);
          final status = (record['status'] ?? '').toString().toUpperCase();
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
              title: Text(
                _employeeName(employee),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${record['employeeNumber'] ?? 'No employee number'} • ${record['position'] ?? 'No position'}\n${record['startDate'] ?? '-'} to ${record['endDate'] ?? '-'}',
                ),
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openForm(record);
                  if (value == 'terminate') _terminate(record);
                  if (value == 'rehire') _rehire(record);
                  if (value == 'partner' && employee['id'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PartnerDetailScreen(
                          partnerId: employee['id'].toString(),
                          title: 'Employee Details',
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'partner', child: Text('Employee details')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit employment')),
                  if (status == 'TERMINATED')
                    const PopupMenuItem(value: 'rehire', child: Text('Rehire')),
                  if (status != 'TERMINATED')
                    const PopupMenuItem(value: 'terminate', child: Text('Terminate')),
                ],
              ),
              onTap: () => _openForm(record),
            ),
          );
        },
      ),
    );
  }

  static Map<String, dynamic> _employee(Map<String, dynamic> row) =>
      row['employee'] is Map
          ? Map<String, dynamic>.from(row['employee'] as Map)
          : <String, dynamic>{};

  static String _employeeName(Map<String, dynamic> employee) {
    final values = [employee['name2'], employee['name3'], employee['name1']]
        .map((e) => (e ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return values.isEmpty ? 'Unknown employee' : values.join(' ');
  }
}

class _EmploymentDialog extends StatefulWidget {
  final Map<String, dynamic>? record;
  final EmploymentService service;

  const _EmploymentDialog({required this.record, required this.service});

  @override
  State<_EmploymentDialog> createState() => _EmploymentDialogState();
}

class _EmploymentDialogState extends State<_EmploymentDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _position;
  late final TextEditingController _branch;
  late final TextEditingController _department;
  DateTime _start = DateTime.now();
  DateTime? _end;
  Partner? _partner;
  bool _saving = false;
  String _type = 'PERMANENT';

  bool get editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record ?? const <String, dynamic>{};
    _number = TextEditingController(text: (r['employeeNumber'] ?? '').toString());
    _position = TextEditingController(text: (r['position'] ?? '').toString());
    _branch = TextEditingController(text: _optionCode(r['branch']));
    _department = TextEditingController(text: _optionCode(r['department']));
    _type = _optionCode(r['type']).isEmpty ? 'PERMANENT' : _optionCode(r['type']);
    _start = DateTime.tryParse((r['startDate'] ?? '').toString()) ?? DateTime.now();
    _end = DateTime.tryParse((r['endDate'] ?? '').toString());
    if (r['employee'] is Map) {
      _partner = Partner.fromJson(Map<String, dynamic>.from(r['employee'] as Map));
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _position.dispose();
    _branch.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _selectPartner() async {
    final selected = await showDialog<Partner>(
      context: context,
      builder: (_) => const _PartnerPickerDialog(),
    );
    if (selected != null) setState(() => _partner = selected);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (!editing && _partner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the person being hired.')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      if (!editing) 'partnerId': _partner?.id,
      'employeeNumber': _number.text.trim(),
      'position': _position.text.trim(),
      'type': _type,
      'branch': _branch.text.trim().toUpperCase(),
      'department': _department.text.trim().toUpperCase(),
      'startDate': DateFormat('yyyy-MM-dd').format(_start),
      if (_end != null) 'endDate': DateFormat('yyyy-MM-dd').format(_end!),
    };
    try {
      if (editing) {
        await widget.service.update(widget.record!['id'].toString(), payload);
      } else {
        await widget.service.hire(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? 'Edit Employment Record' : 'Hire Employee'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(_partner?.fullName ?? 'Select employee'),
                  subtitle: Text(_partner?.number ?? 'Choose an existing partner record'),
                  trailing: editing
                      ? null
                      : OutlinedButton(
                          onPressed: _selectPartner,
                          child: const Text('Select'),
                        ),
                ),
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Employee Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _position,
                  decoration: const InputDecoration(labelText: 'Position'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Position is required'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Employment Type'),
                  items: const [
                    DropdownMenuItem(value: 'PERMANENT', child: Text('Permanent')),
                    DropdownMenuItem(value: 'TEMPORARY', child: Text('Temporary')),
                    DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
                    DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'PERMANENT'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _branch,
                        decoration: const InputDecoration(labelText: 'Branch Code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _department,
                        decoration: const InputDecoration(labelText: 'Department Code'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(1950),
                            lastDate: DateTime(2100),
                            initialDate: _start,
                          );
                          if (date != null) setState(() => _start = date);
                        },
                        icon: const Icon(Icons.event),
                        label: Text('Start ${DateFormat('yyyy-MM-dd').format(_start)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: _start,
                            lastDate: DateTime(2100),
                            initialDate: _end ?? _start,
                          );
                          if (date != null) setState(() => _end = date);
                        },
                        icon: const Icon(Icons.event_busy),
                        label: Text(_end == null
                            ? 'No end date'
                            : 'End ${DateFormat('yyyy-MM-dd').format(_end!)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  static String _optionCode(dynamic value) {
    if (value is Map) return (value['code'] ?? '').toString();
    return (value ?? '').toString();
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
      title: const Text('Select Employee Partner'),
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
