import 'package:flutter/material.dart';
import '../models/tombstone_models.dart';
import '../services/tombstone_service.dart';
import 'tombstone_order_detail_screen.dart';
import 'tombstone_order_form_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class TombstoneManagementScreen extends StatefulWidget {
  final String initialSection;
  const TombstoneManagementScreen({super.key, this.initialSection = 'orders'});

  @override
  State<TombstoneManagementScreen> createState() => _TombstoneManagementScreenState();
}

class _TombstoneManagementScreenState extends State<TombstoneManagementScreen> {
  static const _sections = <String, String>{
    'orders': 'Orders',
    'laybys': 'Lay-by Agreements',
    'assessments': 'Site Assessments',
    'designs': 'Design Approvals',
    'production': 'Production Jobs',
    'installations': 'Installation Planning',
    'calendar': 'Installation Calendar',
    'teams': 'Installation Teams',
    'rework': 'Rework Jobs',
    'reports': 'Reports',
  };

  final _service = TombstoneService();
  final _search = TextEditingController();
  String _section = 'orders';
  bool _loading = true;
  String? _error;
  TombstoneDashboard? _dashboard;
  List<TombstoneOrder> _orders = const [];
  List<Map<String, dynamic>> _records = const [];

  @override
  void initState() {
    super.initState();
    _section = _sections.containsKey(widget.initialSection) ? widget.initialSection : 'orders';
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dashboard = await _service.dashboard();
      List<TombstoneOrder> orders = const [];
      List<Map<String, dynamic>> records = const [];
      switch (_section) {
        case 'orders':
          orders = await _service.orders(query: _search.text.trim());
          break;
        case 'laybys':
          records = await _service.laybys();
          break;
        case 'assessments':
          records = await _service.assessments();
          break;
        case 'designs':
          records = await _service.designs();
          break;
        case 'production':
          records = await _service.productionJobs();
          break;
        case 'installations':
        case 'calendar':
        case 'teams':
          records = await _service.installations();
          break;
        case 'rework':
          records = await _service.installations(status: 'REWORK_REQUIRED');
          break;
      }
      if (!mounted) return;
      setState(() { _dashboard = dashboard; _orders = orders; _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyErrorMessage(e); _loading = false; });
    }
  }

  Future<void> _newOrder() async {
    final order = await Navigator.of(context).push<TombstoneOrder>(
      MaterialPageRoute(builder: (_) => const TombstoneOrderFormScreen()),
    );
    if (order != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TombstoneOrderDetailScreen(orderId: order.id)));
      _load();
    }
  }

  Future<void> _openOrder(String? id) async {
    if (id == null || id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TombstoneOrderDetailScreen(orderId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tombstone Management'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _section == 'orders'
          ? FloatingActionButton.extended(onPressed: _newOrder, icon: const Icon(Icons.add), label: const Text('New Order'))
          : null,
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 960) {
          return Row(children: [
            NavigationRail(
              selectedIndex: _sections.keys.toList().indexOf(_section),
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) { setState(() => _section = _sections.keys.elementAt(index)); _load(); },
              destinations: _sections.entries.map((e) => NavigationRailDestination(icon: Icon(_icon(e.key)), label: Text(e.value))).toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _content()),
          ]);
        }
        return Column(children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _sections.entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: e.key == _section,
                  label: Text(e.value),
                  onSelected: (_) { setState(() => _section = e.key); _load(); },
                ),
              )).toList(),
            ),
          ),
          Expanded(child: _content()),
        ]);
      }),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dashboardCards(),
          const SizedBox(height: 16),
          if (_section == 'orders') _orderSearch(),
          if (_section == 'reports') _reports(),
          if (_section == 'orders' && _orders.isNotEmpty) _orderListHeader(),
          if (_section == 'orders') ..._orders.map(_orderCard),
          if (_section != 'orders' && _section != 'reports') ..._records.map(_recordCard),
          if (_section == 'orders' && _orders.isEmpty) _empty('No tombstone orders found'),
          if (_section != 'orders' && _section != 'reports' && _records.isEmpty) _empty('No ${_sections[_section]!.toLowerCase()} found'),
        ],
      ),
    );
  }

  Widget _dashboardCards() {
    final d = _dashboard;
    if (d == null) return const SizedBox.shrink();
    final values = [
      ('Orders', d.count('totalOrders'), Icons.inventory_2_outlined),
      ('Awaiting funding', d.count('awaitingFunding'), Icons.account_balance_wallet_outlined),
      ('In production', d.count('inProduction'), Icons.precision_manufacturing_outlined),
      ('Ready to install', d.count('readyForInstallation'), Icons.construction_outlined),
      ('Scheduled', d.count('scheduledInstallations'), Icons.event_available_outlined),
      ('Rework', d.count('reworkRequired'), Icons.build_circle_outlined),
    ];
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: values.map((v) => SizedBox(width: 180, child: Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [Icon(v.$3), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${v.$2}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(v.$1, maxLines: 2),
        ]))]),
      )))).toList(),
    );
  }

  Widget _orderSearch() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _load(),
      decoration: InputDecoration(
        hintText: 'Search order, deceased, cemetery or grave',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _orderListHeader() => Container(
    margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blueGrey[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: const Row(
      children: [
        SizedBox(width: 44),
        Expanded(
          child: Text(
            'DECEASED / REFERENCE',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
        SizedBox(width: 8),
        Text(
          'INSTALLATION / FUNDING',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        SizedBox(
          width: 100,
          child: Text(
            'AMOUNT / STATUS',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
      ],
    ),
  );

  Widget _orderCard(TombstoneOrder order) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openOrder(order.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_balance_outlined, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.deceasedName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${order.orderNo}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (order.cemeteryName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${order.cemeteryName}${order.graveNumber == null ? '' : ' • Grave ${order.graveNumber}'}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.expectedInstallationDate ?? 'Not scheduled',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _label(order.fundingStatus),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R ${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _orderStatusChip(order.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderStatusChip(String status) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.red,
      'DRAFT' => Colors.grey,
      'IN_PRODUCTION' => Colors.blue,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        normalized.replaceAll('_', ' '),
        textAlign: TextAlign.right,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final orderId = record['tombstoneOrderId']?.toString();
    final title = switch (_section) {
      'laybys' => record['agreementNo']?.toString() ?? 'Lay-by agreement',
      'assessments' => 'Assessment v${record['versionNo'] ?? ''}',
      'designs' => 'Design v${record['versionNo'] ?? ''}',
      'production' => record['jobNo']?.toString() ?? 'Production job',
      _ => record['installationNo']?.toString() ?? 'Installation',
    };
    final status = record['status']?.toString() ?? '';
    final subtitle = switch (_section) {
      'laybys' => 'Balance R ${_cents(record['balanceCents']).toStringAsFixed(2)} • ${_label(status)}',
      'calendar' => '${record['scheduledStartAt'] ?? 'Not scheduled'} • ${_label(status)}',
      'teams' => '${(record['team'] as List? ?? const []).length} team member(s) • ${_label(status)}',
      _ => _label(status),
    };
    return Card(child: ListTile(
      leading: Icon(_icon(_section)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => _openOrder(orderId),
    ));
  }

  Widget _reports() {
    final d = _dashboard!;
    return Card(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Operational Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _reportRow('Fully funded orders', d.count('fullyFunded').toString()),
        _reportRow('Site assessments pending', d.count('assessmentPending').toString()),
        _reportRow('Designs pending', d.count('designPending').toString()),
        _reportRow('Completed installations', d.count('completed').toString()),
        _reportRow('Outstanding lay-by balance', 'R ${d.amount('outstandingLaybyCents').toStringAsFixed(2)}'),
      ]),
    ));
  }

  Widget _reportRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Center(child: Column(children: [const Icon(Icons.inbox_outlined, size: 52), const SizedBox(height: 12), Text(text)])),
  );

  IconData _icon(String key) => switch (key) {
    'orders' => Icons.inventory_2_outlined,
    'laybys' => Icons.savings_outlined,
    'assessments' => Icons.location_searching,
    'designs' => Icons.design_services_outlined,
    'production' => Icons.precision_manufacturing_outlined,
    'installations' => Icons.construction_outlined,
    'calendar' => Icons.calendar_month_outlined,
    'teams' => Icons.groups_outlined,
    'rework' => Icons.build_circle_outlined,
    _ => Icons.analytics_outlined,
  };

  static String _label(String value) => value.replaceAll('_', ' ').toLowerCase().split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
  static double _cents(dynamic value) => ((value as num?)?.toInt() ?? 0) / 100;
}
