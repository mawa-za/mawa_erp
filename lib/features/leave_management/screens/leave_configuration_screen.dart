import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../employment/services/employment_service.dart';
import '../services/leave_configuration_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveConfigurationScreen extends StatefulWidget {
  final int initialTab;
  const LeaveConfigurationScreen({super.key, this.initialTab = 0});

  @override
  State<LeaveConfigurationScreen> createState() => _LeaveConfigurationScreenState();
}

class _LeaveConfigurationScreenState extends State<LeaveConfigurationScreen>
    with SingleTickerProviderStateMixin {
  final _service = LeaveConfigurationService();
  final _employmentService = EmploymentService();
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _types = const [];
  List<Map<String, dynamic>> _profiles = const [];
  List<Map<String, dynamic>> _calendars = const [];
  List<Map<String, dynamic>> _employeeAssignments = const [];
  List<Map<String, dynamic>> _positionAssignments = const [];
  List<Map<String, dynamic>> _balances = const [];
  List<Map<String, dynamic>> _adjustments = const [];
  List<Map<String, dynamic>> _employments = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this, initialIndex: widget.initialTab.clamp(0, 4));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _service.leaveTypes(),
        _service.profiles(),
        _service.calendars(),
        _service.employeeAssignments(),
        _service.positionAssignments(),
        _service.balances(),
        _service.adjustments(),
        _employmentService.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _types = values[0];
        _profiles = values[1];
        _calendars = values[2];
        _employeeAssignments = values[3];
        _positionAssignments = values[4];
        _balances = values[5];
        _adjustments = values[6];
        _employments = values[7];
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Configuration'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.category_outlined), text: 'Leave Types'),
            Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Leave Profiles'),
            Tab(icon: Icon(Icons.today_outlined), text: 'Working Calendars'),
            Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Assignments'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Balances'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1450),
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _leaveTypesTab(),
                        _profilesTab(),
                        _calendarsTab(),
                        _assignmentsTab(),
                        _balancesTab(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _leaveTypesTab() => _configurationList(
        title: 'Leave Types',
        description: 'Maintain paid or unpaid leave, day or hour units, document rules, limits and calendar inclusion behaviour.',
        icon: Icons.category_outlined,
        actionLabel: 'Add Leave Type',
        onAction: () => _editLeaveType(),
        children: _types.map((type) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: CircleAvatar(child: Icon(type['paid'] == true ? Icons.payments_outlined : Icons.money_off_outlined)),
            title: Text('${type['name']} (${type['code']})', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${type['unit'] ?? 'DAYS'} • ${type['requiresApproval'] == true ? 'Approval required' : 'No approval'} • ${type['requiresSupportingDocument'] == true ? 'Document controlled' : 'Document optional'}'),
            trailing: Wrap(spacing: 4, children: [
              if (type['active'] != true) const Chip(label: Text('Inactive')),
              IconButton(tooltip: 'Edit', onPressed: () => _editLeaveType(type), icon: const Icon(Icons.edit_outlined)),
            ]),
          ),
        )).toList(),
      );

  Widget _profilesTab() => _configurationList(
        title: 'Leave Profiles',
        description: 'Configure entitlements, accrual methods, pro-rating, carry-over, waiting periods and profile-specific document rules.',
        icon: Icons.rule_folder_outlined,
        actionLabel: 'Add Leave Profile',
        onAction: () => _editProfile(),
        children: _profiles.map((profile) {
          final rules = profile['rules'] is List ? profile['rules'] as List : const [];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: CircleAvatar(child: Icon(profile['defaultProfile'] == true ? Icons.star_rounded : Icons.rule_outlined)),
              title: Text('${profile['name']} (${profile['code']})', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${profile['workingCalendarName'] ?? 'No calendar'} • ${rules.length} leave rule${rules.length == 1 ? '' : 's'}${profile['defaultProfile'] == true ? ' • Tenant default' : ''}'),
              trailing: IconButton(tooltip: 'Edit', onPressed: () => _editProfile(profile), icon: const Icon(Icons.edit_outlined)),
            ),
          );
        }).toList(),
      );

  Widget _calendarsTab() => _configurationList(
        title: 'Working Calendars',
        description: 'Define the tenant work week, daily hours and holidays used by backend leave calculations.',
        icon: Icons.today_outlined,
        actionLabel: 'Add Calendar',
        onAction: () => _editCalendar(),
        children: _calendars.map((calendar) {
          final holidays = calendar['holidays'] is List ? calendar['holidays'] as List : const [];
          final days = <String>[];
          for (final item in const [('Mon', 'mondayWorking'), ('Tue', 'tuesdayWorking'), ('Wed', 'wednesdayWorking'), ('Thu', 'thursdayWorking'), ('Fri', 'fridayWorking'), ('Sat', 'saturdayWorking'), ('Sun', 'sundayWorking')]) {
            if (calendar[item.$2] == true) days.add(item.$1);
          }
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(child: Icon(Icons.calendar_month_outlined)),
              title: Text('${calendar['name']} (${calendar['code']})', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${days.join(', ')} • ${calendar['hoursPerDay'] ?? 8} hours/day • ${holidays.length} holiday${holidays.length == 1 ? '' : 's'}'),
              trailing: IconButton(tooltip: 'Edit', onPressed: () => _editCalendar(calendar), icon: const Icon(Icons.edit_outlined)),
            ),
          );
        }).toList(),
      );

  Widget _assignmentsTab() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionHeader(
            'Leave Profile Assignments',
            'Employee-specific assignments take precedence over position assignments, which take precedence over the tenant default profile.',
            Icons.assignment_ind_outlined,
            actions: [
              OutlinedButton.icon(onPressed: () => _assignPosition(), icon: const Icon(Icons.work_outline_rounded), label: const Text('Assign Position')),
              FilledButton.icon(onPressed: () => _assignEmployee(), icon: const Icon(Icons.person_outline_rounded), label: const Text('Assign Employee')),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Employee assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_employeeAssignments.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No employee-specific leave profile assignments.'))),
          ..._employeeAssignments.map((assignment) => _assignmentCard(assignment, employee: true)),
          const SizedBox(height: 22),
          const Text('Position assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_positionAssignments.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No position leave profile assignments.'))),
          ..._positionAssignments.map((assignment) => _assignmentCard(assignment, employee: false)),
        ],
      );

  Widget _balancesTab() => DefaultTabController(
        length: 2,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _sectionHeader(
              'Leave Balances & Adjustments',
              'Balances are backed by an immutable ledger. Manual adjustments require evidence and approval.',
              Icons.account_balance_wallet_outlined,
              actions: [FilledButton.icon(onPressed: () => _requestAdjustment(), icon: const Icon(Icons.tune_rounded), label: const Text('Request Adjustment'))],
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Employee Balances'), Tab(text: 'Adjustment Requests')]),
          Expanded(child: TabBarView(children: [_balanceList(), _adjustmentList()])),
        ]),
      );

  Widget _configurationList({required String title, required String description, required IconData icon, required String actionLabel, required VoidCallback onAction, required List<Widget> children}) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionHeader(title, description, icon, actions: [FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel))]),
          const SizedBox(height: 16),
          if (children.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No configuration records found.'))),
          ...children,
        ],
      );

  Widget _sectionHeader(String title, String description, IconData icon, {List<Widget> actions = const []}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(radius: 26, child: Icon(icon)),
              SizedBox(width: 700, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(description)])),
              ...actions,
            ],
          ),
        ),
      );

  Widget _assignmentCard(Map<String, dynamic> assignment, {required bool employee}) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(child: Icon(employee ? Icons.person_outline_rounded : Icons.work_outline_rounded)),
          title: Text(employee ? '${assignment['employeeName'] ?? 'Employee'} (${assignment['employeeNumber'] ?? '-'})' : _label(assignment['positionCode']), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${assignment['leaveProfileName'] ?? '-'} • ${assignment['effectiveFrom'] ?? '-'} to ${assignment['effectiveTo'] ?? '-'}${assignment['assignmentSource'] != null ? ' • ${assignment['assignmentSource']}' : ''}'),
          trailing: assignment['active'] == true ? const Chip(label: Text('Active')) : const Chip(label: Text('Inactive')),
        ),
      );

  Widget _balanceList() {
    if (_balances.isEmpty) return const Center(child: Text('No leave balances found.'));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _balances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final balance = _balances[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(17),
            leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
            title: Text('${balance['employeeName'] ?? '-'} • ${balance['leaveTypeName'] ?? balance['leaveTypeCode']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${balance['employeeNumber'] ?? '-'} • Cycle ${balance['cycleStart'] ?? '-'} to ${balance['cycleEnd'] ?? '-'}\nAccrued ${balance['accrued'] ?? 0} • Taken ${balance['taken'] ?? 0} • Adjusted ${balance['adjusted'] ?? 0}'),
            isThreeLine: true,
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Available'), Text('${balance['availableBalance'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
            onTap: () => _showLedger(balance['employmentId']?.toString() ?? ''),
          ),
        );
      },
    );
  }

  Widget _adjustmentList() {
    if (_adjustments.isEmpty) return const Center(child: Text('No leave balance adjustment requests found.'));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _adjustments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = _adjustments[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(17),
            leading: const CircleAvatar(child: Icon(Icons.tune_rounded)),
            title: Text('${item['requestNumber'] ?? '-'} • ${item['employeeName'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${item['leaveTypeName'] ?? '-'}: ${item['adjustmentAmount'] ?? 0} effective ${item['effectiveDate'] ?? '-'}\n${item['reason'] ?? ''}'),
            isThreeLine: true,
            trailing: Chip(label: Text(_label(item['status']))),
          ),
        );
      },
    );
  }

  Future<void> _editLeaveType([Map<String, dynamic>? existing]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeaveTypeDialog(existing: existing),
    );
    if (result == null) return;
    await _save(() => _service.saveLeaveType(result), 'Leave type saved.');
  }

  Future<void> _editCalendar([Map<String, dynamic>? existing]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CalendarDialog(existing: existing),
    );
    if (result == null) return;
    await _save(() => _service.saveCalendar(result), 'Working calendar saved.');
  }

  Future<void> _editProfile([Map<String, dynamic>? existing]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfileDialog(existing: existing, leaveTypes: _types.where((item) => item['active'] == true).toList(), calendars: _calendars.where((item) => item['active'] == true).toList()),
    );
    if (result == null) return;
    await _save(() => _service.saveProfile(result), 'Leave profile saved.');
  }

  Future<void> _assignEmployee() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EmployeeAssignmentDialog(employments: _employments, profiles: _profiles),
    );
    if (result == null) return;
    await _save(() => _service.assignEmployee(result), 'Employee leave profile assigned.');
  }

  Future<void> _assignPosition() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PositionAssignmentDialog(profiles: _profiles),
    );
    if (result == null) return;
    await _save(() => _service.assignPosition(result), 'Position leave profile assigned.');
  }

  Future<void> _requestAdjustment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BalanceAdjustmentDialog(employments: _employments, leaveTypes: _types.where((item) => item['active'] == true).toList()),
    );
    if (result == null) return;
    await _save(() => _service.requestAdjustment(result), 'Leave balance adjustment submitted for approval.');
  }

  Future<void> _showLedger(String employmentId) async {
    if (employmentId.isEmpty) return;
    try {
      final ledger = await _service.ledger(employmentId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Leave Balance Ledger'),
          content: SizedBox(
            width: 760,
            child: ledger.isEmpty
                ? const Center(child: Text('No ledger entries found.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: ledger.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = ledger[index];
                      return ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text('${_label(item['transactionType'])} • ${item['amount'] ?? 0}'),
                        subtitle: Text('${item['transactionDate'] ?? '-'} • ${item['description'] ?? ''}'),
                        trailing: Text('${item['balanceAfter'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (error) {
      _message(friendlyErrorMessage(error));
    }
  }

  Future<void> _save(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      _message(success);
      await _load();
    } catch (error) {
      if (mounted) _message(friendlyErrorMessage(error));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static String _label(dynamic value) {
    final text = (value ?? '').toString().replaceAll(RegExp(r'[-_]+'), ' ').trim();
    return text.isEmpty ? 'Not specified' : text.split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}').join(' ');
  }
}

class _LeaveTypeDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LeaveTypeDialog({this.existing});

  @override
  State<_LeaveTypeDialog> createState() => _LeaveTypeDialogState();
}

class _LeaveTypeDialogState extends State<_LeaveTypeDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _documentAfter;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _displayOrder;
  late final TextEditingController _colour;
  late final TextEditingController _icon;
  String _unit = 'DAYS';
  bool _paid = true;
  bool _halfDay = true;
  bool _document = false;
  bool _negative = false;
  bool _weekends = false;
  bool _holidays = false;
  bool _approval = true;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    _code = TextEditingController(text: value['code']?.toString() ?? '');
    _name = TextEditingController(text: value['name']?.toString() ?? '');
    _description = TextEditingController(text: value['description']?.toString() ?? '');
    _documentAfter = TextEditingController(text: value['documentRequiredAfter']?.toString() ?? '');
    _minimum = TextEditingController(text: value['minimumRequest']?.toString() ?? '0.5');
    _maximum = TextEditingController(text: value['maximumConsecutive']?.toString() ?? '');
    _displayOrder = TextEditingController(text: value['displayOrder']?.toString() ?? '0');
    _colour = TextEditingController(text: value['colour']?.toString() ?? '');
    _icon = TextEditingController(text: value['icon']?.toString() ?? '');
    _unit = value['unit']?.toString() ?? 'DAYS';
    _paid = value['paid'] ?? true;
    _halfDay = value['allowHalfDay'] ?? true;
    _document = value['requiresSupportingDocument'] ?? false;
    _negative = value['allowNegativeBalance'] ?? false;
    _weekends = value['includeWeekends'] ?? false;
    _holidays = value['includePublicHolidays'] ?? false;
    _approval = value['requiresApproval'] ?? true;
    _active = value['active'] ?? true;
  }

  @override
  void dispose() {
    for (final controller in [_code, _name, _description, _documentAfter, _minimum, _maximum, _displayOrder, _colour, _icon]) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.existing == null ? 'Add Leave Type' : 'Edit Leave Type'),
        content: SizedBox(
          width: 760,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(children: [
                Row(children: [Expanded(child: _text(_code, 'Code', required: true)), const SizedBox(width: 12), Expanded(child: _text(_name, 'Name', required: true))]),
                const SizedBox(height: 12),
                _text(_description, 'Description', lines: 2),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: _unit, decoration: const InputDecoration(labelText: 'Unit'), items: const [DropdownMenuItem(value: 'DAYS', child: Text('Days')), DropdownMenuItem(value: 'HOURS', child: Text('Hours'))], onChanged: (value) => setState(() => _unit = value ?? 'DAYS')),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: _number(_minimum, 'Minimum request')), const SizedBox(width: 12), Expanded(child: _number(_maximum, 'Maximum consecutive')), const SizedBox(width: 12), Expanded(child: _number(_documentAfter, 'Document after'))]),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: _number(_displayOrder, 'Display order')), const SizedBox(width: 12), Expanded(child: _text(_colour, 'Colour')), const SizedBox(width: 12), Expanded(child: _text(_icon, 'Icon'))]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 0, children: [
                  _switch('Paid', _paid, (v) => _paid = v),
                  _switch('Allow half day', _halfDay, (v) => _halfDay = v),
                  _switch('Supporting document', _document, (v) => _document = v),
                  _switch('Allow negative balance', _negative, (v) => _negative = v),
                  _switch('Include weekends', _weekends, (v) => _weekends = v),
                  _switch('Include public holidays', _holidays, (v) => _holidays = v),
                  _switch('Requires approval', _approval, (v) => _approval = v),
                  _switch('Active', _active, (v) => _active = v),
                ]),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
        ],
      );

  void _save() {
    if (!(_key.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      if (widget.existing?['id'] != null) 'id': widget.existing!['id'],
      if (widget.existing?['version'] != null) 'version': widget.existing!['version'],
      'code': _code.text.trim().toUpperCase().replaceAll(' ', '-'),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'unit': _unit,
      'paid': _paid,
      'allowHalfDay': _halfDay,
      'requiresSupportingDocument': _document,
      if (_documentAfter.text.trim().isNotEmpty) 'documentRequiredAfter': double.tryParse(_documentAfter.text.trim()),
      'minimumRequest': double.tryParse(_minimum.text.trim()) ?? 0.5,
      if (_maximum.text.trim().isNotEmpty) 'maximumConsecutive': double.tryParse(_maximum.text.trim()),
      'allowNegativeBalance': _negative,
      'includeWeekends': _weekends,
      'includePublicHolidays': _holidays,
      'requiresApproval': _approval,
      'displayOrder': int.tryParse(_displayOrder.text.trim()) ?? 0,
      'colour': _colour.text.trim(),
      'icon': _icon.text.trim(),
      'active': _active,
      'activeFrom': widget.existing?['activeFrom'] ?? _today(),
      'activeTo': widget.existing?['activeTo'] ?? '9999-12-31',
    });
  }

  Widget _text(TextEditingController controller, String label, {bool required = false, int lines = 1}) => TextFormField(controller: controller, maxLines: lines, decoration: InputDecoration(labelText: label), validator: required ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null : null);
  Widget _number(TextEditingController controller, String label) => TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label));
  Widget _switch(String label, bool value, ValueChanged<bool> changed) => SizedBox(width: 235, child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: value, onChanged: (newValue) => setState(() => changed(newValue)), title: Text(label)));
  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
}

