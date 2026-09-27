import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryStockCountScreen extends StatefulWidget {
  const InventoryStockCountScreen({super.key});

  @override
  State<InventoryStockCountScreen> createState() => _InventoryStockCountScreenState();
}

class _InventoryStockCountScreenState extends State<InventoryStockCountScreen> {
  final StockService _service = StockService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _counts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _service.inventoryStockCounts();
      if (mounted) setState(() => _counts = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Counts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCount,
        icon: const Icon(Icons.add),
        label: const Text('New Count'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Create cycle or full stock counts from a balance snapshot. Frozen counts prevent movements against the counted stock until variances are resolved.'),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_error != null)
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
            else if (_counts.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No stock counts found.')))
            else
              ..._counts.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text('${c['count_no']} • ${c['warehouse_code'] ?? ''}'),
                  subtitle: Text('${c['count_type']} • ${c['location_code'] ?? 'All locations'}${c['blind_count'] == true || c['blind_count'] == 1 ? ' • Blind' : ''}${c['freeze_stock'] == true || c['freeze_stock'] == 1 ? ' • Frozen' : ''}'),
                  trailing: Chip(label: Text('${c['status']}')),
                  onTap: () => _openCount('${c['id']}'),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Future<void> _createCount() async {
    final warehouses = await _service.inventoryReferenceWarehouses('stock-count');
    if (!mounted) return;
    String? warehouseId = warehouses.isEmpty ? null : '${warehouses.first['id']}';
    String? locationId;
    String countType = 'CYCLE';
    bool blind = true;
    bool freeze = true;
    List<Map<String, dynamic>> locations = const [];
    final notes = TextEditingController();

    Future<void> loadLocations(StateSetter setLocal) async {
      if (warehouseId == null) return;
      final rows = await _service.inventoryReferenceLocations('stock-count', warehouseId!);
      setLocal(() { locations = rows; locationId = null; });
    }

    if (warehouseId != null) {
      locations = await _service.inventoryReferenceLocations('stock-count', warehouseId);
      if (!mounted) return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create stock count'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: warehouseId,
                    decoration: const InputDecoration(labelText: 'Warehouse'),
                    items: warehouses.map((w) => DropdownMenuItem(value: '${w['id']}', child: Text('${w['warehouse_code']} - ${w['name']}'))).toList(),
                    onChanged: (v) async { setLocal(() => warehouseId = v); await loadLocations(setLocal); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: locationId,
                    decoration: const InputDecoration(labelText: 'Location (optional)'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('All locations')),
                      ...locations.map((l) => DropdownMenuItem(value: '${l['id']}', child: Text('${l['location_code']} - ${l['name']}'))),
                    ],
                    onChanged: (v) => setLocal(() => locationId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: countType,
                    decoration: const InputDecoration(labelText: 'Count type'),
                    items: const [
                      DropdownMenuItem(value: 'CYCLE', child: Text('Cycle count')),
                      DropdownMenuItem(value: 'FULL', child: Text('Full stocktake')),
                    ],
                    onChanged: (v) => setLocal(() => countType = v ?? 'CYCLE'),
                  ),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Blind count'), subtitle: const Text('Do not show expected quantity to the counter.'), value: blind, onChanged: (v) => setLocal(() => blind = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Freeze counted stock'), subtitle: const Text('Block movements while this count is open.'), value: freeze, onChanged: (v) => setLocal(() => freeze = v)),
                  TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: warehouseId == null ? null : () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true || warehouseId == null) return;
    try {
      final created = await _service.createInventoryStockCount({
        'warehouseId': warehouseId,
        if (locationId != null) 'storageLocationId': locationId,
        'countType': countType,
        'blindCount': blind,
        'freezeStock': freeze,
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      });
      await _load();
      if (mounted) await _openCount('${created['id']}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openCount(String id) async {
    try {
      var count = await _service.inventoryStockCount(id);
      if (!mounted) return;
      final blind = count['blind_count'] == true || count['blind_count'] == 1;
      final status = '${count['status']}';
      final lines = (count['lines'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final controllers = <String, TextEditingController>{
        for (final line in lines) '${line['id']}': TextEditingController(text: line['counted_qty']?.toString() ?? ''),
      };
      final save = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${count['count_no']} • ${count['warehouse_code'] ?? ''}'),
          content: SizedBox(
            width: 850,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${count['count_type']} • ${count['location_code'] ?? 'All locations'} • $status'),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final expected = line['system_qty'];
                      return ListTile(
                        title: Text('${line['product_code'] ?? line['product_id']} - ${line['product_description'] ?? ''}'),
                        subtitle: Text('${line['location_code'] ?? ''}${('${line['batch_no'] ?? ''}').isNotEmpty ? ' • Batch ${line['batch_no']}' : ''} • ${line['stock_status']}${blind ? '' : ' • Expected $expected ${line['uom']}'}'),
                        trailing: SizedBox(
                          width: 135,
                          child: TextField(
                            controller: controllers['${line['id']}'],
                            enabled: status == 'COUNTING',
                            textAlign: TextAlign.end,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Counted ${line['uom']}'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'close'), child: const Text('Close')),
            if (status == 'COUNTING') ...[
              OutlinedButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save counts')),
              FilledButton(onPressed: () => Navigator.pop(context, 'finalize'), child: const Text('Finalize')),
            ],
          ],
        ),
      );
      if (save == 'save' || save == 'finalize') {
        final entries = <Map<String, dynamic>>[];
        for (final line in lines) {
          final text = controllers['${line['id']}']!.text.trim();
          if (text.isEmpty) continue;
          entries.add({'lineId': '${line['id']}', 'countedQty': double.parse(text)});
        }
        count = await _service.recordInventoryStockCount(id, entries);
        if (save == 'finalize') count = await _service.finalizeInventoryStockCount(id);
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save == 'finalize' ? 'Stock count submitted for variance processing.' : 'Counted quantities saved.')));
      }
      for (final c in controllers.values) { c.dispose(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
