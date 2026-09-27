import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});
  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  final StockService _service = StockService();
  Map<String, dynamic> _dashboard = const {};
  Map<String, dynamic> _health = const {};
  List<Map<String, dynamic>> _expiry = const [];
  List<Map<String, dynamic>> _replenishment = const [];
  List<Map<String, dynamic>> _purchase = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        _service.dashboard(),
        _service.inventoryHealth(),
        _service.inventoryExpiryAlerts(),
        _service.inventoryReplenishmentRecommendations(),
        _service.inventoryPurchaseRecommendations(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = Map<String, dynamic>.from(results[0] as Map);
        _health = Map<String, dynamic>.from(results[1] as Map);
        _expiry = List<Map<String, dynamic>>.from(results[2] as List);
        _replenishment = List<Map<String, dynamic>>.from(results[3] as List);
        _purchase = List<Map<String, dynamic>>.from(results[4] as List);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _listCount(String key) => (_health[key] is List) ? (_health[key] as List).length : 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventory Dashboard')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
          else ...[
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('On hand', '${_dashboard['totalStockQuantity'] ?? 0}', Icons.inventory_2_outlined),
              _metric('Products in stock', '${_dashboard['productCount'] ?? 0}', Icons.category_outlined),
              _metric('Low stock', '${_dashboard['lowStockCount'] ?? 0}', Icons.warning_amber_outlined),
              _metric('Pending putaway', '${_dashboard['pendingPutaways'] ?? 0}', Icons.move_to_inbox_outlined),
              _metric('Expiry alerts', '${_expiry.length}', Icons.event_busy_outlined),
              _metric('Replenishment', '${_replenishment.length}', Icons.sync_alt_outlined),
              _metric('Purchase suggestions', '${_purchase.length}', Icons.shopping_cart_outlined),
              _metric('Health exceptions', '${_listCount('negativeStock') + _listCount('reservationMismatch') + _listCount('expiredUnrestricted') + _listCount('staleTransfers')}', Icons.health_and_safety_outlined),
            ]),
            const SizedBox(height: 20),
            _section('Stock by warehouse', (_dashboard['stockByWarehouse'] as List? ?? const []).map((e) {
              final row = Map<String, dynamic>.from(e as Map);
              return ListTile(title: Text('${row['warehouse_code'] ?? ''} - ${row['name'] ?? ''}'), trailing: Text('${row['on_hand_qty'] ?? 0}'));
            }).toList()),
            _section('Inventory health', [
              ListTile(title: const Text('Negative stock'), trailing: Text('${_listCount('negativeStock')}')),
              ListTile(title: const Text('Reservation mismatches'), trailing: Text('${_listCount('reservationMismatch')}')),
              ListTile(title: const Text('Expired unrestricted stock'), trailing: Text('${_listCount('expiredUnrestricted')}')),
              ListTile(title: const Text('Stale transfers'), trailing: Text('${_listCount('staleTransfers')}')),
            ]),
            _section('Upcoming expiry', _expiry.take(10).map((row) => ListTile(
              title: Text('${row['product_code'] ?? row['product_id']} • ${row['batch_no'] ?? ''}'),
              subtitle: Text('${row['warehouse_code'] ?? ''} / ${row['location_code'] ?? ''}'),
              trailing: Text('${row['expiry_date'] ?? ''}'),
            )).toList()),
            _section('Replenishment recommendations', _replenishment.take(10).map((row) => ListTile(
              title: Text('${row['product_code'] ?? row['product_id']}'),
              subtitle: Text('${row['warehouse_code'] ?? ''}'),
              trailing: Text('${row['recommended_replenishment_qty'] ?? row['replenishment_qty'] ?? ''}'),
            )).toList()),
          ],
        ],
      ),
    ),
  );

  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 210,
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Icon(icon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: Theme.of(context).textTheme.headlineSmall)])),
    ]))),
  );

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      if (children.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No items.')) else ...children,
    ])),
  );
}