class _CalendarDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _CalendarDialog({this.existing});
  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _hours;
  late Map<String, bool> _days;
  late List<Map<String, dynamic>> _holidays;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    _code = TextEditingController(text: value['code']?.toString() ?? '');
    _name = TextEditingController(text: value['name']?.toString() ?? '');
    _description = TextEditingController(text: value['description']?.toString() ?? '');
    _hours = TextEditingController(text: value['hoursPerDay']?.toString() ?? '8');
    _days = {
      'mondayWorking': value['mondayWorking'] ?? true,
      'tuesdayWorking': value['tuesdayWorking'] ?? true,
      'wednesdayWorking': value['wednesdayWorking'] ?? true,
      'thursdayWorking': value['thursdayWorking'] ?? true,
      'fridayWorking': value['fridayWorking'] ?? true,
      'saturdayWorking': value['saturdayWorking'] ?? false,
      'sundayWorking': value['sundayWorking'] ?? false,
    };
    _holidays = value['holidays'] is List ? (value['holidays'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : [];
    _active = value['active'] ?? true;
  }

  @override
  void dispose() {
    _code.dispose(); _name.dispose(); _description.dispose(); _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.existing == null ? 'Add Working Calendar' : 'Edit Working Calendar'),
        content: SizedBox(
          width: 820,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: _requiredField(_code, 'Code')), const SizedBox(width: 12), Expanded(child: _requiredField(_name, 'Name'))]),
                const SizedBox(height: 12),
                TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextFormField(controller: _hours, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Hours per working day'), validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Enter valid hours' : null),
                const SizedBox(height: 14),
                const Text('Working days', style: TextStyle(fontWeight: FontWeight.w800)),
                Wrap(spacing: 8, children: _days.entries.map((entry) => FilterChip(label: Text(_dayLabel(entry.key)), selected: entry.value, onSelected: (selected) => setState(() => _days[entry.key] = selected))).toList()),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Holidays', style: TextStyle(fontWeight: FontWeight.w800)), OutlinedButton.icon(onPressed: _addHoliday, icon: const Icon(Icons.add_rounded), label: const Text('Add Holiday'))]),
                if (_holidays.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('No holidays configured.')),
                ..._holidays.asMap().entries.map((entry) => Card(
                  child: ListTile(
                    title: Text(entry.value['name']?.toString() ?? 'Holiday'),
                    subtitle: Text('${entry.value['holidayDate'] ?? '-'}${entry.value['recurringAnnual'] == true ? ' • Repeats annually' : ''}'),
                    trailing: IconButton(onPressed: () => setState(() => _holidays.removeAt(entry.key)), icon: const Icon(Icons.delete_outline_rounded)),
                  ),
                )),
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('Active')),
              ]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save'))],
      );

  Future<void> _addHoliday() async {
    final name = TextEditingController();
    DateTime date = DateTime.now();
    bool recurring = false;
    final holiday = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Holiday'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Holiday name')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () async { final selected = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (selected != null) setDialogState(() => date = selected); }, icon: const Icon(Icons.event), label: Text(DateFormat('yyyy-MM-dd').format(date))),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: recurring, onChanged: (value) => setDialogState(() => recurring = value), title: const Text('Recurring annually')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'holidayDate': DateFormat('yyyy-MM-dd').format(date), 'name': name.text.trim(), 'recurringAnnual': recurring, 'active': true}), child: const Text('Add'))],
      )),
    );
    name.dispose();
    if (holiday != null && (holiday['name'] ?? '').toString().isNotEmpty) setState(() => _holidays.add(holiday));
  }

  void _save() {
    if (!(_key.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      if (widget.existing?['id'] != null) 'id': widget.existing!['id'],
      if (widget.existing?['version'] != null) 'version': widget.existing!['version'],
      'code': _code.text.trim().toUpperCase().replaceAll(' ', '-'),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      ..._days,
      'hoursPerDay': double.tryParse(_hours.text.trim()) ?? 8,
      'active': _active,
      'holidays': _holidays,
    });
  }

  Widget _requiredField(TextEditingController controller, String label) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null);
  String _dayLabel(String value) => value.replaceAll('Working', '').replaceFirstMapped(RegExp(r'^.'), (match) => match.group(0)!.toUpperCase());
}

