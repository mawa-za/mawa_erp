import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/routing/app_routes.dart';
import '../../home/models/workcenter.dart';
import '../models/report_dashboard.dart';
import '../models/financial_report.dart';
import '../services/reporting_api_client.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key, this.reportKey});

  final String? reportKey;

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  static const _reports = <_ReportDefinition>[
    _ReportDefinition(
      key: 'membership-overview',
      workcenterId: 'management-membership-overview-report',
      title: 'Membership Overview',
      description: 'Current membership population and status across the organisation.',
      category: _ReportCategory.management,
      icon: Icons.groups_2_outlined,
    ),
    _ReportDefinition(
      key: 'memberships-by-plan',
      workcenterId: 'management-memberships-by-plan-report',
      title: 'Memberships by Plan',
      description: 'Compare membership volumes and active memberships across configured plans.',
      category: _ReportCategory.management,
      icon: Icons.account_tree_outlined,
    ),
    _ReportDefinition(
      key: 'premium-performance',
      workcenterId: 'operational-premium-performance-report',
      title: 'Premium Performance',
      description: 'Monitor paid, unpaid and partially paid premiums by reporting period.',
      category: _ReportCategory.operational,
      icon: Icons.payments_outlined,
      usesPeriods: true,
    ),
    _ReportDefinition(
      key: 'claims-activity',
      workcenterId: 'operational-claims-activity-report',
      title: 'Claims by Month & Type',
      description: 'Track monthly claim volumes and the mix of claim types being processed.',
      category: _ReportCategory.operational,
      icon: Icons.request_quote_outlined,
      usesPeriods: true,
    ),
    _ReportDefinition(key:'customer-money-received',workcenterId:'operational-customer-money-received-report',title:'Customer Money Received',description:'Posted customer receipts by cashier, method and source.',category:_ReportCategory.operational,icon:Icons.point_of_sale,usesDates:true,usesCashier:true),
    _ReportDefinition(key:'cashier-collections',workcenterId:'operational-cashier-collections-report',title:'Cashier Collections',description:'Collection totals and receipt volumes for each cashier.',category:_ReportCategory.operational,icon:Icons.badge_outlined,usesDates:true,usesCashier:true),
    _ReportDefinition(key:'deposits-summary',workcenterId:'operational-deposits-summary-report',title:'Deposits Summary',description:'Captured bank deposits and their cashup variances.',category:_ReportCategory.operational,icon:Icons.account_balance_outlined,usesDates:true,usesCashier:true),
    _ReportDefinition(key:'undeposited-collections',workcenterId:'operational-undeposited-collections-report',title:'Undeposited Collections',description:'Cash and Card collections still awaiting deposit.',category:_ReportCategory.operational,icon:Icons.pending_actions,usesDates:true,usesCashier:true),
    _ReportDefinition(key:'collections-deposits-reconciliation',workcenterId:'management-collections-deposits-reconciliation-report',title:'Collections & Deposits Reconciliation',description:'Reconcile deposit-required collections, direct EFTs and bank deposits.',category:_ReportCategory.management,icon:Icons.balance,usesDates:true,usesCashier:true),
    _ReportDefinition(key:'supplier-payments-summary',workcenterId:'management-supplier-payments-summary-report',title:'Supplier Payments Summary',description:'Amounts actually paid to suppliers and service providers.',category:_ReportCategory.management,icon:Icons.payments_outlined,usesDates:true),
    _ReportDefinition(key:'payments-by-service',workcenterId:'management-payments-by-service-report',title:'Payments by Service',description:'Paid expenditure grouped by service or expense category.',category:_ReportCategory.management,icon:Icons.category_outlined,usesDates:true),
    _ReportDefinition(key:'supplier-payment-detail',workcenterId:'operational-supplier-payment-detail-report',title:'Supplier Payment Detail',description:'Auditable detail of completed supplier payments.',category:_ReportCategory.operational,icon:Icons.receipt_long_outlined,usesDates:true),
  ];

  final _number = NumberFormat.decimalPattern();
  final _dateTime = DateFormat('dd MMM yyyy HH:mm');
  final Set<String> _allowedWorkcenters = <String>{};

  ReportDashboard? _dashboard;
  FinancialReport? _financial;
  Object? _error;
  bool _accessLoading = true;
  bool _loading = false;
  int _periods = 6;
  DateTime _from=DateTime(DateTime.now().year,DateTime.now().month,1);
  DateTime _to=DateTime.now();
  final _cashierController=TextEditingController();

  _ReportDefinition? get _selectedReport {
    final key = widget.reportKey?.trim();
    if (key == null || key.isEmpty) return null;
    for (final report in _reports) {
      if (report.key == key) return report;
    }
    return null;
  }

  bool get _hasUnknownReport =>
      widget.reportKey?.trim().isNotEmpty == true && _selectedReport == null;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  @override
  void didUpdateWidget(covariant ReportsDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportKey != widget.reportKey) {
      _initialise();
    }
  }

  Future<void> _initialise() async {
    setState(() {
      _accessLoading = true;
      _loading = false;
      _error = null;
      _dashboard = null;
      _financial = null;
      _allowedWorkcenters.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getString('selectedRole')?.trim() ?? '';
      if (roleId.isEmpty) {
        throw Exception('No selected role found. Sign in again.');
      }

      final response = await ApiClient().get('/role/$roleId/workcenter');
      if (response.statusCode != 200) {
        throw Exception('Unable to load report access for the selected role.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Invalid report access response.');
      }

      final workcenters = decoded
          .whereType<Map>()
          .map((item) => Workcenter.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _allowedWorkcenters.addAll(
          workcenters.map((item) => item.id.trim().toLowerCase()),
        );
        _accessLoading = false;
      });

      final selected = _selectedReport;
      if (selected != null && _canAccess(selected)) {
        await _loadReport();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _accessLoading = false;
      });
    }
  }

  bool _canAccess(_ReportDefinition report) =>
      _allowedWorkcenters.contains(report.workcenterId.toLowerCase());

  Future<void> _loadReport() async {
    final selected = _selectedReport;
    if (selected == null || !_canAccess(selected)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if(selected.usesDates) {
        final value=await ReportingApiClient().financial(selected.key,from:_from,to:_to,cashier:selected.usesCashier?_cashierController.text:null);
        if(mounted) setState(()=>_financial=value);
      } else {
        final value = await ReportingApiClient().dashboard(periods: _periods,months: _periods);
        if (mounted) setState(() => _dashboard = value);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedReport;
    return Scaffold(
      appBar: AppBar(
        title: Text(selected?.title ?? 'Reports'),
        actions: [
          IconButton(
            tooltip: selected == null ? 'Refresh access' : 'Refresh report',
            onPressed: (_accessLoading || _loading)
                ? null
                : selected == null
                    ? _initialise
                    : _loadReport,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_accessLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasUnknownReport) {
      return _ErrorState(
        message: 'The requested report is not registered.',
        onRetry: () => context.go(AppRoutes.reports),
        actionLabel: 'Back to reports',
      );
    }

    final selected = _selectedReport;
    if (selected == null) {
      if (_error != null && _allowedWorkcenters.isEmpty) {
        return _ErrorState(message: '$_error', onRetry: _initialise);
      }
      return _reportCatalogue();
    }

    if (!_canAccess(selected)) {
      return _AccessDeniedState(reportTitle: selected.title);
    }

    if (_loading && _dashboard == null && _financial == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _dashboard == null && _financial == null) {
      return _ErrorState(message: '$_error', onRetry: _loadReport);
    }

    final data = _dashboard;
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          selected.usesDates ? _financialToolbar(selected) : _toolbar(data!, selected),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text('Refresh failed: $_error'),
              actions: [
                TextButton(onPressed: _loadReport, child: const Text('Retry')),
              ],
            ),
          ],
          const SizedBox(height: 20),
          selected.usesDates ? _financialContent(selected,_financial!) : _reportContent(selected, data!),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _reportCatalogue() {
    final management = _reports
        .where((report) =>
            report.category == _ReportCategory.management && _canAccess(report))
        .toList();
    final operational = _reports
        .where((report) =>
            report.category == _ReportCategory.operational && _canAccess(report))
        .toList();

    if (management.isEmpty && operational.isEmpty) {
      return const _AccessDeniedState();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Reports & Analytics',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Reports are permission-controlled individually. Only reports assigned to your current role are shown.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (management.isNotEmpty) ...[
          const SizedBox(height: 28),
          _catalogueHeading(
            'Management Reports',
            'Portfolio and performance information for management oversight and decision-making.',
          ),
          const SizedBox(height: 12),
          _reportCardGrid(management),
        ],
        if (operational.isNotEmpty) ...[
          const SizedBox(height: 30),
          _catalogueHeading(
            'Operational Reports',
            'Day-to-day activity and processing information for operational teams.',
          ),
          const SizedBox(height: 12),
          _reportCardGrid(operational),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _catalogueHeading(String title, String description) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );

  Widget _reportCardGrid(List<_ReportDefinition> reports) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 580
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: reports
              .map(
                (report) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(
                        '${AppRoutes.reports}?report=${Uri.encodeQueryComponent(report.key)}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              report.icon,
                              size: 30,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              report.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              report.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Open report  →',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _toolbar(ReportDashboard data, _ReportDefinition report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated ${_dateTime.format(data.generatedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Tenant: ${data.tenantId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
        if (!report.usesPeriods) return details;

        final selector = SizedBox(
          width: 190,
          child: SearchableDropdownFormField<int>(
            initialValue: _periods,
            decoration: const InputDecoration(
              labelText: 'Reporting periods',
              border: OutlineInputBorder(),
            ),
            items: const [6, 12, 18, 24]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('Last $value periods'),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    if (value != null && value != _periods) {
                      setState(() => _periods = value);
                      _loadReport();
                    }
                  },
          ),
        );
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 12), selector],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [details, selector],
        );
      },
    );
  }

  Widget _financialToolbar(_ReportDefinition report) => Wrap(
    spacing:12,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.end,children:[
      OutlinedButton.icon(icon:const Icon(Icons.date_range),label:Text('From ${DateFormat('dd MMM yyyy').format(_from)}'),onPressed:() async {final v=await showDatePicker(context:context,initialDate:_from,firstDate:DateTime(2000),lastDate:DateTime.now());if(v!=null)setState(()=>_from=v);}),
      OutlinedButton.icon(icon:const Icon(Icons.event),label:Text('To ${DateFormat('dd MMM yyyy').format(_to)}'),onPressed:() async {final v=await showDatePicker(context:context,initialDate:_to,firstDate:DateTime(2000),lastDate:DateTime.now());if(v!=null)setState(()=>_to=v);}),
      if(report.usesCashier) SizedBox(width:240,child:TextField(controller:_cashierController,decoration:const InputDecoration(labelText:'Cashier (optional)',border:OutlineInputBorder(),prefixIcon:Icon(Icons.person_search)))),
      FilledButton.icon(onPressed:_loading?null:_loadReport,icon:const Icon(Icons.filter_alt),label:const Text('Apply filters')),
    ]);

  Widget _financialContent(_ReportDefinition report,FinancialReport data) {
    final summary=data.summary.entries.where((e)=>e.value!=0).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _sectionTitle(report.title,report.description),const SizedBox(height:12),
      if(summary.isNotEmpty) Wrap(spacing:12,runSpacing:12,children:summary.map((e)=>SizedBox(width:220,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_title(e.key)),const SizedBox(height:5),Text(e.key.endsWith('_cents')?_money(e.value,data.currency):_number.format(e.value),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))])))).toList()),
      const SizedBox(height:18),
      if(data.rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(28),child:Center(child:Text('No records found for the selected filters.')))) else _dynamicTable(data.rows,data.currency),
    ]);
  }

  Widget _dynamicTable(List<Map<String,dynamic>> rows,String currency) {
    final columns=rows.expand((r)=>r.keys).toSet().toList();
    return _tableCard(DataTable(columns:columns.map((c)=>DataColumn(numeric:c.endsWith('_cents')||c.endsWith('_count'),label:Text(_title(c)))).toList(),rows:rows.map((r)=>DataRow(cells:columns.map((c){final value=r[c];final text=c.endsWith('_cents')?_money((value as num?)?.toInt()??0,currency):c.endsWith('_count')?_number.format(value??0):'${value??''}';return DataCell(Text(text));}).toList())).toList()));
  }

  Widget _reportContent(_ReportDefinition report, ReportDashboard data) {
    switch (report.key) {
      case 'membership-overview':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(report.title, report.description),
            const SizedBox(height: 12),
            _summaryGrid(data.membershipSummary),
          ],
        );
      case 'memberships-by-plan':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              report.title,
              'All plans, including inactive plans and plans with no memberships.',
            ),
            const SizedBox(height: 12),
            _planTable(data.membershipsByPlan),
          ],
        );
      case 'premium-performance':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(report.title, report.description),
            const SizedBox(height: 12),
            _premiumBars(data.premiumsByPeriod),
            const SizedBox(height: 12),
            _premiumTable(data.premiumsByPeriod, data.currency),
          ],
        );
      case 'claims-activity':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              report.title,
              'Claim date is used for monthly grouping.',
            ),
            const SizedBox(height: 12),
            _claimTable(data.claimsByMonth),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );

  Widget _summaryGrid(MembershipSummary summary) {
    final values = <(String, int, IconData)>[
      ('Total memberships', summary.total, Icons.people_alt_rounded),
      ('Active', summary.active, Icons.check_circle_outline_rounded),
      ('Suspended', summary.suspended, Icons.pause_circle_outline_rounded),
      ('Lapsed', summary.lapsed, Icons.history_toggle_off_rounded),
      ('Cancelled', summary.cancelled, Icons.cancel_outlined),
      ('Deceased', summary.deceased, Icons.person_off_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: values
              .map(
                (value) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            value.$3,
                            size: 30,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value.$1,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _number.format(value.$2),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _planTable(List<MembershipPlanCount> rows) => _tableCard(
        DataTable(
          columns: const [
            DataColumn(label: Text('Plan')),
            DataColumn(label: Text('Code')),
            DataColumn(numeric: true, label: Text('Memberships')),
            DataColumn(numeric: true, label: Text('Active')),
            DataColumn(label: Text('Plan status')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.planName)),
                    DataCell(Text(row.planCode)),
                    DataCell(Text(_number.format(row.membershipCount))),
                    DataCell(Text(_number.format(row.activeMembershipCount))),
                    DataCell(
                      Chip(
                        label: Text(row.activePlan ? 'Active' : 'Inactive'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      );

  Widget _premiumBars(List<PremiumPeriod> rows) {
    final maxValue = rows.fold<int>(
      1,
      (max, row) => row.paidCount + row.outstandingCount > max
          ? row.paidCount + row.outstandingCount
          : max,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: rows.map((row) {
            final paidFraction = row.paidCount / maxValue;
            final outstandingFraction = row.outstandingCount / maxValue;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 76, child: Text(row.label)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 12,
                            child: LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: [
                                  Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  Container(
                                    width: constraints.maxWidth * paidFraction,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 8,
                            child: LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: [
                                  Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  Container(
                                    width:
                                        constraints.maxWidth * outstandingFraction,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 116,
                    child: Text(
                      '${_number.format(row.paidCount)} paid\n${_number.format(row.outstandingCount)} outstanding',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _premiumTable(List<PremiumPeriod> rows, String currency) => _tableCard(
        DataTable(
          columns: const [
            DataColumn(label: Text('Period')),
            DataColumn(numeric: true, label: Text('Paid')),
            DataColumn(numeric: true, label: Text('Unpaid')),
            DataColumn(numeric: true, label: Text('Partial')),
            DataColumn(numeric: true, label: Text('Outstanding')),
            DataColumn(numeric: true, label: Text('Excluded')),
            DataColumn(numeric: true, label: Text('Paid amount')),
            DataColumn(numeric: true, label: Text('Outstanding amount')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.label)),
                    DataCell(Text(_number.format(row.paidCount))),
                    DataCell(Text(_number.format(row.unpaidCount))),
                    DataCell(Text(_number.format(row.partiallyPaidCount))),
                    DataCell(Text(_number.format(row.outstandingCount))),
                    DataCell(Text(_number.format(row.excludedCount))),
                    DataCell(Text(_money(row.paidAmountCents, currency))),
                    DataCell(Text(_money(row.outstandingAmountCents, currency))),
                  ],
                ),
              )
              .toList(),
        ),
      );

  Widget _claimTable(List<ClaimMonth> rows) {
    final types = rows.expand((row) => row.byType.keys).toSet().toList()..sort();
    return _tableCard(
      DataTable(
        columns: [
          const DataColumn(label: Text('Month')),
          ...types.map(
            (type) => DataColumn(
              numeric: true,
              label: Text(_title(type)),
            ),
          ),
          const DataColumn(numeric: true, label: Text('Total')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.label)),
                  ...types.map(
                    (type) => DataCell(
                      Text(_number.format(row.byType[type] ?? 0)),
                    ),
                  ),
                  DataCell(Text(_number.format(row.totalCount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tableCard(Widget table) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      );

  String _money(int cents, String currency) =>
      '$currency ${NumberFormat('#,##0.00').format(cents / 100)}';

  static String _title(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

enum _ReportCategory { management, operational }

class _ReportDefinition {
  final String key;
  final String workcenterId;
  final String title;
  final String description;
  final _ReportCategory category;
  final IconData icon;
  final bool usesPeriods;
  final bool usesDates;
  final bool usesCashier;

  const _ReportDefinition({
    required this.key,
    required this.workcenterId,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.usesPeriods = false,
    this.usesDates = false,
    this.usesCashier = false,
  });
}

class _AccessDeniedState extends StatelessWidget {
  final String? reportTitle;

  const _AccessDeniedState({this.reportTitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                reportTitle == null ? 'No reports assigned' : 'Report access required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                reportTitle == null
                    ? 'Your current role does not have access to any reports.'
                    : 'Your current role is not assigned access to $reportTitle.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Reports could not be loaded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      );
}
