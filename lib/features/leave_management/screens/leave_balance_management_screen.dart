import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../services/leave_configuration_service.dart';

class LeaveBalanceManagementScreen extends StatefulWidget {
  final bool approverView;

  const LeaveBalanceManagementScreen({
    super.key,
    this.approverView = false,
  });

  @override
  State<LeaveBalanceManagementScreen> createState() =>
      _LeaveBalanceManagementScreenState();
}

class _LeaveBalanceManagementScreenState
    extends State<LeaveBalanceManagementScreen> {
  final LeaveConfigurationService _service = LeaveConfigurationService();
  List<Map<String, dynamic>> _balances = const [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  String? get _view => widget.approverView ? 'APPROVER' : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balances = await _service.balances(view: _view);
      if (mounted) setState(() => _balances = balances);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.approverView ? 'Team Leave Balances' : 'My Leave Balances';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
                      FilledButton(onPressed: _load, child: const Text('Retry')),
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
                            decoration: InputDecoration(
                              hintText: widget.approverView
                                  ? 'Search team leave balances'
                                  : 'Search my leave balances',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                          ),
                        ),
                        Expanded(child: _balanceList()),
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
            colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 27,
              child: Icon(Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.approverView
                        ? 'Employees you approve'
                        : 'Your leave balances',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.approverView
                        ? 'Only balances for employees covered by your active leave approval assignments are shown.'
                        : 'Review your current leave entitlements, usage and ledger entries.',
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
        : _balances
            .where(
              (item) => item.entries
                  .map((entry) => '${entry.key} ${entry.value}')
                  .join(' ')
                  .toLowerCase()
                  .contains(query),
            )
            .toList();
    if (balances.isEmpty) {
      return Center(
        child: Text(
          widget.approverView
              ? 'No employee leave balances are assigned to you.'
              : 'No leave balances found.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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

  Future<void> _showLedger(String employmentId) async {
    if (employmentId.isEmpty) return;
    try {
      final ledger = await _service.ledger(employmentId, view: _view);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    }
  }

  String _label(dynamic value) =>
      (value ?? '-').toString().replaceAll('_', ' ').replaceAll('-', ' ');
}