class _ProfileDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> calendars;
  const _ProfileDialog({this.existing, required this.leaveTypes, required this.calendars});
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _calendarId;
  bool _defaultProfile = false;
  bool _active = true;
  final Map<String, _RuleEditor> _rules = {};

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    _code = TextEditingController(text: value['code']?.toString() ?? '');
    _name = TextEditingController(text: value['name']?.toString() ?? '');
    _description = TextEditingController(text: value['description']?.toString() ?? '');
    _calendarId = value['workingCalendarId']?.toString() ?? (widget.calendars.isNotEmpty ? widget.calendars.first['id']?.toString() : null);
    _defaultProfile = value['defaultProfile'] ?? false;
    _active = value['active'] ?? true;
    final existingRules = value['rules'] is List ? value['rules'] as List : const [];
    for (final type in widget.leaveTypes) {
      Map<String, dynamic>? existingRule;
      for (final candidate in existingRules.whereType<Map>()) {
        if ((candidate['leaveTypeId'] ?? '').toString() == (type['id'] ?? '').toString()) { existingRule = Map<String, dynamic>.from(candidate); break; }
      }
      _rules[type['id'].toString()] = _RuleEditor(type: type, existing: existingRule);
    }
  }

  @override
  void dispose() {
    _code.dispose(); _name.dispose(); _description.dispose();
    for (final rule in _rules.values) { rule.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.existing == null ? 'Add Leave Profile' : 'Edit Leave Profile'),
        content: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(context).height * .76,
          child: Form(
            key: _key,
            child: ListView(children: [
              Row(children: [Expanded(child: _required(_code, 'Code')), const SizedBox(width: 12), Expanded(child: _required(_name, 'Name'))]),
              const SizedBox(height: 12),
              TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _calendarId,
                decoration: const InputDecoration(labelText: 'Working calendar'),
                items: widget.calendars.map((calendar) => DropdownMenuItem(value: calendar['id'].toString(), child: Text(calendar['name']?.toString() ?? '-'))).toList(),
                onChanged: (value) => setState(() => _calendarId = value),
                validator: (value) => value == null ? 'Working calendar is required' : null,
              ),
              Row(children: [Expanded(child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _defaultProfile, onChanged: (value) => setState(() => _defaultProfile = value), title: const Text('Tenant default profile'))), Expanded(child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('Active')))]),
              const Divider(),
              const Text('Profile rules', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Enable the leave types that apply to this profile and configure their entitlement rules.'),
              const SizedBox(height: 12),
              ..._rules.values.map((rule) => _ruleCard(rule)),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save Profile'))],
      );

  Widget _ruleCard(_RuleEditor rule) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: rule.enabled,
              onChanged: (value) => setState(() => rule.enabled = value),
              title: Text('${rule.type['name']} (${rule.type['code']})', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${rule.type['unit'] ?? 'DAYS'} entitlement'),
            ),
            if (rule.enabled) ...[
              const Divider(),
              Row(children: [Expanded(child: _number(rule.entitlement, 'Entitlement')), const SizedBox(width: 10), Expanded(child: _number(rule.cycleMonths, 'Cycle months')), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(value: rule.accrualMethod, decoration: const InputDecoration(labelText: 'Accrual method'), items: const [DropdownMenuItem(value: 'UPFRONT', child: Text('Upfront')), DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')), DropdownMenuItem(value: 'NONE', child: Text('None'))], onChanged: (value) => setState(() => rule.accrualMethod = value ?? 'UPFRONT')))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: _number(rule.accrualAmount, 'Accrual amount')), const SizedBox(width: 10), Expanded(child: _number(rule.maximumNegative, 'Maximum negative balance')), const SizedBox(width: 10), Expanded(child: _number(rule.waitingDays, 'Waiting period days'))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: _number(rule.maximumCarry, 'Maximum carry-over')), const SizedBox(width: 10), Expanded(child: _number(rule.carryExpiry, 'Carry-over expiry months')), const Spacer()]),
              Wrap(spacing: 8, children: [
                _smallSwitch('Pro-rata', rule.proRata, (value) => rule.proRata = value),
                _smallSwitch('Carry-over', rule.carryOver, (value) => rule.carryOver = value),
                _smallSwitch('Document required', rule.documentOverride ?? false, (value) => rule.documentOverride = value),
              ]),
            ],
          ]),
        ),
      );

  void _save() {
    if (!(_key.currentState?.validate() ?? false)) return;
    final rules = _rules.values.where((rule) => rule.enabled).map((rule) => rule.toJson()).toList();
    if (rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure at least one leave type rule.')));
      return;
    }
    Navigator.pop(context, {
      if (widget.existing?['id'] != null) 'id': widget.existing!['id'],
      if (widget.existing?['version'] != null) 'version': widget.existing!['version'],
      'code': _code.text.trim().toUpperCase().replaceAll(' ', '-'),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'workingCalendarId': _calendarId,
      'defaultProfile': _defaultProfile,
      'activeFrom': widget.existing?['activeFrom'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'activeTo': widget.existing?['activeTo'] ?? '9999-12-31',
      'active': _active,
      'rules': rules,
    });
  }

  Widget _required(TextEditingController controller, String label) => TextFormField(controller: controller, decoration: InputDecoration(labelText: label), validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null);
  Widget _number(TextEditingController controller, String label) => TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label));
  Widget _smallSwitch(String label, bool value, ValueChanged<bool> changed) => SizedBox(width: 190, child: SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: value, onChanged: (newValue) => setState(() => changed(newValue)), title: Text(label)));
}

