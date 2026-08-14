import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../employment/services/employment_service.dart';
import '../services/leave_configuration_service.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class LeaveBalanceManagementScreen extends StatefulWidget {
  final int initialTab;

  const LeaveBalanceManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<LeaveBalanceManagementScreen> createState() =>
      _LeaveBalanceManagementScreenState();
}

class _LeaveBalanceManagementScreenState
    extends State<LeaveBalanceManagementScreen>
    with SingleTickerProviderStateMixin {
  final LeaveConfigurationService _service = LeaveConfigurationService();
  final EmploymentService _employmentService = EmploymentService();

  late final TabController _tabs;
  List<Map<String, dynamic>> _balances = const [];
  List<Map<String, dynamic>> _adjustments = const [];
  List<Map<String, dynamic>> _employments = const [];
  List<Map<String, dynamic>> _leaveTypes = const [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _service.balances(),
        _service.adjustments(),
        _employmentService.list(),
        _service.leaveTypes(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _balances = values[0];
        _adjustments = values[1];
        _employments = values[2];
        _leaveTypes = values[3];
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
        title: const Text('Leave Balances'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined),
              text: 'Employee Balances',
            ),
            Tab(
              icon: Icon(Icons.tune_rounded),
              text: 'Adjustment Requests',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestAdjustment,
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Request Adjustment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1450),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: _hero(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search leave balances and adjustments',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _balanceList(),
                              _adjustmentList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _hero() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 27,
              child: Icon(Icons.account_balance_wallet_outlined),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee leave balances',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Review current balances and immutable ledger entries, or submit documented corrections for approval. Leave rules and profiles are maintained under System Configuration.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceList() {
    final query = _searchQuery.trim().toLowerCase();
    final balances = query.isEmpty
        ? _balances
        : _balances.where((item) => item.entries
            .map((entry) => '${entry.key} ${entry.value}')
            .join(' ')
            .toLowerCase()
            .contains(query)).toList();
    if (balances.isEmpty) {
      return const Center(child: Text('No leave balances found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: balances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final balance = balances[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(17),
            leading: const CircleAvatar(
              child: Icon(Icons.account_balance_wallet_outlined),
            ),
            title: Text(
              '${balance['employeeName'] ?? '-'} • ${balance['leaveTypeName'] ?? balance['leaveTypeCode']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${balance['employeeNumber'] ?? '-'} • Cycle ${balance['cycleStart'] ?? '-'} to ${balance['cycleEnd'] ?? '-'}\n'
              'Accrued ${balance['accrued'] ?? 0} • Taken ${balance['taken'] ?? 0} • Adjusted ${balance['adjusted'] ?? 0}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Available'),
                Text(
                  '${balance['availableBalance'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            onTap: () =>
                _showLedger(balance['employmentId']?.toString() ?? ''),
          ),
        );
      },
    );
  }

  Widget _adjustmentList() {
    final query = _searchQuery.trim().toLowerCase();
    final adjustments = query.isEmpty
        ? _adjustments
        : _adjustments.where((item) => item.entries
            .map((entry) => '${entry.key} ${entry.value}')
            .join(' ')
            .toLowerCase()
            .contains(query)).toList();
    if (adjustments.isEmpty) {
      return const Center(
        child: Text('No leave balance adjustment requests found.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: adjustments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = adjustments[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(17),
            leading: const CircleAvatar(child: Icon(Icons.tune_rounded)),
            title: Text(
              '${item['requestNumber'] ?? '-'} • ${item['employeeName'] ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${item['leaveTypeName'] ?? '-'}: ${item['adjustmentAmount'] ?? 0} effective ${AppDateUtils.displayDate(item['effectiveDate'])}\n${item['reason'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: Chip(label: Text(_label(item['status']))),
          ),
        );
      },
    );
  }

  Future<void> _requestAdjustment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BalanceAdjustmentDialog(
        employments: _employments,
        leaveTypes: _leaveTypes,
      ),
    );
    if (result == null) return;
    try {
      await _service.requestAdjustment(result);
      if (!mounted) return;
      _message('Leave balance adjustment submitted for approval.');
      _tabs.animateTo(1);
      await _load();
    } catch (error) {
      if (mounted) _message(friendlyErrorMessage(error));
    }
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
                        title: Text(
                          '${_label(item['transactionType'])} • ${item['amount'] ?? 0}',
                        ),
                        subtitle: Text(
                          '${item['transactionDate'] ?? '-'} • ${item['description'] ?? ''}',
                        ),
                        trailing: Text(
                          '${item['balanceAfter'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message(friendlyErrorMessage(error));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _label(dynamic value) {
    final text = (value ?? '')
        .toString()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .trim();
    if (text.isEmpty) return 'Not specified';
    return text
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _BalanceAdjustmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> employments;
  final List<Map<String, dynamic>> leaveTypes;

  const _BalanceAdjustmentDialog({
    required this.employments,
    required this.leaveTypes,
  });

  @override
  State<_BalanceAdjustmentDialog> createState() =>
      _BalanceAdjustmentDialogState();
}

class _BalanceAdjustmentDialogState
    extends State<_BalanceAdjustmentDialog> {
  final GlobalKey<FormState> _key = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();

  String? _employmentId;
  String? _leaveTypeId;
  DateTime _date = DateTime.now();
  int _attachmentCount = 0;
  late final String _attachmentId;

  @override
  void initState() {
    super.initState();
    _attachmentId =
        'LEAVE-ADJUSTMENT-DOC-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Request Leave Balance Adjustment'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SearchableDropdownFormField<String>(
                  value: _employmentId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: widget.employments
                      .map(
                        (employment) => DropdownMenuItem(
                          value: employment['id'].toString(),
                          child: Text(
                            '${_employeeName(employment)} • ${employment['employeeNumber'] ?? '-'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _employmentId = value),
                  validator: (value) =>
                      value == null ? 'Employee is required' : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownFormField<String>(
                  value: _leaveTypeId,
                  decoration: const InputDecoration(labelText: 'Leave type'),
                  items: widget.leaveTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type['id'].toString(),
                          child: Text(type['name']?.toString() ?? '-'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _leaveTypeId = value),
                  validator: (value) =>
                      value == null ? 'Leave type is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Adjustment amount',
                    helperText: 'Use a negative value to reduce the balance.',
                  ),
                  validator: (value) =>
                      (double.tryParse(value ?? '') ?? 0) == 0
                          ? 'Enter a non-zero amount'
                          : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: _date,
                    );
                    if (date != null) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Effective ${DateFormat('yyyy-MM-dd').format(_date)}',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Reason is required'
                      : null,
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Supporting documents (required)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                AttachmentSection(
                  objectId: _attachmentId,
                  onAttachmentCountChanged: (count) =>
                      _attachmentCount = count,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.approval_outlined),
          label: const Text('Submit for Approval'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_attachmentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload at least one supporting document.'),
        ),
      );
      return;
    }
    Navigator.pop(context, {
      'employmentId': _employmentId,
      'leaveTypeId': _leaveTypeId,
      'adjustmentAmount': double.parse(_amount.text.trim()),
      'effectiveDate': DateFormat('yyyy-MM-dd').format(_date),
      'reason': _reason.text.trim(),
      'attachmentObjectIds': [_attachmentId],
    });
  }

  String _employeeName(Map<String, dynamic> employment) {
    final employee = employment['employee'] is Map
        ? Map<String, dynamic>.from(employment['employee'] as Map)
        : <String, dynamic>{};
    final names = [employee['name2'], employee['name3'], employee['name1']]
        .map((value) => (value ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return names.isEmpty ? 'Unknown employee' : names.join(' ');
  }
}
