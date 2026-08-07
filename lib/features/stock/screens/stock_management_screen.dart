import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../home/models/workcenter.dart';
import '../services/stock_service.dart';
import '../widgets/inventory_document_dialog.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class InventoryManagementScreen extends StatefulWidget {
  final String? initialSection;

  const InventoryManagementScreen({super.key, this.initialSection});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final StockService _service = StockService();
  bool _loading = true;
  String? _error;
  bool _initialSectionApplied = false;
  _InventorySection? _selectedSection;
  final Map<_InventorySection, String> _statusFilters = <_InventorySection, String>{};
  List<_InventoryCardDefinition> _visibleCards = [];

  Map<String, dynamic> _dashboard = <String, dynamic>{};
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _putaways = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _salesOrders = [];
  List<Map<String, dynamic>> _audit = [];

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
      List<_InventoryCardDefinition> cards;
      try {
        cards = await _loadVisibleCards();
      } catch (_) {
        // The backend still protects every operation. A stale role-workcenter
        // response must not make a valid deep-linked inventory tile unusable.
        cards = List<_InventoryCardDefinition>.from(
          _inventoryCardCatalog.where(
            (card) => !_isCommercialDocumentSection(card.section),
          ),
        );
      }

      final requested = _requestedSection();
      if (requested != null && !cards.any((card) => card.section == requested)) {
        cards.add(_inventoryCardCatalog.firstWhere((card) => card.section == requested));
      }
      if (cards.isEmpty && widget.initialSection == null) {
        cards = List<_InventoryCardDefinition>.from(
          _inventoryCardCatalog.where(
            (card) => !_isCommercialDocumentSection(card.section),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _visibleCards = cards;
        _selectedSection ??= requested;
      });

      await _loadSectionData(_selectedSection ?? _InventorySection.dashboard);
      if (!mounted) return;
      setState(() {
        _initialSectionApplied = true;
        if (_selectedSection != null &&
            !_visibleCards.any((card) => card.section == _selectedSection)) {
          _selectedSection = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _InventorySection? _requestedSection() {
    final requested = widget.initialSection;
    if (requested == null || requested.trim().isEmpty) return null;
    final normalized = _normalize(requested);
    for (final card in _inventoryCardCatalog) {
      if (card.matchesSection(normalized)) return card.section;
    }
    return null;
  }

  Future<void> _loadSectionData(_InventorySection section) async {
    switch (section) {
      case _InventorySection.dashboard:
        _dashboard = await _service.dashboard();
        break;
      case _InventorySection.quotations:
        _quotations = await _service.quotations();
        break;
      case _InventorySection.purchaseOrders:
        _purchaseOrders = await _service.purchaseOrders();
        break;
      case _InventorySection.stock:
        _stock = await _service.stock();
        break;
      case _InventorySection.goodsReceipts:
        _receipts = await _service.goodsReceipts();
        final dependencies = await Future.wait<dynamic>([
          _service.purchaseOrders().catchError((_) => <Map<String, dynamic>>[]),
          _service.warehouses().catchError((_) => <Map<String, dynamic>>[]),
          _service.storageLocations().catchError((_) => <Map<String, dynamic>>[]),
        ]);
        _purchaseOrders = List<Map<String, dynamic>>.from(dependencies[0] as List);
        _warehouses = List<Map<String, dynamic>>.from(dependencies[1] as List);
        _locations = List<Map<String, dynamic>>.from(dependencies[2] as List);
        break;
      case _InventorySection.putaways:
        _putaways = await _service.putaways();
        final dependencies = await Future.wait<dynamic>([
          _service.goodsReceipts().catchError((_) => <Map<String, dynamic>>[]),
          _service.warehouses().catchError((_) => <Map<String, dynamic>>[]),
          _service.storageLocations().catchError((_) => <Map<String, dynamic>>[]),
        ]);
        _receipts = List<Map<String, dynamic>>.from(dependencies[0] as List);
        _warehouses = List<Map<String, dynamic>>.from(dependencies[1] as List);
        _locations = List<Map<String, dynamic>>.from(dependencies[2] as List);
        break;
      case _InventorySection.movements:
        _movements = await _service.movements();
        break;
      case _InventorySection.salesOrders:
        _salesOrders = await _service.salesOrders();
        break;
      case _InventorySection.audit:
        _audit = await _service.audit();
        break;
      case _InventorySection.setup:
        final setup = await Future.wait<dynamic>([
          _service.warehouses(),
          _service.storageLocations(),
        ]);
        _warehouses = List<Map<String, dynamic>>.from(setup[0] as List);
        _locations = List<Map<String, dynamic>>.from(setup[1] as List);
        break;
    }
  }

  Future<void> _openSection(_InventorySection section) async {
    setState(() {
      _selectedSection = section;
      _loading = true;
      _error = null;
    });
    try {
      await _loadSectionData(section);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_InventoryCardDefinition>> _loadVisibleCards() async {
    final prefs = await SharedPreferences.getInstance();
    final roleId = prefs.getString('selectedRole');
    if (roleId == null || roleId.trim().isEmpty) return const [];

    final response = await ApiClient().get('/role/$roleId/workcenter');
    if (response.statusCode != 200) {
      throw AppException('Failed to load role workcenters: ${response.statusCode} ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    final workcenters = data.map((json) => Workcenter.fromJson(json)).toList();
    final Map<String, int> positionsById = <String, int>{};
    for (final workcenter in workcenters) {
      final routeSegments = workcenter.routePath == null
          ? const <String>[]
          : (Uri.tryParse(workcenter.routePath!)?.pathSegments ??
              const <String>[]);
      final candidates = <String>[
        workcenter.id,
        workcenter.routeKey,
        workcenter.description,
        ...routeSegments,
      ];
      for (final candidate in candidates) {
        final normalized = _normalize(candidate);
        if (normalized.isEmpty) continue;
        positionsById.putIfAbsent(normalized, () => workcenter.position);
      }
    }
    final Set<String> allowed = positionsById.keys.toSet();

    final cards = _inventoryCardCatalog
        .where((card) => card.isAllowedBy(allowed))
        .where((card) => !_isCommercialDocumentSection(card.section))
        .toList();
    cards.sort((a, b) {
      final ap = a.positionFrom(positionsById);
      final bp = b.positionFrom(positionsById);
      if (ap != bp) return ap.compareTo(bp);
      return a.defaultOrder.compareTo(b.defaultOrder);
    });
    return cards;
  }

  void _applyInitialSectionIfNeeded() {
    if (_initialSectionApplied) return;
    _initialSectionApplied = true;
    final requested = widget.initialSection;
    if (requested == null || requested.trim().isEmpty) return;
    final normalized = _normalize(requested);
    _InventoryCardDefinition? matchingCard;
    for (final card in _visibleCards) {
      if (card.matchesSection(normalized)) {
        matchingCard = card;
        break;
      }
    }
    if (matchingCard != null) {
      _selectedSection = matchingCard.section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTitle = _cardForSection(_selectedSection)?.title ?? 'Inventory Operations';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(selectedTitle),
        leading: _selectedSection == null
            ? null
            : IconButton(
                tooltip: 'Back to Inventory cards',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedSection = null),
              ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: _buildActionButton(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(theme)
              : _visibleCards.isEmpty
                  ? _noAccessView(theme)
                  : _selectedSection == null
                      ? _inventoryCardLanding(theme)
                      : _sectionView(theme, _selectedSection!),
    );
  }

  Widget? _buildActionButton() {
    switch (_selectedSection) {
      case _InventorySection.quotations:
        return FloatingActionButton.extended(onPressed: _openQuotationDialog, icon: const Icon(Icons.add), label: const Text('Quotation'));
      case _InventorySection.purchaseOrders:
        return FloatingActionButton.extended(onPressed: _openPurchaseOrderDialog, icon: const Icon(Icons.add), label: const Text('Purchase Order'));
      case _InventorySection.goodsReceipts:
        return FloatingActionButton.extended(onPressed: _openGoodsReceiptDialog, icon: const Icon(Icons.add), label: const Text('Goods Receipt'));
      case _InventorySection.putaways:
        return FloatingActionButton.extended(onPressed: _openPutawayDialog, icon: const Icon(Icons.add), label: const Text('Putaway'));
      case _InventorySection.salesOrders:
        return FloatingActionButton.extended(onPressed: _openSalesOrderDialog, icon: const Icon(Icons.add), label: const Text('Sales Order'));
      case _InventorySection.setup:
        return FloatingActionButton.extended(onPressed: _openSetupDialog, icon: const Icon(Icons.store_mall_directory_outlined), label: const Text('Setup'));
      default:
        return null;
    }
  }

  Widget _errorView(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );

  Widget _noAccessView(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No inventory operation cards are enabled for your current role.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Ask an administrator to add the required Products & Inventory workcenters to your role configuration.', textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _inventoryCardLanding(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(1, 5);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Inventory Operations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Warehouse and stock processes live here. Sales documents remain under Sales & Customers and purchase orders remain under Procurement & Suppliers.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('Stock Qty', _dashboard['totalStockQuantity'], Icons.inventory_2_outlined),
              _metric('Pending Putaway', _dashboard['pendingPutaways'], Icons.compare_arrows_outlined),
            ]),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.32,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _visibleCards.length,
              itemBuilder: (context, index) {
                final card = _visibleCards[index];
                return _inventoryCard(theme, card);
              },
            ),
          ]),
        );
      }),
    );
  }

  Widget _inventoryCard(ThemeData theme, _InventoryCardDefinition card) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openSection(card.section),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                foregroundColor: theme.colorScheme.primary,
                child: Icon(card.icon),
              ),
              const Spacer(),
              Text(_cardMetric(card.section), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            ]),
            const Spacer(),
            Text(card.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(card.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
          ]),
        ),
      ),
    );
  }

  Widget _sectionView(ThemeData theme, _InventorySection section) {
    final card = _cardForSection(section)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
            foregroundColor: theme.colorScheme.primary,
            child: Icon(card.icon),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(card.subtitle, style: theme.textTheme.bodySmall),
          ])),
          TextButton.icon(onPressed: () => setState(() => _selectedSection = null), icon: const Icon(Icons.apps_outlined), label: const Text('Cards')),
        ]),
      ),
      Expanded(child: _sectionContent(section, theme)),
    ]);
  }

  Widget _sectionContent(_InventorySection section, ThemeData theme) {
    switch (section) {
      case _InventorySection.dashboard:
        return _dashboardView(theme);
      case _InventorySection.quotations:
        return _quotationView();
      case _InventorySection.purchaseOrders:
        return _purchaseOrderView();
      case _InventorySection.stock:
        return _tableView(_stock, const ['product_code', 'product_description', 'warehouse_code', 'location_code', 'on_hand_qty', 'reserved_qty', 'available_qty', 'uom']);
      case _InventorySection.goodsReceipts:
        return _statusTableView(
          section: _InventorySection.goodsReceipts,
          rows: _receipts,
          columns: const ['receipt_no', 'purchase_order_no', 'receipt_date', 'status', 'supplier_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
          dateKeys: const ['receipt_date', 'created_at', 'createdAt'],
        );
      case _InventorySection.putaways:
        return _statusTableView(
          section: _InventorySection.putaways,
          rows: _putaways,
          columns: const ['putaway_no', 'movement_date', 'status', 'warehouse_id', 'from_location_id', 'to_location_id'],
          dateKeys: const ['movement_date', 'created_at', 'createdAt'],
        );
      case _InventorySection.movements:
        return _tableView(
          _sortLatest(_movements, const ['movement_at', 'created_at', 'createdAt']),
          const ['movement_no', 'movement_type', 'product_code', 'quantity', 'uom', 'reference_no', 'processed_by', 'movement_at'],
        );
      case _InventorySection.salesOrders:
        return _salesOrderView();
      case _InventorySection.audit:
        return _tableView(
          _sortLatest(_audit, const ['created_at', 'createdAt']),
          const ['entity_type', 'action', 'entity_id', 'notes', 'created_by', 'created_at'],
        );
      case _InventorySection.setup:
        return _setupView(theme);
    }
  }

  Widget _dashboardView(ThemeData theme) {
    final stockByWarehouse = _asList(_dashboard['stockByWarehouse']);
    final lowStock = _asList(_dashboard['lowStock']);
    final recentMovements = _asList(_dashboard['recentMovements']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _metric('Stock Qty', _dashboard['totalStockQuantity'], Icons.inventory_2_outlined),
          _metric('Products', _dashboard['productCount'], Icons.category_outlined),
          _metric('Low Stock', _dashboard['lowStockCount'], Icons.warning_amber_outlined),
          _metric('Pending Putaway', _dashboard['pendingPutaways'], Icons.compare_arrows_outlined),
          _metric('Receipts Today', _dashboard['goodsReceiptsToday'], Icons.call_received_outlined),
          _metric('Warehouses', _dashboard['activeWarehouses'], Icons.store_mall_directory_outlined),
        ]),
        const SizedBox(height: 20),
        _section('Warehouse visibility', _simpleList(stockByWarehouse, ['warehouse_code', 'name', 'on_hand_qty'])),
        _section('Low stock visibility', _simpleList(lowStock, ['product_code', 'product_description', 'on_hand_qty', 'minimum_qty'])),
        _section('Recent stock movements', _simpleList(recentMovements, ['movement_no', 'movement_type', 'product_code', 'quantity'])),
      ]),
    );
  }

  Widget _setupView(ThemeData theme) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _section('Warehouses', _simpleList(_warehouses, ['warehouse_code', 'name', 'status'])),
      _section('Storage locations', _simpleList(_locations, ['location_code', 'name', 'location_type', 'warehouse_id'])),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(onPressed: _openSetupDialog, icon: const Icon(Icons.add_business_outlined), label: const Text('Create Warehouse / Receiving Location')),
      ),
    ]);
  }

  Widget _quotationView() => _statusTableView(
        section: _InventorySection.quotations,
        rows: _quotations,
        columns: const ['quotation_no', 'quotation_date', 'valid_until', 'status', 'customer_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        dateKeys: const ['quotation_date', 'created_at', 'createdAt'],
        actions: [
          _rowAction('Send', (row) => _service.updateQuotationStatus(_id(row), 'SENT')),
          _rowAction('Accept', (row) => _service.updateQuotationStatus(_id(row), 'ACCEPTED')),
          _rowAction('Convert', (row) => _service.convertQuotationToSalesOrder(_id(row))),
        ],
      );

  Widget _purchaseOrderView() => _statusTableView(
        section: _InventorySection.purchaseOrders,
        rows: _purchaseOrders,
        columns: const ['purchase_order_no', 'order_date', 'expected_delivery_date', 'status', 'supplier_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        dateKeys: const ['order_date', 'created_at', 'createdAt'],
        actions: [
          _rowAction('Send', (row) => _service.updatePurchaseOrderStatus(_id(row), 'SENT')),
          _rowAction('Receive', (row) => _receivePurchaseOrder(row)),
          _rowAction('Cancel', (row) => _service.updatePurchaseOrderStatus(_id(row), 'CANCELLED')),
        ],
      );

  Widget _salesOrderView() => _statusTableView(
        section: _InventorySection.salesOrders,
        rows: _salesOrders,
        columns: const ['sales_order_no', 'order_date', 'requested_delivery_date', 'status', 'customer_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        dateKeys: const ['order_date', 'created_at', 'createdAt'],
        actions: [
          _rowAction('Reserve', (row) => _service.reserveSalesOrder(_id(row))),
          _rowAction('Issue', (row) => _issueSalesOrder(row)),
          _rowAction('Cancel', (row) => _service.updateSalesOrderStatus(_id(row), 'CANCELLED')),
        ],
      );

  Widget _statusTableView({
    required _InventorySection section,
    required List<Map<String, dynamic>> rows,
    required List<String> columns,
    required List<String> dateKeys,
    List<_RowAction>? actions,
  }) {
    if (rows.isEmpty) return const Center(child: Text('No records found'));

    final statuses = rows
        .map((row) => _text(row['status']).trim().toUpperCase())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final selected = statuses.contains(_statusFilters[section])
        ? _statusFilters[section]!
        : 'ALL';
    final filtered = _sortLatest(
      selected == 'ALL'
          ? rows
          : rows.where((row) => _text(row['status']).trim().toUpperCase() == selected).toList(),
      dateKeys,
    );

    final invoiceStyled = _isCommercialDocumentSection(section);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statuses.isNotEmpty)
          Container(
            height: 50,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: ['ALL', ...statuses].map((status) {
                final isSelected = selected == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      status == 'ALL' ? 'ALL' : status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _statusFilters[section] = status),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: BorderSide.none,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: invoiceStyled
              ? _commercialDocumentListView(
                  section: section,
                  rows: filtered,
                  actions: actions ?? const <_RowAction>[],
                )
              : actions == null
                  ? _tableView(filtered, columns)
                  : _actionTableView(
                      rows: filtered,
                      columns: columns,
                      actions: actions,
                    ),
        ),
      ],
    );
  }

  Widget _commercialDocumentListView({
    required _InventorySection section,
    required List<Map<String, dynamic>> rows,
    required List<_RowAction> actions,
  }) {
    if (rows.isEmpty) {
      return const Center(child: Text('No records found'));
    }

    final config = _CommercialDocumentListConfig.forSection(section);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(config.icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                config.overviewTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Text(
                  '${config.partnerLabel.toUpperCase()} / REFERENCE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DATE / DELIVERY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 100),
              const SizedBox(
                width: 112,
                child: Text(
                  'AMOUNT / STATUS',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return _commercialDocumentCard(
                row: row,
                config: config,
                actions: actions,
                colorScheme: colorScheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _commercialDocumentCard({
    required Map<String, dynamic> row,
    required _CommercialDocumentListConfig config,
    required List<_RowAction> actions,
    required ColorScheme colorScheme,
  }) {
    final partnerName = _text(row[config.partnerKey]).trim();
    final reference = _text(row[config.referenceKey]).trim();
    final status = _text(row['status']).trim();
    final amount = _formatDocumentAmount(row['total_amount']);
    final documentDate = _formatDocumentDate(row[config.dateKey]);
    final secondaryDate = _formatDocumentDate(row[config.secondaryDateKey]);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(config.icon, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerName.isEmpty ? config.partnerLabel : partnerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${reference.isEmpty ? '-' : reference}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 142,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _documentDateLine(
                        Icons.calendar_today_outlined,
                        documentDate,
                      ),
                      if (secondaryDate.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _documentDateLine(
                          Icons.event_available_outlined,
                          secondaryDate,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _documentStatusChip(status),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const Divider(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map(
                        (action) => OutlinedButton(
                          onPressed: () => _runRowAction(action, row),
                          child: Text(action.label),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _documentDateLine(IconData icon, String value) => Row(
        children: [
          Icon(icon, size: 11, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      );

  Widget _documentStatusChip(String status) {
    final normalized = status.toUpperCase();
    final Color color;
    switch (normalized) {
      case 'ACCEPTED':
      case 'COMPLETED':
      case 'RECEIVED':
      case 'ISSUED':
        color = Colors.green;
        break;
      case 'CANCELLED':
      case 'REJECTED':
        color = Colors.red;
        break;
      case 'SENT':
      case 'OPEN':
      case 'CONFIRMED':
        color = Colors.blue;
        break;
      case 'DRAFT':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        normalized.isEmpty ? '-' : normalized,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDocumentAmount(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '') ?? '');
    return parsed == null ? 'R 0.00' : 'R ${parsed.toStringAsFixed(2)}';
  }

  String _formatDocumentDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return _text(value);
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  List<Map<String, dynamic>> _sortLatest(
    List<Map<String, dynamic>> rows,
    List<String> dateKeys,
  ) {
    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) {
      final dateCompare = _dateRank(b, dateKeys).compareTo(_dateRank(a, dateKeys));
      if (dateCompare != 0) return dateCompare;
      final aRef = _text(a['id'] ?? a['number'] ?? a['code']);
      final bRef = _text(b['id'] ?? b['number'] ?? b['code']);
      return bRef.compareTo(aRef);
    });
    return sorted;
  }

  int _dateRank(Map<String, dynamic> row, List<String> keys) {
    for (final key in [...dateKeysFallback, ...keys]) {
      final value = row[key];
      if (value == null) continue;
      if (value is num) {
        final raw = value.toInt();
        return raw < 100000000000 ? raw * 1000 : raw;
      }
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return 0;
  }

  static const List<String> dateKeysFallback = <String>[
    'created_at',
    'createdAt',
    'updated_at',
    'updatedAt',
  ];

  Widget _metric(String title, dynamic value, IconData icon) => SizedBox(
        width: 180,
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_text(value), style: Theme.of(context).textTheme.headlineSmall),
        ]))),
      );

  Widget _section(String title, Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ])),
      );

  Widget _simpleList(List<Map<String, dynamic>> rows, List<String> columns) {
    if (rows.isEmpty) return const Text('No records found');
    return Column(children: rows.take(8).map((row) => ListTile(
      dense: true,
      title: Text(columns.take(2).map((c) => _text(row[c])).where((v) => v.isNotEmpty).join(' • ')),
      subtitle: Text(columns.skip(2).map((c) => '${_label(c)}: ${_text(row[c])}').join('   ')),
    )).toList());
  }

  Widget _tableView(List<Map<String, dynamic>> rows, List<String> columns) {
    if (rows.isEmpty) return const Center(child: Text('No records found'));
    return Scrollbar(child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(child: DataTable(
        columns: columns.map((c) => DataColumn(label: Text(_label(c)))).toList(),
        rows: rows.map((row) => DataRow(cells: columns.map((c) => DataCell(Text(_text(row[c])))).toList())).toList(),
      )),
    ));
  }

  Widget _actionTableView({required List<Map<String, dynamic>> rows, required List<String> columns, required List<_RowAction> actions}) {
    if (rows.isEmpty) return const Center(child: Text('No records found'));
    return Scrollbar(child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(child: DataTable(
        columns: [
          ...columns.map((c) => DataColumn(label: Text(_label(c)))),
          const DataColumn(label: Text('Actions')),
        ],
        rows: rows.map((row) => DataRow(cells: [
          ...columns.map((c) => DataCell(Text(_text(row[c])))),
          DataCell(Wrap(spacing: 6, children: actions.map((a) => OutlinedButton(onPressed: () => _runRowAction(a, row), child: Text(a.label))).toList())),
        ])).toList(),
      )),
    ));
  }

  Future<void> _runRowAction(_RowAction action, Map<String, dynamic> row) async {
    try {
      await action.handler(row);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _openSetupDialog() async {
    final warehouseCode = TextEditingController();
    final warehouseName = TextEditingController();
    final locationCode = TextEditingController(text: 'RECEIVING');
    final locationName = TextEditingController(text: 'Receiving Area');
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Create Warehouse / Receiving Location'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: warehouseCode, decoration: const InputDecoration(labelText: 'Warehouse code')),
        TextField(controller: warehouseName, decoration: const InputDecoration(labelText: 'Warehouse name')),
        TextField(controller: locationCode, decoration: const InputDecoration(labelText: 'Location code')),
        TextField(controller: locationName, decoration: const InputDecoration(labelText: 'Location name')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final wh = await _service.createWarehouse(warehouseCode: warehouseCode.text, name: warehouseName.text);
          await _service.createStorageLocation(warehouseId: wh['id'].toString(), locationCode: locationCode.text, name: locationName.text, locationType: 'RECEIVING');
          if (mounted) Navigator.pop(context);
          await _load();
        }, child: const Text('Save')),
      ],
    ));
  }

  Future<void> _openQuotationDialog() async {
    final saved = await showInventoryDocumentDialog(
      context: context,
      service: _service,
      type: InventoryDocumentType.quotation,
      warehouses: _warehouses,
      storageLocations: _locations,
    );
    if (saved == true) await _load();
  }

  Future<void> _openPurchaseOrderDialog() async {
    final saved = await showInventoryDocumentDialog(
      context: context,
      service: _service,
      type: InventoryDocumentType.purchaseOrder,
      warehouses: _warehouses,
      storageLocations: _locations,
    );
    if (saved == true) await _load();
  }

  Future<void> _openGoodsReceiptDialog() async {
    final saved = await showInventoryDocumentDialog(
      context: context,
      service: _service,
      type: InventoryDocumentType.goodsReceipt,
      warehouses: _warehouses,
      storageLocations: _locations,
    );
    if (saved == true) await _load();
  }

  Future<void> _openPutawayDialog() => _lineDialog(
    title: 'Create Putaway',
    actionLabel: 'Move',
    fields: const ['goodsReceiptId', 'warehouseId', 'fromLocationId', 'toLocationId', 'productId', 'quantity', 'uom', 'batchNo'],
    onSave: (values) => _service.createPutaway(
      goodsReceiptId: values['goodsReceiptId'],
      warehouseId: values['warehouseId']!,
      fromLocationId: values['fromLocationId']!,
      toLocationId: values['toLocationId']!,
      lines: [_line(values, includeBatch: true)],
    ),
  );

  Future<void> _openSalesOrderDialog() async {
    final saved = await showInventoryDocumentDialog(
      context: context,
      service: _service,
      type: InventoryDocumentType.salesOrder,
      warehouses: _warehouses,
      storageLocations: _locations,
    );
    if (saved == true) await _load();
  }

  Future<void> _receivePurchaseOrder(Map<String, dynamic> row) async {
    try {
      final po = await _service.purchaseOrder(_id(row));
      if (!mounted) return;
      final saved = await showInventoryDocumentDialog(
        context: context,
        service: _service,
        type: InventoryDocumentType.goodsReceipt,
        warehouses: _warehouses,
        storageLocations: _locations,
        sourceDocument: po,
      );
      if (saved == true) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _issueSalesOrder(Map<String, dynamic> row) async {
    final warehouse = TextEditingController(text: _text(row['warehouse_id']));
    final location = TextEditingController();
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text('Issue ${_text(row['sales_order_no'])}'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: warehouse, decoration: const InputDecoration(labelText: 'Warehouse ID')),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'Storage location ID (optional)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          await _service.issueSalesOrder(_id(row), warehouseId: warehouse.text, storageLocationId: location.text);
          if (mounted) Navigator.pop(context);
          await _load();
        }, child: const Text('Issue')),
      ],
    ));
  }

  Future<void> _lineDialog({required String title, required String actionLabel, required List<String> fields, required Future<dynamic> Function(Map<String, String>) onSave}) async {
    final controllers = {for (final f in fields) f: TextEditingController(text: f == 'uom' ? 'EA' : '')};
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields.map((f) => TextField(controller: controllers[f], decoration: InputDecoration(labelText: _label(f)))).toList()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          try {
            await onSave({for (final entry in controllers.entries) entry.key: entry.value.text});
            if (mounted) Navigator.pop(context);
            await _load();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
          }
        }, child: Text(actionLabel)),
      ],
    ));
  }

  Map<String, dynamic> _line(Map<String, String> values, {bool includePrice = false, bool includeCost = false, bool includeBatch = false}) {
    return {
      if (_has(values['productId'])) 'productId': values['productId'],
      if (_has(values['productCode'])) 'productCode': values['productCode'],
      'quantity': values['quantity'],
      'uom': _has(values['uom']) ? values['uom'] : 'EA',
      if (includePrice) 'unitPrice': _has(values['unitPrice']) ? values['unitPrice'] : '0',
      if (includePrice) 'taxRate': _has(values['taxRate']) ? values['taxRate'] : '0',
      if (includeCost) 'unitCost': _has(values['unitCost']) ? values['unitCost'] : '0',
      if (includeBatch && _has(values['batchNo'])) 'batchNo': values['batchNo'],
    };
  }

  String _cardMetric(_InventorySection section) {
    switch (section) {
      case _InventorySection.dashboard:
        return '${_text(_dashboard['productCount'])} products';
      case _InventorySection.quotations:
        return '${_text(_dashboard['openQuotations'] ?? _quotations.length)} open';
      case _InventorySection.purchaseOrders:
        return '${_text(_dashboard['openPurchaseOrders'] ?? _purchaseOrders.length)} open';
      case _InventorySection.stock:
        return '${_stock.length} balances';
      case _InventorySection.goodsReceipts:
        return '${_receipts.length} receipts';
      case _InventorySection.putaways:
        return '${_text(_dashboard['pendingPutaways'] ?? _putaways.length)} pending';
      case _InventorySection.movements:
        return '${_movements.length} recent';
      case _InventorySection.salesOrders:
        return '${_text(_dashboard['openSalesOrders'] ?? _salesOrders.length)} open';
      case _InventorySection.audit:
        return '${_audit.length} events';
      case _InventorySection.setup:
        return '${_warehouses.length} warehouses';
    }
  }

  _InventoryCardDefinition? _cardForSection(_InventorySection? section) {
    if (section == null) return null;
    for (final card in _visibleCards) {
      if (card.section == section) return card;
    }
    return null;
  }

  _RowAction _rowAction(String label, Future<dynamic> Function(Map<String, dynamic>) handler) => _RowAction(label, handler);
  List<Map<String, dynamic>> _asList(dynamic value) => value is List ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  bool _has(String? value) => value != null && value.trim().isNotEmpty;
  String _id(Map<String, dynamic> row) => _text(row['id']);
  String _text(dynamic value) => value == null ? '' : value.toString();
  String _label(String value) => value.replaceAll('_', ' ').replaceAll('-', ' ').replaceAllMapped(RegExp(r'(^|\s)([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
  String _normalize(String value) => value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
}

class _RowAction {
  final String label;
  final Future<dynamic> Function(Map<String, dynamic>) handler;
  _RowAction(this.label, this.handler);
}

enum _InventorySection {
  dashboard,
  quotations,
  purchaseOrders,
  stock,
  goodsReceipts,
  putaways,
  movements,
  salesOrders,
  audit,
  setup,
}

bool _isCommercialDocumentSection(_InventorySection section) =>
    section == _InventorySection.quotations ||
    section == _InventorySection.purchaseOrders ||
    section == _InventorySection.salesOrders;

class _CommercialDocumentListConfig {
  final String overviewTitle;
  final String partnerLabel;
  final String partnerKey;
  final String referenceKey;
  final String dateKey;
  final String secondaryDateKey;
  final IconData icon;

  const _CommercialDocumentListConfig({
    required this.overviewTitle,
    required this.partnerLabel,
    required this.partnerKey,
    required this.referenceKey,
    required this.dateKey,
    required this.secondaryDateKey,
    required this.icon,
  });

  factory _CommercialDocumentListConfig.forSection(_InventorySection section) {
    switch (section) {
      case _InventorySection.quotations:
        return const _CommercialDocumentListConfig(
          overviewTitle: 'Quotation Overview',
          partnerLabel: 'Customer',
          partnerKey: 'customer_name',
          referenceKey: 'quotation_no',
          dateKey: 'quotation_date',
          secondaryDateKey: 'valid_until',
          icon: Icons.request_quote_outlined,
        );
      case _InventorySection.purchaseOrders:
        return const _CommercialDocumentListConfig(
          overviewTitle: 'Purchase Order Overview',
          partnerLabel: 'Supplier',
          partnerKey: 'supplier_name',
          referenceKey: 'purchase_order_no',
          dateKey: 'order_date',
          secondaryDateKey: 'expected_delivery_date',
          icon: Icons.assignment_outlined,
        );
      case _InventorySection.salesOrders:
        return const _CommercialDocumentListConfig(
          overviewTitle: 'Sales Order Overview',
          partnerLabel: 'Customer',
          partnerKey: 'customer_name',
          referenceKey: 'sales_order_no',
          dateKey: 'order_date',
          secondaryDateKey: 'requested_delivery_date',
          icon: Icons.shopping_cart_outlined,
        );
      default:
        throw ArgumentError('Section is not a commercial document list: $section');
    }
  }
}

class _InventoryCardDefinition {
  final _InventorySection section;
  final String title;
  final String subtitle;
  final IconData icon;
  final int defaultOrder;
  final List<String> workcenterAliases;
  final List<String> sectionAliases;

  const _InventoryCardDefinition({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.defaultOrder,
    required this.workcenterAliases,
    required this.sectionAliases,
  });

  bool isAllowedBy(Set<String> allowedWorkcenters) {
    final aliases = workcenterAliases.map(_normalizeStatic).toSet();
    if (aliases.any(allowedWorkcenters.contains)) return true;

    return allowedWorkcenters.any(
      (configured) => aliases.any(
        (alias) => alias.length >= 5 && configured.contains(alias),
      ),
    );
  }

  bool matchesSection(String normalizedSection) => sectionAliases.map(_normalizeStatic).contains(normalizedSection) || _normalizeStatic(title) == normalizedSection;

  int positionFrom(Map<String, int> positionsById) {
    final positions = workcenterAliases.map(_normalizeStatic).map((alias) => positionsById[alias]).whereType<int>().toList();
    if (positions.isEmpty) return 100000 + defaultOrder;
    positions.sort();
    return positions.first;
  }

  static String _normalizeStatic(String value) => value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
}

const List<_InventoryCardDefinition> _inventoryCardCatalog = [
  _InventoryCardDefinition(
    section: _InventorySection.dashboard,
    title: 'Inventory Dashboard',
    subtitle: 'Stock visibility, receiving, putaway and recent movement summary.',
    icon: Icons.dashboard_outlined,
    defaultOrder: 10,
    workcenterAliases: ['inventory', 'inventory-management', 'stock-management'],
    sectionAliases: ['dashboard', 'overview', 'inventory'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.quotations,
    title: 'Quotations',
    subtitle: 'Create and manage customer quotations with multiple items, VAT and totals.',
    icon: Icons.request_quote_outlined,
    defaultOrder: 20,
    workcenterAliases: ['quotation', 'quotations', 'quote', 'quotes'],
    sectionAliases: ['quotation', 'quotations', 'quote', 'quotes'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.purchaseOrders,
    title: 'Purchase Orders',
    subtitle: 'Create supplier purchase orders and receive ordered items.',
    icon: Icons.assignment_outlined,
    defaultOrder: 30,
    workcenterAliases: ['purchase-order', 'purchase-orders', 'purchase_order', 'purchase_orders'],
    sectionAliases: ['purchase-order', 'purchase-orders', 'purchase_order', 'purchase_orders', 'po'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.stock,
    title: 'Stock on Hand',
    subtitle: 'View stock balances by product, warehouse, storage location and batch.',
    icon: Icons.inventory_2_outlined,
    defaultOrder: 40,
    workcenterAliases: ['stock', 'stock-on-hand', 'stock_on_hand'],
    sectionAliases: ['stock', 'stock-on-hand', 'stock_on_hand', 'balances'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.goodsReceipts,
    title: 'Goods Receipts',
    subtitle: 'Capture direct or PO-based receiving documents.',
    icon: Icons.call_received_outlined,
    defaultOrder: 50,
    workcenterAliases: ['goods-receipt', 'goods-receipts', 'goods_receipt', 'goods_receipts'],
    sectionAliases: ['goods-receipt', 'goods-receipts', 'goods_receipt', 'goods_receipts', 'receipts'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.putaways,
    title: 'Putaways',
    subtitle: 'Move received stock from receiving areas into final storage locations.',
    icon: Icons.compare_arrows_outlined,
    defaultOrder: 60,
    workcenterAliases: ['putaway', 'putaways'],
    sectionAliases: ['putaway', 'putaways'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.movements,
    title: 'Stock Movements',
    subtitle: 'Trace stock receipts, putaways, reservations and issues.',
    icon: Icons.timeline_outlined,
    defaultOrder: 70,
    workcenterAliases: ['stock-movement', 'stock-movements', 'inventory-movement', 'inventory-movements'],
    sectionAliases: ['stock-movement', 'stock-movements', 'movement', 'movements'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.salesOrders,
    title: 'Sales Orders',
    subtitle: 'Create customer sales orders, reserve stock and issue stock.',
    icon: Icons.shopping_cart_outlined,
    defaultOrder: 80,
    workcenterAliases: ['sales-order', 'sales-orders', 'sales_order', 'sales_orders'],
    sectionAliases: ['sales-order', 'sales-orders', 'sales_order', 'sales_orders', 'so'],
  ),
  _InventoryCardDefinition(
    section: _InventorySection.audit,
    title: 'Inventory Audit',
    subtitle: 'Review inventory document and stock process audit history.',
    icon: Icons.history_outlined,
    defaultOrder: 90,
    workcenterAliases: ['inventory-audit', 'stock-audit', 'stock-audit-log'],
    sectionAliases: ['audit', 'inventory-audit', 'stock-audit'],
  ),
];
