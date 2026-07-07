import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> with SingleTickerProviderStateMixin {
  final StockService _service = StockService();
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _dashboard = <String, dynamic>{};
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _putaways = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _salesOrders = [];
  List<Map<String, dynamic>> _audit = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.dashboard(),
        _service.stock(),
        _service.goodsReceipts(),
        _service.putaways(),
        _service.movements(),
        _service.salesOrders(),
        _service.audit(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = Map<String, dynamic>.from(results[0] as Map);
        _stock = List<Map<String, dynamic>>.from(results[1] as List);
        _receipts = List<Map<String, dynamic>>.from(results[2] as List);
        _putaways = List<Map<String, dynamic>>.from(results[3] as List);
        _movements = List<Map<String, dynamic>>.from(results[4] as List);
        _salesOrders = List<Map<String, dynamic>>.from(results[5] as List);
        _audit = List<Map<String, dynamic>>.from(results[6] as List);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock'),
            Tab(icon: Icon(Icons.call_received_outlined), text: 'Goods Receipt'),
            Tab(icon: Icon(Icons.compare_arrows_outlined), text: 'Putaway'),
            Tab(icon: Icon(Icons.timeline_outlined), text: 'Movements'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Sales Orders'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Audit'),
          ],
        ),
      ),
      floatingActionButton: _buildActionButton(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(theme)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _dashboardView(theme),
                    _tableView(_stock, const ['product_code', 'product_description', 'warehouse_code', 'location_code', 'on_hand_qty', 'reserved_qty', 'available_qty', 'uom']),
                    _tableView(_receipts, const ['receipt_no', 'receipt_date', 'status', 'supplier_reference', 'warehouse_id', 'created_by']),
                    _tableView(_putaways, const ['putaway_no', 'movement_date', 'status', 'warehouse_id', 'from_location_id', 'to_location_id']),
                    _tableView(_movements, const ['movement_no', 'movement_type', 'product_code', 'quantity', 'uom', 'reference_no', 'processed_by', 'movement_at']),
                    _tableView(_salesOrders, const ['sales_order_no', 'order_date', 'status', 'customer_partner_id', 'warehouse_id', 'created_by']),
                    _tableView(_audit, const ['entity_type', 'action', 'entity_id', 'notes', 'created_by', 'created_at']),
                  ],
                ),
    );
  }

  Widget? _buildActionButton() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        if (_tabController.index == 2) {
          return FloatingActionButton.extended(onPressed: () => _openGoodsReceiptDialog(), icon: const Icon(Icons.add), label: const Text('Goods Receipt'));
        }
        if (_tabController.index == 3) {
          return FloatingActionButton.extended(onPressed: () => _openPutawayDialog(), icon: const Icon(Icons.add), label: const Text('Putaway'));
        }
        if (_tabController.index == 5) {
          return FloatingActionButton.extended(onPressed: () => _openSalesOrderDialog(), icon: const Icon(Icons.add), label: const Text('Sales Order'));
        }
        return FloatingActionButton.extended(onPressed: _openSetupDialog, icon: const Icon(Icons.store_mall_directory_outlined), label: const Text('Setup'));
      },
    );
  }

  Widget _errorView(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _dashboardView(ThemeData theme) {
    final stockByWarehouse = _asList(_dashboard['stockByWarehouse']);
    final lowStock = _asList(_dashboard['lowStock']);
    final recentMovements = _asList(_dashboard['recentMovements']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('Stock Qty', _dashboard['totalStockQuantity'], Icons.inventory_2_outlined),
              _metric('Products', _dashboard['productCount'], Icons.category_outlined),
              _metric('Low Stock', _dashboard['lowStockCount'], Icons.warning_amber_outlined),
              _metric('Receipts Today', _dashboard['goodsReceiptsToday'], Icons.call_received_outlined),
              _metric('Movements Today', _dashboard['stockMovementsToday'], Icons.timeline_outlined),
              _metric('Open Orders', _dashboard['openSalesOrders'], Icons.shopping_cart_outlined),
              _metric('Warehouses', _dashboard['activeWarehouses'], Icons.store_mall_directory_outlined),
            ],
          ),
          const SizedBox(height: 20),
          _section('Warehouse visibility', _simpleList(stockByWarehouse, ['warehouse_code', 'name', 'on_hand_qty'])),
          _section('Low stock visibility', _simpleList(lowStock, ['product_code', 'product_description', 'on_hand_qty', 'minimum_qty'])),
          _section('Recent stock movements', _simpleList(recentMovements, ['movement_no', 'movement_type', 'product_code', 'quantity'])),
        ],
      ),
    );
  }

  Widget _metric(String title, dynamic value, IconData icon) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_text(value), style: Theme.of(context).textTheme.headlineSmall),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _simpleList(List<Map<String, dynamic>> rows, List<String> columns) {
    if (rows.isEmpty) return const Text('No records found');
    return Column(
      children: rows.take(8).map((row) => ListTile(
            dense: true,
            title: Text(columns.take(2).map((c) => _text(row[c])).where((v) => v.isNotEmpty).join(' • ')),
            subtitle: Text(columns.skip(2).map((c) => '${_label(c)}: ${_text(row[c])}').join('   ')),
          )).toList(),
    );
  }

  Widget _tableView(List<Map<String, dynamic>> rows, List<String> columns) {
    if (rows.isEmpty) return const Center(child: Text('No records found'));
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: columns.map((c) => DataColumn(label: Text(_label(c)))).toList(),
            rows: rows.map((row) => DataRow(cells: columns.map((c) => DataCell(Text(_text(row[c])))).toList())).toList(),
          ),
        ),
      ),
    );
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

  Future<void> _openGoodsReceiptDialog() => _lineDialog(
    title: 'Create Goods Receipt',
    actionLabel: 'Receive',
    fields: const ['warehouseId', 'storageLocationId', 'productId', 'quantity', 'uom', 'supplierReference'],
    onSave: (values) => _service.createGoodsReceipt(
      warehouseId: values['warehouseId']!,
      storageLocationId: values['storageLocationId']!,
      supplierReference: values['supplierReference'],
      lines: [{'productId': values['productId'], 'quantity': values['quantity'], 'uom': values['uom'] ?? 'EA'}],
    ),
  );

  Future<void> _openPutawayDialog() => _lineDialog(
    title: 'Create Putaway',
    actionLabel: 'Move',
    fields: const ['warehouseId', 'fromLocationId', 'toLocationId', 'productId', 'quantity', 'uom'],
    onSave: (values) => _service.createPutaway(
      warehouseId: values['warehouseId']!,
      fromLocationId: values['fromLocationId']!,
      toLocationId: values['toLocationId']!,
      lines: [{'productId': values['productId'], 'quantity': values['quantity'], 'uom': values['uom'] ?? 'EA'}],
    ),
  );

  Future<void> _openSalesOrderDialog() => _lineDialog(
    title: 'Create Sales Order',
    actionLabel: 'Create',
    fields: const ['customerPartnerId', 'warehouseId', 'productId', 'quantity', 'uom'],
    onSave: (values) => _service.createSalesOrder(
      customerPartnerId: values['customerPartnerId'],
      warehouseId: values['warehouseId'],
      lines: [{'productId': values['productId'], 'quantity': values['quantity'], 'uom': values['uom'] ?? 'EA'}],
    ),
  );

  Future<void> _lineDialog({required String title, required String actionLabel, required List<String> fields, required Future<dynamic> Function(Map<String, String>) onSave}) async {
    final controllers = {for (final f in fields) f: TextEditingController(text: f == 'uom' ? 'EA' : '')};
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields.map((f) => TextField(controller: controllers[f], decoration: InputDecoration(labelText: _label(f)))).toList()))),
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

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return <Map<String, dynamic>>[];
  }

  String _text(dynamic value) => value == null ? '' : value.toString();
  String _label(String value) => value.replaceAll('_', ' ').replaceAllMapped(RegExp(r'(^|\s)([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
}
