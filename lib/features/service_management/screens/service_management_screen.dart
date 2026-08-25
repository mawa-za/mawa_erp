import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../../core/widgets/quick_customer_create_dialog.dart';
import '../../partners/models/partner.dart';
import '../services/service_management_service.dart';

enum ServiceManagementView { overview, requests, contracts, resources }

class ServiceManagementScreen extends StatefulWidget {
  final ServiceManagementView view;

  const ServiceManagementScreen({
    super.key,
    this.view = ServiceManagementView.overview,
  });

  @override
  State<ServiceManagementScreen> createState() => _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen>
    with SingleTickerProviderStateMixin {
  final _service = ServiceManagementService();
  late final TabController _tabs;
  bool _loading = true;
  Map<String, dynamic> _dashboard = const {};
  List<Map<String, dynamic>> _requests = const [];
  List<Map<String, dynamic>> _contracts = const [];
  List<Map<String, dynamic>> _resources = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: switch (widget.view) {
        ServiceManagementView.requests => 1,
        ServiceManagementView.contracts => 2,
        ServiceManagementView.resources => 3,
        ServiceManagementView.overview => 0,
      },
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      switch (widget.view) {
        case ServiceManagementView.requests:
          final requests = await _service.requests();
          if (!mounted) return;
          setState(() => _requests = requests);
          break;
        case ServiceManagementView.contracts:
          final contracts = await _service.contracts();
          if (!mounted) return;
          setState(() => _contracts = contracts);
          break;
        case ServiceManagementView.resources:
          final resources = await _service.resources();
          if (!mounted) return;
          setState(() => _resources = resources);
          break;
        case ServiceManagementView.overview:
          final values = await Future.wait([
            _service.dashboard(),
            _service.requests(),
            _service.contracts(),
            _service.resources(),
          ]);
          if (!mounted) return;
          setState(() {
            _dashboard = values[0] as Map<String, dynamic>;
            _requests = values[1] as List<Map<String, dynamic>>;
            _contracts = values[2] as List<Map<String, dynamic>>;
            _resources = values[3] as List<Map<String, dynamic>>;
          });
          break;
      }
    } catch (error) {
      _message(friendlyErrorMessage(error, fallback: 'Unable to load $_pageTitle.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (widget.view == ServiceManagementView.overview)
            PopupMenuButton<String>(
              onSelected: _handleAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'contract', child: Text('New service contract')),
                PopupMenuItem(value: 'resource', child: Text('New service resource')),
                PopupMenuItem(value: 'requirement', child: Text('Configure service resource requirement')),
                PopupMenuItem(value: 'generate', child: Text('Generate recurring visits')),
              ],
            ),
        ],
        bottom: widget.view == ServiceManagementView.overview
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Contracts'),
                  Tab(text: 'Resources'),
                ],
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.view == ServiceManagementView.overview
              ? TabBarView(
                  controller: _tabs,
                  children: [
                    _overview(),
                    _requestsTab(),
                    _contractsTab(),
                    _resourcesTab(),
                  ],
                )
              : _standaloneBody,
      floatingActionButton: widget.view == ServiceManagementView.contracts
          ? FloatingActionButton.extended(
              onPressed: _newContract,
              icon: const Icon(Icons.add),
              label: const Text('Contract'),
            )
          : widget.view == ServiceManagementView.resources
              ? FloatingActionButton.extended(
                  onPressed: _newResource,
                  icon: const Icon(Icons.add),
                  label: const Text('Resource'),
                )
              : widget.view == ServiceManagementView.overview
                  ? ListenableBuilder(
                      listenable: _tabs,
                      builder: (_, __) {
                        if (_tabs.index == 2) {
                          return FloatingActionButton.extended(
                            onPressed: _newContract,
                            icon: const Icon(Icons.add),
                            label: const Text('Contract'),
                          );
                        }
                        if (_tabs.index == 3) {
                          return FloatingActionButton.extended(
                            onPressed: _newResource,
                            icon: const Icon(Icons.add),
                            label: const Text('Resource'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  : null,
    );
  }

  String get _pageTitle => switch (widget.view) {
        ServiceManagementView.requests => 'Service Requests',
        ServiceManagementView.contracts => 'Service Contracts',
        ServiceManagementView.resources => 'Service Resources',
        ServiceManagementView.overview => 'Service Management',
      };

  Widget get _standaloneBody => switch (widget.view) {
        ServiceManagementView.requests => _requestsTab(),
        ServiceManagementView.contracts => _contractsTab(),
        ServiceManagementView.resources => _resourcesTab(),
        ServiceManagementView.overview => _overview(),
      };

  Widget _overview() {
    final cards = <_Metric>[
      _Metric('Active contracts', _dashboard['activeContracts'], Icons.description_outlined),
      _Metric('Today appointments', _dashboard['todayAppointments'], Icons.event_available_outlined),
      _Metric('Ready / scheduled', _dashboard['readyOrders'], Icons.assignment_outlined),
      _Metric('In progress', _dashboard['inProgressOrders'], Icons.play_circle_outline),
      _Metric('Completed not invoiced', _dashboard['completedNotInvoiced'], Icons.receipt_long_outlined),
      _Metric('Pending resource', _dashboard['pendingResource'], Icons.warning_amber_outlined),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((metric) => SizedBox(width: 230, child: _metricCard(metric)))
                .toList(),
          ),
          const SizedBox(height: 24),
          Text('Operations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _actionCard('Service orders', 'Manage work to be performed', Icons.assignment_outlined,
                  () => context.go(AppRoutes.serviceOrders)),
              _actionCard('Calendar', 'Schedule and reschedule service visits', Icons.calendar_month_outlined,
                  () => context.go(AppRoutes.appointments)),
              _actionCard('Products & services', 'Maintain the service catalogue and pricing', Icons.design_services_outlined,
                  () => context.go(AppRoutes.products)),
              _actionCard('Purple publishing', 'Choose customer-facing services and online availability', Icons.public_outlined,
                  () => context.go(AppRoutes.systemConfiguration)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(_Metric metric) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(child: Icon(metric.icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${metric.value ?? 0}', style: Theme.of(context).textTheme.headlineSmall),
                    Text(metric.label),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _actionCard(String title, String subtitle, IconData icon, VoidCallback onTap) => SizedBox(
        width: 320,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );

  Widget _requestsTab() {
    if (_requests.isEmpty) {
      return const Center(child: Text('No service requests yet. Purple and ERP service requests will appear here.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final request = _requests[index];
          final recurring = request['recurring_requested'] == true || '${request['recurring_requested']}' == '1';
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(recurring ? Icons.autorenew : Icons.support_agent_outlined)),
              title: Text('${request['number'] ?? request['no'] ?? 'Service request'} • ${request['service_name'] ?? request['summary'] ?? ''}'),
              subtitle: Text([
                '${request['customer_name'] ?? ''}',
                if ('${request['service_location_name'] ?? ''}'.isNotEmpty) '${request['service_location_name']}',
                if (request['preferred_date'] != null) 'Preferred ${request['preferred_date']} ${request['preferred_start_time'] ?? ''}',
                if ('${request['source_channel'] ?? ''}'.isNotEmpty) 'Source ${request['source_channel']}',
              ].where((value) => value.trim().isNotEmpty).join(' • ')),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _convertRequest(request, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'order', child: Text('Create service order')),
                  if (recurring) const PopupMenuItem(value: 'contract', child: Text('Create draft contract')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _convertRequest(Map<String, dynamic> request, String action) async {
    try {
      final id = '${request['id']}';
      if (action == 'contract') {
        await _service.createContractFromRequest(id);
        _message('Draft service contract created.');
      } else {
        await _service.createOrderFromRequest(id);
        _message('Service order created and ready for scheduling.');
      }
      await _load();
    } catch (error) {
      _message(friendlyErrorMessage(error, fallback: 'Unable to convert the service request.'));
    }
  }

  Widget _contractsTab() {
    if (_contracts.isEmpty) {
      return _empty('No service contracts yet', 'Create a recurring service agreement for a customer.', _newContract);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _contracts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final contract = _contracts[index];
          final status = '${contract['status'] ?? ''}';
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
              title: Text('${contract['contract_no'] ?? contract['contractNo'] ?? 'Service contract'}'),
              subtitle: Text([
                if ('${contract['service_location_name'] ?? ''}'.isNotEmpty)
                  '${contract['service_location_name']}',
                '${contract['start_date'] ?? contract['startDate'] ?? ''}' +
                    ('${contract['end_date'] ?? contract['endDate'] ?? ''}'.isNotEmpty
                        ? ' – ${contract['end_date'] ?? contract['endDate']}'
                        : ''),
                '${contract['active_schedules'] ?? 0} recurring schedule(s)',
              ].where((e) => e.isNotEmpty).join(' • ')),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _contractStatus(contract, value),
                itemBuilder: (_) => [
                  if (status != 'ACTIVE') const PopupMenuItem(value: 'ACTIVE', child: Text('Activate')),
                  if (status == 'ACTIVE') const PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend')),
                  if (status != 'CANCELLED') const PopupMenuItem(value: 'CANCELLED', child: Text('Cancel')),
                ],
                child: Chip(label: Text(status.isEmpty ? 'DRAFT' : status)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _resourcesTab() {
    if (_resources.isEmpty) {
      return _empty('No service resources yet', 'Add employees, teams, facilities or equipment used for scheduling.', _newResource);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _resources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final resource = _resources[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.groups_2_outlined)),
              title: Text('${resource['name'] ?? ''}'),
              subtitle: Text('${resource['resource_type'] ?? resource['resourceType'] ?? ''} • Capacity ${resource['capacity'] ?? 1}'),
              trailing: '${resource['active']}' == '0'
                  ? const Chip(label: Text('Inactive'))
                  : const Chip(label: Text('Active')),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(String title, String message, VoidCallback action) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.design_services_outlined, size: 56),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: action, icon: const Icon(Icons.add), label: const Text('Create')),
              ],
            ),
          ),
        ),
      );

  Future<void> _handleAction(String action) async {
    if (action == 'contract') return _newContract();
    if (action == 'resource') return _newResource();
    if (action == 'requirement') return _newRequirement();
    if (action == 'generate') {
      try {
        final result = await _service.generateRecurring();
        _message('Generated ${result['generated'] ?? 0} visit(s); ${result['pendingResource'] ?? 0} need resource assignment.');
        await _load();
      } catch (error) {
        _message(friendlyErrorMessage(error, fallback: 'Unable to generate recurring visits.'));
      }
    }
  }

  Future<void> _contractStatus(Map<String, dynamic> contract, String status) async {
    try {
      await _service.changeContractStatus('${contract['id']}', status);
      await _load();
    } catch (error) {
      _message(friendlyErrorMessage(error, fallback: 'Unable to update the contract.'));
    }
  }

  Future<void> _newContract() async {
    final products = await _service.serviceProducts();
    if (!mounted) return;
    Partner? customer;
    String? selectedProductId;
    DateTime start = DateTime.now();
    DateTime? end;
    String frequency = 'WEEKLY';
    int interval = 1;
    int dayOfWeek = start.weekday;
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0);
    final location = TextEditingController();
    final price = TextEditingController();
    final notes = TextEditingController();
    bool active = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New service contract'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PartnerSearchDropdown(
                    key: ValueKey(customer?.id ?? 'service-contract-customer'),
                    role: 'CUSTOMER',
                    label: 'Search customer',
                    initialPartner: customer,
                    onPartnerSelected: (value) => setLocal(() => customer = value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await showQuickCustomerCreateDialog(context);
                        if (created != null) setLocal(() => customer = created);
                      },
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Quick create customer'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: '${p['id']}',
                              child: Text('${p['description'] ?? p['code'] ?? p['id']}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setLocal(() => selectedProductId = value);
                      final selected = products.where((p) => '${p['id']}' == value).toList();
                      if (selected.isNotEmpty && price.text.isEmpty && selected.first['price'] != null) {
                        price.text = '${selected.first['price']}';
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Service address / location'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: start,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (value != null) setLocal(() { start = value; dayOfWeek = value.weekday; });
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('Start ${_date(start)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: end ?? start.add(const Duration(days: 365)),
                              firstDate: start,
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (value != null) setLocal(() => end = value);
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(end == null ? 'No end date' : 'End ${_date(end!)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: frequency,
                          decoration: const InputDecoration(labelText: 'Frequency'),
                          items: const [
                            DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                            DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                            DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                          ],
                          onChanged: (v) => setLocal(() => frequency = v ?? 'WEEKLY'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: interval,
                          decoration: const InputDecoration(labelText: 'Repeat every'),
                          items: List.generate(12, (i) => i + 1)
                              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                              .toList(),
                          onChanged: (v) => setLocal(() => interval = v ?? 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (frequency == 'WEEKLY')
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: dayOfWeek,
                            decoration: const InputDecoration(labelText: 'Day'),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Monday')),
                              DropdownMenuItem(value: 2, child: Text('Tuesday')),
                              DropdownMenuItem(value: 3, child: Text('Wednesday')),
                              DropdownMenuItem(value: 4, child: Text('Thursday')),
                              DropdownMenuItem(value: 5, child: Text('Friday')),
                              DropdownMenuItem(value: 6, child: Text('Saturday')),
                              DropdownMenuItem(value: 7, child: Text('Sunday')),
                            ],
                            onChanged: (v) => setLocal(() => dayOfWeek = v ?? 1),
                          ),
                        ),
                      if (frequency == 'WEEKLY') const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showTimePicker(context: context, initialTime: time);
                            if (value != null) setLocal(() => time = value);
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(time.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Agreed price (R)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setLocal(() => active = value),
                    title: const Text('Activate immediately'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: customer == null || selectedProductId == null
                  ? null
                  : () async {
                      try {
                        String? locationId;
                        if (location.text.trim().isNotEmpty) {
                          final savedLocation = await _service.saveLocation({
                            'customerPartnerId': customer!.id,
                            'name': location.text.trim(),
                            'addressLine1': location.text.trim(),
                            'active': true,
                          });
                          locationId = '${savedLocation['id']}';
                        }
                        final product = products.firstWhere((p) => '${p['id']}' == selectedProductId);
                        final parsed = double.tryParse(price.text.trim().replaceAll(',', '.')) ?? 0;
                        await _service.saveContract({
                          'customerPartnerId': customer!.id,
                          'serviceLocationId': locationId,
                          'status': active ? 'ACTIVE' : 'DRAFT',
                          'startDate': _date(start),
                          if (end != null) 'endDate': _date(end!),
                          'billingFrequency': 'MONTHLY',
                          'billingTiming': 'ARREARS',
                          'billingMode': 'FIXED_PERIODIC',
                          'currency': 'ZAR',
                          'notes': notes.text.trim(),
                          'lines': [
                            {
                              'productId': selectedProductId,
                              'description': '${product['description'] ?? 'Service'}',
                              'quantity': 1,
                              'unitPriceCents': (parsed * 100).round(),
                              'active': true,
                            }
                          ],
                          'schedules': [
                            {
                              'productId': selectedProductId,
                              'frequency': frequency,
                              'intervalCount': interval,
                              if (frequency == 'WEEKLY') 'dayOfWeek': dayOfWeek,
                              if (frequency == 'MONTHLY') 'dayOfMonth': start.day,
                              'preferredStartTime': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              'durationMinutes': 60,
                              'generationHorizonDays': 60,
                              'active': true,
                            }
                          ],
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(friendlyErrorMessage(error, fallback: 'Unable to save contract.'))),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    location.dispose();
    price.dispose();
    notes.dispose();
    if (saved == true) await _load();
  }

  Future<void> _newRequirement() async {
    final products = await _service.serviceProducts();
    final resources = await _service.resources();
    if (!mounted) return;
    String? productId;
    String resourceType = 'EMPLOYEE';
    String? resourceId;
    int quantity = 1;
    bool mandatory = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Service resource requirement'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: productId,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: products
                      .map((item) => DropdownMenuItem(
                            value: '${item['id']}',
                            child: Text('${item['description'] ?? item['code'] ?? item['id']}'),
                          ))
                      .toList(),
                  onChanged: (value) => setLocal(() => productId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: resourceType,
                  decoration: const InputDecoration(labelText: 'Resource type'),
                  items: const [
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee')),
                    DropdownMenuItem(value: 'TEAM', child: Text('Team / crew')),
                    DropdownMenuItem(value: 'FACILITY', child: Text('Facility / bay / chair')),
                    DropdownMenuItem(value: 'EQUIPMENT', child: Text('Equipment')),
                    DropdownMenuItem(value: 'CAPACITY', child: Text('Capacity resource')),
                  ],
                  onChanged: (value) => setLocal(() {
                    resourceType = value ?? 'EMPLOYEE';
                    resourceId = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: resourceId,
                  decoration: const InputDecoration(labelText: 'Specific resource (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Any resource of this type')),
                    ...resources
                        .where((item) => '${item['resource_type'] ?? item['resourceType']}' == resourceType)
                        .map((item) => DropdownMenuItem<String?>(
                              value: '${item['id']}',
                              child: Text('${item['name']}'),
                            )),
                  ],
                  onChanged: (value) => setLocal(() => resourceId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: quantity,
                  decoration: const InputDecoration(labelText: 'Capacity required'),
                  items: List.generate(20, (index) => index + 1)
                      .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
                      .toList(),
                  onChanged: (value) => setLocal(() => quantity = value ?? 1),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: mandatory,
                  onChanged: (value) => setLocal(() => mandatory = value),
                  title: const Text('Mandatory for booking'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: productId == null
                  ? null
                  : () async {
                      try {
                        await _service.saveResourceRequirement({
                          'productId': productId,
                          'resourceType': resourceType,
                          'resourceId': resourceId,
                          'quantity': quantity,
                          'mandatory': mandatory,
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(friendlyErrorMessage(error, fallback: 'Unable to save resource requirement.'))),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _message('Service resource requirement saved.');
  }

  Future<void> _newResource() async {
    final name = TextEditingController();
    final location = TextEditingController();
    String type = 'EMPLOYEE';
    int capacity = 1;
    bool active = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New service resource'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, onChanged: (_) => setLocal(() {}), decoration: const InputDecoration(labelText: 'Resource name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Resource type'),
                  items: const [
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee')),
                    DropdownMenuItem(value: 'TEAM', child: Text('Team / crew')),
                    DropdownMenuItem(value: 'FACILITY', child: Text('Facility / bay / chair')),
                    DropdownMenuItem(value: 'EQUIPMENT', child: Text('Equipment')),
                    DropdownMenuItem(value: 'CAPACITY', child: Text('Capacity resource')),
                  ],
                  onChanged: (value) => setLocal(() => type = value ?? 'EMPLOYEE'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: capacity,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  items: List.generate(20, (i) => i + 1)
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (value) => setLocal(() => capacity = value ?? 1),
                ),
                const SizedBox(height: 12),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location (optional)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () async {
                      try {
                        await _service.saveResource({
                          'name': name.text.trim(),
                          'resourceType': type,
                          'capacity': capacity,
                          'location': location.text.trim(),
                          'active': active,
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(friendlyErrorMessage(error, fallback: 'Unable to save resource.'))),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    location.dispose();
    if (saved == true) await _load();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _Metric {
  final String label;
  final dynamic value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
}
