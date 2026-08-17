import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../leave_requests/models/leave_request.dart';
import '../../leave_requests/screens/leave_request_list_screen.dart';
import '../../leave_requests/services/leave_service.dart';
import 'leave_balance_management_screen.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  final LeaveService _service = LeaveService();
  Map<String, dynamic> _access = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _service.getAccess();
      if (mounted) setState(() => _access = access);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Management')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadAccess, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final isApprover = _access['leaveApprover'] == true;
    final hasEmployment = _access['hasEmployment'] == true;
    final cards = <_LeaveDestination>[
      if (hasEmployment)
        _LeaveDestination(
          'My Leave Requests',
          'Create, submit and track only your own leave requests.',
          Icons.event_note_outlined,
          () => const LeaveRequestListScreen(),
        ),
      if (hasEmployment)
        _LeaveDestination(
          'My Leave Balances',
          'Review your leave entitlements, usage and ledger entries.',
          Icons.account_balance_wallet_outlined,
          () => const LeaveBalanceManagementScreen(),
        ),
      if (isApprover)
        _LeaveDestination(
          'Team Leave Calendar',
          'Review leave for employees covered by your leave approval assignments.',
          Icons.calendar_month_outlined,
          () => const _LeaveCalendarScreen(),
        ),
      if (isApprover)
        _LeaveDestination(
          'Team Leave Balances',
          'Review balances for employees you are configured to approve.',
          Icons.groups_2_outlined,
          () => const LeaveBalanceManagementScreen(approverView: true),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.beach_access_outlined, size: 52),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leave',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isApprover && hasEmployment
                                  ? 'Manage your own leave. Your approver access is limited to employees assigned to you by the active leave approval workflow.'
                                  : isApprover
                                      ? 'Your approver access is limited to employees assigned to you by the active leave approval workflow.'
                                      : 'Capture, view and track your own leave requests and balances.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 3
                      : constraints.maxWidth >= 700
                          ? 2
                          : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: cards
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: _destinationCard(context, item),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destinationCard(BuildContext context, _LeaveDestination item) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item.builder()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Icon(item.icon)),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(item.description),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LeaveDestination {
  final String title;
  final String description;
  final IconData icon;
  final Widget Function() builder;

  const _LeaveDestination(
    this.title,
    this.description,
    this.icon,
    this.builder,
  );
}

class _LeaveCalendarScreen extends StatefulWidget {
  const _LeaveCalendarScreen();

  @override
  State<_LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<_LeaveCalendarScreen> {
  final _service = LeaveService();
  List<LeaveRequest> _requests = const [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

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
      final values = await _service.getLeaveRequests(view: 'APPROVER');
      if (mounted) {
        setState(
          () => _requests = values
              .where(
                (request) => [
                  'APPROVED',
                  'SUBMITTED',
                  'AWAITING-APPROVAL',
                ].contains(request.status),
              )
              .toList(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaveRequest> get _monthRequests {
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1, 0);
    return _requests.where((request) {
      final requestStart = DateTime.tryParse(request.startDate);
      final requestEnd = DateTime.tryParse(request.endDate);
      return requestStart != null &&
          requestEnd != null &&
          !requestEnd.isBefore(start) &&
          !requestStart.isAfter(end);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<LeaveRequest> get _visibleMonthRequests {
    final values = _monthRequests;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return values;
    return values
        .where(
          (request) => [
            request.employeeName,
            request.leaveTypeName,
            request.status,
            request.startDate,
            request.endDate,
            request.unit,
          ].join(' ').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Leave Calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () => _month =
                                DateTime(_month.year, _month.month - 1),
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_month),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _month =
                                DateTime(_month.year, _month.month + 1),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search team leave calendar',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final values = _visibleMonthRequests;
    if (values.isEmpty) {
      return const Center(
        child: Text('No approved or pending team leave in this month.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: values.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final request = values[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              child: Text(
                request.startDate.length >= 10
                    ? request.startDate.substring(8, 10)
                    : '—',
              ),
            ),
            title: Text(
              '${request.employeeName} • ${request.leaveTypeName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${request.startDate} to ${request.endDate} • ${request.amount.toStringAsFixed(2)} ${request.unit.toLowerCase()}',
            ),
            trailing: Chip(
              label: Text(request.status.replaceAll('-', ' ')),
            ),
          ),
        );
      },
    );
  }
}
