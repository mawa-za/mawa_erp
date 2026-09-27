import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventorySetupScreen extends StatefulWidget {
  const InventorySetupScreen({super.key});
  @override
  State<InventorySetupScreen> createState() => _InventorySetupScreenState();
}

class _InventorySetupScreenState extends State<InventorySetupScreen> with SingleTickerProviderStateMixin {
  final StockService _service = StockService();
  late final TabController _tabs;
  List<Map<String, dynamic>> _reasons = const [];
  List<Map<String, dynamic>> _policies = const [];
  List<Map<String, dynamic>> _warehouses = const [];
  List<Map<String, dynamic>> _products = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _service.inventoryReasonCodes(),
        _service.inventoryPolicies(),
        _service.inventoryReferenceWarehouses('inventory-setup'),
        _service.inventoryReferenceProducts('inventory-setup'),
      ]);
      if (!mounted) return;
      setState(() {
        _reasons = values[0]; _policies = values[1]; _warehouses = values[2]; _products = values[3];
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventory Configuration'), bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Reason codes'), Tab(text: 'Warehouse policies')])),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : TabBarView(controller: _tabs, children: [
      RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _editReason, icon: const Icon(Icons.add), label: const Text('Reason code'))),
        const SizedBox(height: 12),
        ..._reasons.map((r) => Card(child: ListTile(title: Text('${r['code']} - ${r['description']}'), subtitle: Text('${r['category']} • Approval: ${_yes(r['requires_approval'])} • Notes: ${_yes(r['requires_notes'])} • Attachment: ${_yes(r['requires_attachment'])}')))),
      ])),
      RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _editPolicy, icon: const Icon(Icons.add), label: const Text('Warehouse policy'))),
        const SizedBox(height: 12),
        ..._policies.map((r) => Card(child: ListTile(title: Text('${r['product_code']} • ${r['warehouse_code']}'), subtitle: Text('Min ${r['minimum_qty']} • Max ${r['maximum_qty']} • Reorder at ${r['reorder_point']} • Reorder qty ${r['reorder_qty']} • Safety ${r['safety_stock_qty']}')))),
      ])),
    ]),
  );

  String _yes(dynamic value) => (value == true || value == 1 || '$value' == '1') ? 'Yes' : 'No';

  Future<void> _editReason() async {
    final code = TextEditingController(), description = TextEditingController();
    String category = 'OTHER'; bool approval = false, notes = true, attachment = false;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Inventory reason code'),
      content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: const ['OTHER','ADJUSTMENT','DAMAGE','EXPIRY','LOSS','RETURN','DISPOSAL','TRANSFER'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setLocal(() => category = v ?? category)),
        CheckboxListTile(value: notes, onChanged: (v) => setLocal(() => notes = v ?? false), title: const Text('Require notes')),
        CheckboxListTile(value: attachment, onChanged: (v) => setLocal(() => attachment = v ?? false), title: const Text('Require attachment')),
        CheckboxListTile(value: approval, onChanged: (v) => setLocal(() => approval = v ?? false), title: const Text('Require approval')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (ok == true && code.text.trim().isNotEmpty && description.text.trim().isNotEmpty) {
      await _service.saveInventoryReasonCode({'code': code.text.trim().toUpperCase(), 'description': description.text.trim(), 'category': category, 'requiresNotes': notes, 'requiresAttachment': attachment, 'requiresApproval': approval, 'active': true});
      await _load();
    }
    code.dispose(); description.dispose();
  }

  Future<void> _editPolicy() async {
    if (_products.isEmpty || _warehouses.isEmpty) return;
    String productId = '${_products.first['id']}', warehouseId = '${_warehouses.first['id']}';
    final minimum = TextEditingController(text: '0'), maximum = TextEditingController(text: '0'), reorderPoint = TextEditingController(text: '0'), reorderQty = TextEditingController(text: '0'), safety = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Product warehouse policy'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: productId, decoration: const InputDecoration(labelText: 'Product'), items: _products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text('${p['code']} - ${p['description']}'))).toList(), onChanged: (v) => setLocal(() => productId = v ?? productId)),
        DropdownButtonFormField<String>(value: warehouseId, decoration: const InputDecoration(labelText: 'Warehouse'), items: _warehouses.map((w) => DropdownMenuItem(value: '${w['id']}', child: Text('${w['warehouse_code']} - ${w['name']}'))).toList(), onChanged: (v) => setLocal(() => warehouseId = v ?? warehouseId)),
        TextField(controller: minimum, decoration: const InputDecoration(labelText: 'Minimum quantity'), keyboardType: TextInputType.number),
        TextField(controller: maximum, decoration: const InputDecoration(labelText: 'Maximum quantity'), keyboardType: TextInputType.number),
        TextField(controller: reorderPoint, decoration: const InputDecoration(labelText: 'Reorder point'), keyboardType: TextInputType.number),
        TextField(controller: reorderQty, decoration: const InputDecoration(labelText: 'Reorder quantity'), keyboardType: TextInputType.number),
        TextField(controller: safety, decoration: const InputDecoration(labelText: 'Safety stock'), keyboardType: TextInputType.number),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (ok == true) {
      double n(TextEditingController c) => double.tryParse(c.text) ?? 0;
      await _service.saveInventoryPolicy({'productId': productId, 'warehouseId': warehouseId, 'minimumQty': n(minimum), 'maximumQty': n(maximum), 'reorderPoint': n(reorderPoint), 'reorderQty': n(reorderQty), 'safetyStockQty': n(safety), 'leadTimeDays': 0, 'expiryWarningDays': 30, 'minimumShelfLifeDays': 0});
      await _load();
    }
    for (final c in [minimum, maximum, reorderPoint, reorderQty, safety]) { c.dispose(); }
  }
}
