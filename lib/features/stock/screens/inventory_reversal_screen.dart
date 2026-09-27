import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryReversalScreen extends StatefulWidget {
  const InventoryReversalScreen({super.key});
  @override
  State<InventoryReversalScreen> createState() => _InventoryReversalScreenState();
}

class _InventoryReversalScreenState extends State<InventoryReversalScreen> {
  final StockService _service = StockService();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final rows = await _service.reversibleInventoryMovements(); if (mounted) setState(() => _rows = rows); }
    catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventory Reversals')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Reverse posted inventory by creating a compensating movement. Original movements remain immutable and fully auditable.'),
          const SizedBox(height: 16),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
          else if (_rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No reversible movements found.')))
          else ..._rows.map((m) => Card(child: ListTile(
            leading: const Icon(Icons.undo),
            title: Text('${m['movement_no']} • ${m['product_code'] ?? m['product_id']}'),
            subtitle: Text('${m['movement_type']} • ${m['quantity']} ${m['uom']}\n${m['source_warehouse_code'] ?? ''}/${m['from_location_code'] ?? '-'} → ${m['destination_warehouse_code'] ?? ''}/${m['to_location_code'] ?? '-'}'),
            isThreeLine: true,
            trailing: FilledButton.tonal(onPressed: () => _reverse(m), child: const Text('Reverse')),
          ))),
        ],
      ),
    ),
  );

  Future<void> _reverse(Map<String, dynamic> movement) async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Reverse ${movement['movement_no']}?'),
      content: TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason / notes', hintText: 'Explain why this posting is being reversed')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reverse'))],
    ));
    if (ok != true) return;
    try {
      await _service.reverseInventoryMovement('${movement['id']}', notes: notes.text.trim());
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reversal submitted for approval. Stock will change only after approval.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { notes.dispose(); }
  }
}
