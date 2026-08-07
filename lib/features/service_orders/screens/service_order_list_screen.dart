import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../models/service_order.dart';
import '../services/service_order_service.dart';
import 'service_order_screen.dart';

class ServiceOrderListScreen extends StatefulWidget {
  const ServiceOrderListScreen({super.key});

  @override
  State<ServiceOrderListScreen> createState() => _ServiceOrderListScreenState();
}

class _ServiceOrderListScreenState extends State<ServiceOrderListScreen> {
  final ServiceOrderService _service = ServiceOrderService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_ZA',
    symbol: 'R ',
    decimalDigits: 2,
  );

  bool _loading = true;
  String? _error;
  String _selectedStatus = 'ALL';
  List<ServiceOrder> _orders = <ServiceOrder>[];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_refreshFilter);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshFilter)
      ..dispose();
    super.dispose();
  }

  void _refreshFilter() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _service.search();
      orders.sort((a, b) {
        final aDate = a.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  List<String> get _statuses {
    final statuses = _orders
        .map((order) => order.status.trim().toUpperCase())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return <String>['ALL', ...statuses];
  }

  List<ServiceOrder> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders.where((order) {
      final statusMatches = _selectedStatus == 'ALL' ||
          order.status.trim().toUpperCase() == _selectedStatus;
      if (!statusMatches) return false;
      if (query.isEmpty) return true;
      return <String>[
        order.serviceOrderNo,
        order.customerName,
        order.assignedEmployeeName,
        order.location,
        order.primarySourceLabel,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Service Orders'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(colorScheme),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(colorScheme)
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final horizontalPadding =
                                    constraints.maxWidth < 640 ? 8.0 : 16.0;
                                return ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    12,
                                    horizontalPadding,
                                    24,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1180,
                                        ),
                                        child: _buildOrderCard(
                                          filtered[index],
                                          colorScheme,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search service order, customer or source',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final selected = status == _selectedStatus;
                return ChoiceChip(
                  label: Text(
                    status.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) =>
                      setState(() => _selectedStatus = status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    ServiceOrder order,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ServiceOrderScreen(serviceOrderId: order.id),
            ),
          );
          await _load();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;
            return Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: compact
                  ? _buildCompactOrder(order, colorScheme)
                  : _buildDesktopOrder(order, colorScheme),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactOrder(
    ServiceOrder order,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _orderIcon(colorScheme, compact: true),
            const SizedBox(width: 10),
            Expanded(child: _orderIdentity(order, colorScheme)),
            const SizedBox(width: 8),
            Text(
              _money.format(order.totalCents / 100),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _metadata(
              Icons.calendar_today_outlined,
              _formatDate(order.orderDate),
              colorScheme,
            ),
            if (order.scheduledStartAt != null)
              _metadata(
                Icons.schedule_outlined,
                DateFormat('dd MMM HH:mm').format(order.scheduledStartAt!),
                colorScheme,
              ),
            _statusChip(order.status),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopOrder(
    ServiceOrder order,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        _orderIcon(colorScheme),
        const SizedBox(width: 12),
        Expanded(child: _orderIdentity(order, colorScheme)),
        const SizedBox(width: 16),
        SizedBox(
          width: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metadata(
                Icons.calendar_today_outlined,
                _formatDate(order.orderDate),
                colorScheme,
              ),
              if (order.scheduledStartAt != null) ...[
                const SizedBox(height: 4),
                _metadata(
                  Icons.schedule_outlined,
                  DateFormat('dd MMM yyyy HH:mm')
                      .format(order.scheduledStartAt!),
                  colorScheme,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money.format(order.totalCents / 100),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              _statusChip(order.status),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _orderIcon(
    ColorScheme colorScheme, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.build_circle_outlined,
        size: compact ? 20 : 24,
        color: colorScheme.primary,
      ),
    );
  }

  Widget _orderIdentity(
    ServiceOrder order,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.customerName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          order.serviceOrderNo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          order.primarySourceLabel,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _metadata(
    IconData icon,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.trim().toUpperCase();
    final Color color;
    switch (normalized) {
      case 'COMPLETED':
      case 'INVOICED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        color = Colors.blue;
        break;
      case 'SCHEDULED':
        color = Colors.indigo;
        break;
      case 'DRAFT':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        normalized.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Service orders could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined, size: 54),
            SizedBox(height: 12),
            Text('No service orders found'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }
}
