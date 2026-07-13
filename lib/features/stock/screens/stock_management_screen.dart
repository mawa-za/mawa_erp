import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../home/models/workcenter.dart';
import '../services/stock_service.dart';
import '../widgets/inventory_document_dialog.dart';

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
      final results = await Future.wait<dynamic>([
        _service.dashboard(),
        _service.quotations(),
        _service.purchaseOrders(),
        _service.stock(),
        _service.warehouses(),
        _service.storageLocations(),
        _service.goodsReceipts(),
        _service.putaways(),
        _service.movements(),
        _service.salesOrders(),
        _service.audit(),
        _loadVisibleCards(),
      ]);
      if (!mounted) return;
      final cards = List<_InventoryCardDefinition>.from(results[11] as List);
      setState(() {
        _dashboard = Map<String, dynamic>.from(results[0] as Map);
        _quotations = List<Map<String, dynamic>>.from(results[1] as List);
        _purchaseOrders = List<Map<String, dynamic>>.from(results[2] as List);
        _stock = List<Map<String, dynamic>>.from(results[3] as List);
        _warehouses = List<Map<String, dynamic>>.from(results[4] as List);
        _locations = List<Map<String, dynamic>>.from(results[5] as List);
        _receipts = List<Map<String, dynamic>>.from(results[6] as List);
        _putaways = List<Map<String, dynamic>>.from(results[7] as List);
        _movements = List<Map<String, dynamic>>.from(results[8] as List);
        _salesOrders = List<Map<String, dynamic>>.from(results[9] as List);
        _audit = List<Map<String, dynamic>>.from(results[10] as List);
        _visibleCards = cards;
        if (_selectedSection != null && !_visibleCards.any((card) => card.section == _selectedSection)) {
          _selectedSection = null;
        }
        _applyInitialSectionIfNeeded();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
      throw Exception('Failed to load role workcenters: ${response.statusCode} ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    final workcenters = data.map((json) => Workcenter.fromJson(json)).toList();
    final Map<String, int> positionsById = {
      for (final wc in workcenters) _normalize(wc.id): wc.position,
    };
    final Set<String> allowed = positionsById.keys.toSet();

    final cards = _inventoryCardCatalog.where((card) => card.isAllowedBy(allowed)).toList();
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
    final selectedTitle = _cardForSection(_selectedSection)?.title ?? 'Inventory Management';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
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
            Text('No Inventory Management cards are enabled for your current role.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Ask an administrator to add Inventory workcenters to your role configuration.', textAlign: TextAlign.center),
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
            Text('Inventory Management', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Choose a process card. Available cards are controlled by the selected role workcenter configuration.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('Stock Qty', _dashboard['totalStockQuantity'], Icons.inventory_2_outlined),
              _metric('Open Quotes', _dashboard['openQuotations'], Icons.request_quote_outlined),
              _metric('Open POs', _dashboard['openPurchaseOrders'], Icons.assignment_outlined),
              _metric('Pending Putaway', _dashboard['pendingPutaways'], Icons.compare_arrows_outlined),
              _metric('Open Orders', _dashboard['openSalesOrders'], Icons.shopping_cart_outlined),
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
        onTap: () => setState(() => _selectedSection = card.section),
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
        return _tableView(_receipts, const ['receipt_no', 'purchase_order_no', 'receipt_date', 'status', 'supplier_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount']);
      case _InventorySection.putaways:
        return _tableView(_putaways, const ['putaway_no', 'movement_date', 'status', 'warehouse_id', 'from_location_id', 'to_location_id']);
      case _InventorySection.movements:
        return _tableView(_movements, const ['movement_no', 'movement_type', 'product_code', 'quantity', 'uom', 'reference_no', 'processed_by', 'movement_at']);
      case _InventorySection.salesOrders:
        return _salesOrderView();
      case _InventorySection.audit:
        return _tableView(_audit, const ['entity_type', 'action', 'entity_id', 'notes', 'created_by', 'created_at']);
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
          _metric('Open Quotes', _dashboard['openQuotations'], Icons.request_quote_outlined),
          _metric('Open POs', _dashboard['openPurchaseOrders'], Icons.assignment_outlined),
          _metric('Pending Putaway', _dashboard['pendingPutaways'], Icons.compare_arrows_outlined),
          _metric('Receipts Today', _dashboard['goodsReceiptsToday'], Icons.call_received_outlined),
          _metric('Open Orders', _dashboard['openSalesOrders'], Icons.shopping_cart_outlined),
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

  Widget _quotationView() => _actionTableView(
        rows: _quotations,
        columns: const ['quotation_no', 'quotation_date', 'valid_until', 'status', 'customer_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        actions: [
          _rowAction('Send', (row) => _service.updateQuotationStatus(_id(row), 'SENT')),
          _rowAction('Accept', (row) => _service.updateQuotationStatus(_id(row), 'ACCEPTED')),
          _rowAction('Convert', (row) => _service.convertQuotationToSalesOrder(_id(row))),
        ],
      );

  Widget _purchaseOrderView() => _actionTableView(
        rows: _purchaseOrders,
        columns: const ['purchase_order_no', 'order_date', 'expected_delivery_date', 'status', 'supplier_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        actions: [
          _rowAction('Send', (row) => _service.updatePurchaseOrderStatus(_id(row), 'SENT')),
          _rowAction('Receive', (row) => _receivePurchaseOrder(row)),
          _rowAction('Cancel', (row) => _service.updatePurchaseOrderStatus(_id(row), 'CANCELLED')),
        ],
      );

  Widget _salesOrderView() => _actionTableView(
        rows: _salesOrders,
        columns: const ['sales_order_no', 'order_date', 'requested_delivery_date', 'status', 'customer_name', 'line_count', 'subtotal_amount', 'tax_amount', 'total_amount'],
        actions: [
          _rowAction('Reserve', (row) => _service.reserveSalesOrder(_id(row))),
          _rowAction('Issue', (row) => _issueSalesOrder(row)),
          _rowAction('Cancel', (row) => _service.updateSalesOrderStatus(_id(row), 'CANCELLED')),
        ],
      );

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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

  bool isAllowedBy(Set<String> allowedWorkcenters) => workcenterAliases.map(_normalizeStatic).any(allowedWorkcenters.contains);

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
    subtitle: 'Stock visibility, low stock, open documents and recent movement summary.',
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
  _InventoryCardDefinition(
    section: _InventorySection.setup,
    title: 'Inventory Setup',
    subtitle: 'Maintain warehouses and storage locations.',
    icon: Icons.store_mall_directory_outlined,
    defaultOrder: 100,
    workcenterAliases: ['inventory-setup', 'warehouse-setup', 'warehouse', 'storage-location'],
    sectionAliases: ['setup', 'inventory-setup', 'warehouse-setup'],
  ),
];
