import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryWarehouseTransferScreen extends StatefulWidget {
  const InventoryWarehouseTransferScreen({super.key});
  @override
  State<InventoryWarehouseTransferScreen> createState() => _InventoryWarehouseTransferScreenState();
}

class _InventoryWarehouseTransferScreenState extends State<InventoryWarehouseTransferScreen> {
  final StockService _service = StockService();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final rows = await _service.inventoryDocuments(type: 'WAREHOUSE_TRANSFER'); if (mounted) setState(() => _rows = rows); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Warehouse Transfers')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New Transfer')),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Controlled warehouse-to-warehouse transfers: approval → dispatch → in transit → destination receipt. Shortages and damages remain visible on the transfer.'),
      const SizedBox(height: 16),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
      else if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
      else if (_rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No warehouse transfers found.')))
      else ..._rows.map((r) => Card(child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text('${r['document_no']}'),
        subtitle: Text('${r['reference_no'] ?? ''}${r['notes'] == null ? '' : '\n${r['notes']}'}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Chip(label: Text('${r['status']}')), const SizedBox(width: 8), const Icon(Icons.chevron_right)]),
        onTap: () => _open('${r['id']}'),
      ))),
    ])),
  );

  Future<void> _create() async {
    final warehouses = await _service.inventoryReferenceWarehouses('warehouse-transfer');
    final products = await _service.inventoryReferenceProducts('warehouse-transfer');
    if (!mounted || warehouses.length < 2) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least two accessible warehouses are required.')));
      return;
    }
    String? sourceWarehouse = '${warehouses.first['id']}';
    String? destinationWarehouse = '${warehouses[1]['id']}';
    String? sourceLocation;
    String? destinationLocation;
    String? productId;
    List<Map<String, dynamic>> sourceLocations = await _service.inventoryReferenceLocations('warehouse-transfer', sourceWarehouse);
    List<Map<String, dynamic>> destinationLocations = await _service.inventoryReferenceLocations('warehouse-transfer', destinationWarehouse);
    final qty = TextEditingController(text: '1');
    final uom = TextEditingController(text: 'EA');
    final batch = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();

    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('New warehouse transfer'),
      content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: sourceWarehouse, decoration: const InputDecoration(labelText: 'Source warehouse'), items: warehouses.map((w) => DropdownMenuItem(value: '${w['id']}', child: Text('${w['warehouse_code']} - ${w['name']}'))).toList(), onChanged: (v) async { if (v == null) return; final locs = await _service.inventoryReferenceLocations('warehouse-transfer', v); setLocal(() { sourceWarehouse = v; sourceLocations = locs; sourceLocation = null; if (destinationWarehouse == v) destinationWarehouse = null; }); }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: destinationWarehouse, decoration: const InputDecoration(labelText: 'Destination warehouse'), items: warehouses.where((w) => '${w['id']}' != sourceWarehouse).map((w) => DropdownMenuItem(value: '${w['id']}', child: Text('${w['warehouse_code']} - ${w['name']}'))).toList(), onChanged: (v) async { if (v == null) return; final locs = await _service.inventoryReferenceLocations('warehouse-transfer', v); setLocal(() { destinationWarehouse = v; destinationLocations = locs; destinationLocation = null; }); }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: sourceLocation, decoration: const InputDecoration(labelText: 'Source location'), items: sourceLocations.map((l) => DropdownMenuItem(value: '${l['id']}', child: Text('${l['location_code']} - ${l['name']}'))).toList(), onChanged: (v) => setLocal(() => sourceLocation = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: destinationLocation, decoration: const InputDecoration(labelText: 'Destination location'), items: destinationLocations.map((l) => DropdownMenuItem(value: '${l['id']}', child: Text('${l['location_code']} - ${l['name']}'))).toList(), onChanged: (v) => setLocal(() => destinationLocation = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: productId, decoration: const InputDecoration(labelText: 'Product'), items: products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text('${p['code']} - ${p['description']}'))).toList(), onChanged: (v) => setLocal(() { productId = v; final p=products.firstWhere((e)=>'${e['id']}'==v,orElse:()=> <String,dynamic>{});uom.text='${p['uom'] ?? 'EA'}'; })),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))), const SizedBox(width: 12), SizedBox(width:110,child:TextField(controller:uom,decoration:const InputDecoration(labelText:'UOM'))), const SizedBox(width: 12), Expanded(child: TextField(controller: batch, decoration: const InputDecoration(labelText: 'Batch (optional)')))]),
        const SizedBox(height: 12), TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference (optional)')),
        const SizedBox(height: 12), TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: sourceWarehouse == null || destinationWarehouse == null || sourceLocation == null || destinationLocation == null || productId == null ? null : () => Navigator.pop(context, true), child: const Text('Create'))],
    )));
    if (ok != true) return;
    try {
      final created = await _service.createWarehouseTransfer({
        'warehouseId': sourceWarehouse, 'destinationWarehouseId': destinationWarehouse,
        if (reference.text.trim().isNotEmpty) 'referenceNo': reference.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'lines': [{'productId': productId, 'quantity': double.parse(qty.text), 'uom': uom.text.trim().toUpperCase(), 'sourceLocationId': sourceLocation, 'destinationLocationId': destinationLocation, 'sourceStockStatus': 'UNRESTRICTED', 'destinationStockStatus': 'UNRESTRICTED', if (batch.text.trim().isNotEmpty) 'batchNo': batch.text.trim()}],
      });
      await _load();
      if (mounted) await _open('${created['id']}');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { qty.dispose(); uom.dispose(); batch.dispose(); reference.dispose(); notes.dispose(); }
  }

  Future<void> _open(String id) async {
    try {
      final doc = await _service.inventoryDocument(id);
      if (!mounted) return;
      final status = '${doc['status']}';
      final lines = (doc['lines'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final action = await showDialog<String>(context: context, builder: (context) => AlertDialog(
        title: Text('${doc['document_no']} • $status'),
        content: SizedBox(width: 800, height: 430, child: ListView(children: [
          if (doc['reference_no'] != null) Text('Reference: ${doc['reference_no']}'),
          if (doc['notes'] != null) Text('Notes: ${doc['notes']}'),
          const SizedBox(height: 12),
          ...lines.map((l) => Card(child: ListTile(title: Text('${l['product_code'] ?? l['product_id']} - ${l['product_description'] ?? ''}'), subtitle: Text('Requested ${l['quantity']} ${l['uom']} • Dispatched ${l['dispatched_qty'] ?? 0} • Received ${l['received_qty'] ?? 0} • Damaged ${l['damaged_qty'] ?? 0} • Short ${l['shortage_qty'] ?? 0}')))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'close'), child: const Text('Close')),
          if (status == 'DRAFT') FilledButton(onPressed: () => Navigator.pop(context, 'submit'), child: const Text('Submit for approval')),
          if (status == 'APPROVED') FilledButton(onPressed: () => Navigator.pop(context, 'dispatch'), child: const Text('Dispatch')),
          if (status == 'IN_TRANSIT' || status == 'PARTIALLY_RECEIVED') FilledButton(onPressed: () => Navigator.pop(context, 'receive'), child: const Text('Receive')),
        ],
      ));
      if (action == 'submit') await _service.submitWarehouseTransfer(id);
      if (action == 'dispatch') await _service.dispatchWarehouseTransfer(id);
      if (action == 'receive') await _receive(doc, lines);
      if (action != null && action != 'close') await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _receive(Map<String, dynamic> doc, List<Map<String, dynamic>> lines) async {
    final ctrls = <String, TextEditingController>{};
    final damagedCtrls = <String, TextEditingController>{};
    for (final l in lines) {
      final outstanding = (num.tryParse('${l['dispatched_qty'] ?? 0}') ?? 0) - (num.tryParse('${l['received_qty'] ?? 0}') ?? 0) - (num.tryParse('${l['damaged_qty'] ?? 0}') ?? 0);
      ctrls['${l['id']}'] = TextEditingController(text: outstanding > 0 ? '$outstanding' : '0');
      damagedCtrls['${l['id']}'] = TextEditingController(text: '0');
    }
    bool finalReceipt = true;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text('Receive ${doc['document_no']}'),
      content: SizedBox(width: 850, height: 480, child: Column(children: [
        Expanded(child: ListView(children: lines.map((l) => ListTile(
          title: Text('${l['product_code'] ?? l['product_id']}'),
          subtitle: Row(children: [Expanded(child: TextField(controller: ctrls['${l['id']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Received'))), const SizedBox(width: 12), Expanded(child: TextField(controller: damagedCtrls['${l['id']}'], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Damaged')))]),
        )).toList())),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Final receipt'), subtitle: const Text('Any outstanding quantity will be recorded as shortage.'), value: finalReceipt, onChanged: (v) => setLocal(() => finalReceipt = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post receipt'))],
    )));
    if (ok == true) {
      await _service.receiveWarehouseTransfer('${doc['id']}', {'finalReceipt': finalReceipt, 'lines': lines.map((l) => {'lineId': '${l['id']}', 'receivedQty': double.tryParse(ctrls['${l['id']}']!.text) ?? 0, 'damagedQty': double.tryParse(damagedCtrls['${l['id']}']!.text) ?? 0}).toList()});
    }
    for (final c in [...ctrls.values, ...damagedCtrls.values]) { c.dispose(); }
  }
}