class _RuleEditor {
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  bool enabled;
  late final TextEditingController entitlement;
  late final TextEditingController cycleMonths;
  late final TextEditingController accrualAmount;
  late final TextEditingController maximumNegative;
  late final TextEditingController waitingDays;
  late final TextEditingController maximumCarry;
  late final TextEditingController carryExpiry;
  String accrualMethod;
  bool proRata;
  bool carryOver;
  bool? documentOverride;

  _RuleEditor({required this.type, this.existing})
      : enabled = existing != null && existing['active'] != false,
        accrualMethod = existing?['accrualMethod']?.toString() ?? 'UPFRONT',
        proRata = existing?['proRata'] ?? true,
        carryOver = existing?['carryOverAllowed'] ?? false,
        documentOverride = existing?['supportingDocumentRequiredOverride'] {
    entitlement = TextEditingController(text: existing?['entitlementAmount']?.toString() ?? '0');
    cycleMonths = TextEditingController(text: existing?['cycleMonths']?.toString() ?? '12');
    accrualAmount = TextEditingController(text: existing?['accrualAmount']?.toString() ?? '');
    maximumNegative = TextEditingController(text: existing?['maximumNegativeBalance']?.toString() ?? '0');
    waitingDays = TextEditingController(text: existing?['waitingPeriodDays']?.toString() ?? '0');
    maximumCarry = TextEditingController(text: existing?['maximumCarryOver']?.toString() ?? '');
    carryExpiry = TextEditingController(text: existing?['carryOverExpiryMonths']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
        if (existing?['id'] != null) 'id': existing!['id'],
        if (existing?['version'] != null) 'version': existing!['version'],
        'leaveTypeId': type['id'],
        'entitlementAmount': double.tryParse(entitlement.text.trim()) ?? 0,
        'cycleMonths': int.tryParse(cycleMonths.text.trim()) ?? 12,
        'accrualMethod': accrualMethod,
        'accrualFrequency': 'MONTHLY',
        if (accrualAmount.text.trim().isNotEmpty) 'accrualAmount': double.tryParse(accrualAmount.text.trim()),
        'proRata': proRata,
        'carryOverAllowed': carryOver,
        if (maximumCarry.text.trim().isNotEmpty) 'maximumCarryOver': double.tryParse(maximumCarry.text.trim()),
        if (carryExpiry.text.trim().isNotEmpty) 'carryOverExpiryMonths': int.tryParse(carryExpiry.text.trim()),
        'maximumNegativeBalance': double.tryParse(maximumNegative.text.trim()) ?? 0,
        'waitingPeriodDays': int.tryParse(waitingDays.text.trim()) ?? 0,
        'supportingDocumentRequiredOverride': documentOverride,
        'activeFrom': existing?['activeFrom'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'activeTo': existing?['activeTo'] ?? '9999-12-31',
        'active': true,
      };

  void dispose() {
    entitlement.dispose(); cycleMonths.dispose(); accrualAmount.dispose(); maximumNegative.dispose(); waitingDays.dispose(); maximumCarry.dispose(); carryExpiry.dispose();
  }
}

class _EmployeeAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> employments;
  final List<Map<String, dynamic>> profiles;
  const _EmployeeAssignmentDialog({required this.employments, required this.profiles});
  @override
  State<_EmployeeAssignmentDialog> createState() => _EmployeeAssignmentDialogState();
}

class _EmployeeAssignmentDialogState extends State<_EmployeeAssignmentDialog> {
  final _reason = TextEditingController();
  String? _employmentId;
  String? _profileId;
  DateTime _from = DateTime.now();

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign Employee Leave Profile'),
        content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: _employmentId, decoration: const InputDecoration(labelText: 'Employee'), items: widget.employments.map((employment) => DropdownMenuItem(value: employment['id'].toString(), child: Text('${_employeeName(employment)} • ${employment['employeeNumber'] ?? '-'}'))).toList(), onChanged: (value) => setState(() => _employmentId = value)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _profileId, decoration: const InputDecoration(labelText: 'Leave profile'), items: widget.profiles.where((profile) => profile['active'] == true).map((profile) => DropdownMenuItem(value: profile['id'].toString(), child: Text(profile['name']?.toString() ?? '-'))).toList(), onChanged: (value) => setState(() => _profileId = value)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _from); if (date != null) setState(() => _from = date); }, icon: const Icon(Icons.event), label: Text('Effective ${DateFormat('yyyy-MM-dd').format(_from)}')),
          const SizedBox(height: 12),
          TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Override reason')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _employmentId == null || _profileId == null ? null : () => Navigator.pop(context, {'employmentId': _employmentId, 'leaveProfileId': _profileId, 'effectiveFrom': DateFormat('yyyy-MM-dd').format(_from), 'effectiveTo': '9999-12-31', 'overrideReason': _reason.text.trim()}), child: const Text('Assign'))],
      );

  String _employeeName(Map<String, dynamic> employment) {
    final employee = employment['employee'] is Map ? Map<String, dynamic>.from(employment['employee'] as Map) : <String, dynamic>{};
    final names = [employee['name2'], employee['name3'], employee['name1']].map((v) => (v ?? '').toString().trim()).where((v) => v.isNotEmpty).toList();
    return names.isEmpty ? 'Unknown employee' : names.join(' ');
  }
}

