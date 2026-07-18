import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/report_dashboard.dart';
import '../services/reporting_api_client.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});
  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final _number = NumberFormat.decimalPattern();
  final _dateTime = DateFormat('dd MMM yyyy HH:mm');
  ReportDashboard? _dashboard;
  Object? _error;
  bool _loading = true;
  int _periods = 6;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await ReportingApiClient().dashboard(periods: _periods, months: _periods);
      if (mounted) setState(() => _dashboard = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(tooltip: 'Refresh reports', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _dashboard == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _dashboard == null) {
      return _ErrorState(message: '$_error', onRetry: _load);
    }
    final data = _dashboard!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _toolbar(data),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MaterialBanner(content: Text('Refresh failed: $_error'), actions: [TextButton(onPressed: _load, child: const Text('Retry'))]),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Membership overview', 'Current membership population and status'),
          const SizedBox(height: 12),
          _summaryGrid(data.membershipSummary),
          const SizedBox(height: 28),
          _sectionTitle('Memberships per plan', 'All plans, including inactive plans and plans with no memberships'),
          const SizedBox(height: 12),
          _planTable(data.membershipsByPlan),
          const SizedBox(height: 28),
          _sectionTitle('Premium performance', 'Paid, unpaid and partially paid premiums for the selected periods'),
          const SizedBox(height: 12),
          _premiumBars(data.premiumsByPeriod),
          const SizedBox(height: 12),
          _premiumTable(data.premiumsByPeriod, data.currency),
          const SizedBox(height: 28),
          _sectionTitle('Claims by month and type', 'Claim date is used for monthly grouping'),
          const SizedBox(height: 12),
          _claimTable(data.claimsByMonth),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _toolbar(ReportDashboard data) {
    return LayoutBuilder(builder: (context, constraints) {
      final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Generated ${_dateTime.format(data.generatedAt.toLocal())}', style: Theme.of(context).textTheme.bodySmall),
        Text('Tenant: ${data.tenantId}', style: Theme.of(context).textTheme.bodySmall),
      ]);
      final selector = SizedBox(width: 190, child: DropdownButtonFormField<int>(
        initialValue: _periods,
        decoration: const InputDecoration(labelText: 'Reporting periods', border: OutlineInputBorder()),
        items: const [6, 12, 18, 24].map((value) => DropdownMenuItem(value: value, child: Text('Last $value periods'))).toList(),
        onChanged: _loading ? null : (value) { if (value != null && value != _periods) { setState(() => _periods = value); _load(); } },
      ));
      if (constraints.maxWidth < 600) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, const SizedBox(height: 12), selector]);
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [details, selector]);
    });
  }

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
    const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);

  Widget _summaryGrid(MembershipSummary summary) {
    final values = <(String, int, IconData)>[
      ('Total memberships', summary.total, Icons.people_alt_rounded),
      ('Active', summary.active, Icons.check_circle_outline_rounded),
      ('Suspended', summary.suspended, Icons.pause_circle_outline_rounded),
      ('Lapsed', summary.lapsed, Icons.history_toggle_off_rounded),
      ('Cancelled', summary.cancelled, Icons.cancel_outlined),
      ('Deceased', summary.deceased, Icons.person_off_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: values.map((value) => SizedBox(width: width, child: Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(value.$3, size: 30, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value.$1, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4), Text(_number.format(value.$2), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ])),
        ])),
      ))).toList());
    });
  }

  Widget _planTable(List<MembershipPlanCount> rows) => _tableCard(DataTable(
    columns: const [DataColumn(label: Text('Plan')), DataColumn(label: Text('Code')), DataColumn(numeric: true, label: Text('Memberships')),
      DataColumn(numeric: true, label: Text('Active')), DataColumn(label: Text('Plan status'))],
    rows: rows.map((row) => DataRow(cells: [
      DataCell(Text(row.planName)), DataCell(Text(row.planCode)), DataCell(Text(_number.format(row.membershipCount))),
      DataCell(Text(_number.format(row.activeMembershipCount))),
      DataCell(Chip(label: Text(row.activePlan ? 'Active' : 'Inactive'), visualDensity: VisualDensity.compact)),
    ])).toList(),
  ));

  Widget _premiumBars(List<PremiumPeriod> rows) {
    final maxValue = rows.fold<int>(1, (max, row) => row.paidCount + row.outstandingCount > max ? row.paidCount + row.outstandingCount : max);
    return Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(18), child: Column(children: rows.map((row) {
      final paidFraction = row.paidCount / maxValue;
      final outstandingFraction = row.outstandingCount / maxValue;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        SizedBox(width: 76, child: Text(row.label)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(height: 12, child: LayoutBuilder(builder: (context, constraints) => Stack(children: [
            Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            Container(width: constraints.maxWidth * paidFraction, color: Theme.of(context).colorScheme.primary),
          ])))),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(height: 8, child: LayoutBuilder(builder: (context, constraints) => Stack(children: [
            Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            Container(width: constraints.maxWidth * outstandingFraction, color: Theme.of(context).colorScheme.error),
          ])))),
        ])),
        const SizedBox(width: 12), SizedBox(width: 116, child: Text('${_number.format(row.paidCount)} paid\n${_number.format(row.outstandingCount)} outstanding', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall)),
      ]));
    }).toList())));
  }

  Widget _premiumTable(List<PremiumPeriod> rows, String currency) => _tableCard(DataTable(
    columns: const [DataColumn(label: Text('Period')), DataColumn(numeric: true, label: Text('Paid')), DataColumn(numeric: true, label: Text('Unpaid')),
      DataColumn(numeric: true, label: Text('Partial')), DataColumn(numeric: true, label: Text('Outstanding')), DataColumn(numeric: true, label: Text('Excluded')),
      DataColumn(numeric: true, label: Text('Paid amount')), DataColumn(numeric: true, label: Text('Outstanding amount'))],
    rows: rows.map((row) => DataRow(cells: [DataCell(Text(row.label)), DataCell(Text(_number.format(row.paidCount))),
      DataCell(Text(_number.format(row.unpaidCount))), DataCell(Text(_number.format(row.partiallyPaidCount))),
      DataCell(Text(_number.format(row.outstandingCount))), DataCell(Text(_number.format(row.excludedCount))),
      DataCell(Text(_money(row.paidAmountCents, currency))), DataCell(Text(_money(row.outstandingAmountCents, currency))),
    ])).toList(),
  ));

  Widget _claimTable(List<ClaimMonth> rows) {
    final types = rows.expand((row) => row.byType.keys).toSet().toList()..sort();
    return _tableCard(DataTable(
      columns: [const DataColumn(label: Text('Month')), ...types.map((type) => DataColumn(numeric: true, label: Text(_title(type)))), const DataColumn(numeric: true, label: Text('Total'))],
      rows: rows.map((row) => DataRow(cells: [DataCell(Text(row.label)), ...types.map((type) => DataCell(Text(_number.format(row.byType[type] ?? 0)))), DataCell(Text(_number.format(row.totalCount)))] )).toList(),
    ));
  }

  Widget _tableCard(Widget table) => Card(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: table));
  String _money(int cents, String currency) => '$currency ${NumberFormat('#,##0.00').format(cents / 100)}';
  static String _title(String value) => value.toLowerCase().split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.error_outline_rounded, size: 52, color: Theme.of(context).colorScheme.error), const SizedBox(height: 16),
    Text('Reports could not be loaded', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
    Text(message, textAlign: TextAlign.center), const SizedBox(height: 20), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
  ])));
}