class _PositionAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  const _PositionAssignmentDialog({required this.profiles});
  @override
  State<_PositionAssignmentDialog> createState() => _PositionAssignmentDialogState();
}

class _PositionAssignmentDialogState extends State<_PositionAssignmentDialog> {
  String? _position;
  String? _profileId;
  DateTime _from = DateTime.now();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign Position Leave Profile'),
        content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppDropdownField(field: 'EMPLOYMENT-POSITION', label: 'Position', value: _position, onChanged: (value) => setState(() => _position = value)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _profileId, decoration: const InputDecoration(labelText: 'Leave profile'), items: widget.profiles.where((profile) => profile['active'] == true).map((profile) => DropdownMenuItem(value: profile['id'].toString(), child: Text(profile['name']?.toString() ?? '-'))).toList(), onChanged: (value) => setState(() => _profileId = value)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _from); if (date != null) setState(() => _from = date); }, icon: const Icon(Icons.event), label: Text('Effective ${DateFormat('yyyy-MM-dd').format(_from)}')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _position == null || _profileId == null ? null : () => Navigator.pop(context, {'positionCode': _position, 'leaveProfileId': _profileId, 'effectiveFrom': DateFormat('yyyy-MM-dd').format(_from), 'effectiveTo': '9999-12-31'}), child: const Text('Assign'))],
      );
}

class _BalanceAdjustmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> employments;
  final List<Map<String, dynamic>> leaveTypes;
  const _BalanceAdjustmentDialog({required this.employments, required this.leaveTypes});
  @override
  State<_BalanceAdjustmentDialog> createState() => _BalanceAdjustmentDialogState();
}

class _BalanceAdjustmentDialogState extends State<_BalanceAdjustmentDialog> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _employmentId;
  String? _leaveTypeId;
  DateTime _date = DateTime.now();
  int _attachmentCount = 0;
  late final String _attachmentId;

  @override
  void initState() { super.initState(); _attachmentId = 'LEAVE-ADJUSTMENT-DOC-${DateTime.now().microsecondsSinceEpoch}'; }
  @override
  void dispose() { _amount.dispose(); _reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Leave Balance Adjustment'),
        content: SizedBox(width: 720, child: Form(key: _key, child: SingleChildScrollView(child: Column(children: [
          DropdownButtonFormField<String>(value: _employmentId, decoration: const InputDecoration(labelText: 'Employee'), items: widget.employments.map((employment) => DropdownMenuItem(value: employment['id'].toString(), child: Text('${_employeeName(employment)} • ${employment['employeeNumber'] ?? '-'}'))).toList(), onChanged: (value) => setState(() => _employmentId = value), validator: (value) => value == null ? 'Employee is required' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _leaveTypeId, decoration: const InputDecoration(labelText: 'Leave type'), items: widget.leaveTypes.map((type) => DropdownMenuItem(value: type['id'].toString(), child: Text(type['name']?.toString() ?? '-'))).toList(), onChanged: (value) => setState(() => _leaveTypeId = value), validator: (value) => value == null ? 'Leave type is required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Adjustment amount', helperText: 'Use a negative value to reduce the balance.'), validator: (value) => (double.tryParse(value ?? '') ?? 0) == 0 ? 'Enter a non-zero amount' : null),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _date); if (date != null) setState(() => _date = date); }, icon: const Icon(Icons.event), label: Text('Effective ${DateFormat('yyyy-MM-dd').format(_date)}')),
          const SizedBox(height: 12),
          TextFormField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason'), validator: (value) => value == null || value.trim().isEmpty ? 'Reason is required' : null),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('Supporting documents (required)', style: TextStyle(fontWeight: FontWeight.w800))),
          AttachmentSection(objectId: _attachmentId, onAttachmentCountChanged: (count) => _attachmentCount = count),
        ])))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.approval_outlined), label: const Text('Submit for Approval'))],
      );

  void _submit() {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_attachmentCount == 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload at least one supporting document.'))); return; }
    Navigator.pop(context, {'employmentId': _employmentId, 'leaveTypeId': _leaveTypeId, 'adjustmentAmount': double.parse(_amount.text.trim()), 'effectiveDate': DateFormat('yyyy-MM-dd').format(_date), 'reason': _reason.text.trim(), 'attachmentObjectIds': [_attachmentId]});
  }

  String _employeeName(Map<String, dynamic> employment) {
    final employee = employment['employee'] is Map ? Map<String, dynamic>.from(employment['employee'] as Map) : <String, dynamic>{};
    final names = [employee['name2'], employee['name3'], employee['name1']].map((v) => (v ?? '').toString().trim()).where((v) => v.isNotEmpty).toList();
    return names.isEmpty ? 'Unknown employee' : names.join(' ');
  }
}
