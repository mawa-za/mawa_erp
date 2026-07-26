import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

class StorageConfigurationScreen extends StatefulWidget {
  const StorageConfigurationScreen({super.key});

  @override
  State<StorageConfigurationScreen> createState() => _StorageConfigurationScreenState();
}

class _StorageConfigurationScreenState extends State<StorageConfigurationScreen> {
  List<Map<String, dynamic>> warehouses = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> bins = [];
  String? warehouseId;
  String? locationId;
  bool loading = true;

  @override
  void initState() { super.initState(); _loadWarehouses(); }

  Future<List<Map<String, dynamic>>> _get(String path, [Map<String, dynamic>? query]) async {
    final response = await ApiClient().get(path, queryParameters: query);
    if (response.statusCode != 200) throw Exception(response.body);
    return (jsonDecode(response.body) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _loadWarehouses() async {
    setState(() => loading = true);
    try {
      warehouses = await _get('/v2/storage-configuration/warehouses', {'activeOnly': false});
      if (warehouseId != null && !warehouses.any((row) => row['id'].toString() == warehouseId)) warehouseId = null;
      await _loadLocations();
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _loadLocations() async {
    locations = warehouseId == null ? [] : await _get('/v2/storage-configuration/locations', {'warehouseId': warehouseId, 'activeOnly': false});
    if (locationId != null && !locations.any((row) => row['id'].toString() == locationId)) locationId = null;
    await _loadBins();
    if (mounted) setState(() {});
  }

  Future<void> _loadBins() async {
    bins = locationId == null ? [] : await _get('/v2/storage-configuration/bins', {'locationId': locationId, 'activeOnly': false});
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>?> _editDialog(String title, Map<String, dynamic>? current, {bool showCapacity = false, bool showStorageType = false}) async {
    final code = TextEditingController(text: current?['code']?.toString() ?? '');
    final name = TextEditingController(text: current?['name']?.toString() ?? '');
    final description = TextEditingController(text: current?['description']?.toString() ?? '');
    final capacity = TextEditingController(text: current?['capacity']?.toString() ?? '');
    final storageType = TextEditingController(text: current?['storage_type']?.toString() ?? '');
    bool active = current == null || current['active'] == true || current['active'] == 1;
    final key = GlobalKey<FormState>();
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Form(key: key, child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Code'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
          if (showStorageType) TextFormField(controller: storageType, decoration: const InputDecoration(labelText: 'Storage Type')),
          if (showCapacity) TextFormField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (value) => setState(() => active = value)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (!key.currentState!.validate()) return;
            Navigator.pop(context, {
              if (current?['id'] != null) 'id': current!['id'],
              'code': code.text.trim().toUpperCase(), 'name': name.text.trim(),
              'description': description.text.trim(), 'active': active,
              if (showStorageType) 'storageType': storageType.text.trim(),
              if (showCapacity && capacity.text.trim().isNotEmpty) 'capacity': int.tryParse(capacity.text.trim()),
            });
          }, child: const Text('Save')),
        ],
      )),
    );
  }

  Future<void> _save(String path, Map<String, dynamic> body) async {
    final response = await ApiClient().post(path, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception(response.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Warehouse & Storage Configuration')),
      body: loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _column('Warehouses', warehouses, warehouseId, (id) async { warehouseId = id; locationId = null; await _loadLocations(); }, () async {
            final body = await _editDialog('Warehouse', null); if (body != null) { await _save('/v2/storage-configuration/warehouses', body); await _loadWarehouses(); }
          }, (row) async { final body = await _editDialog('Warehouse', row); if (body != null) { await _save('/v2/storage-configuration/warehouses', body); await _loadWarehouses(); }})),
          const SizedBox(width: 12),
          Expanded(child: _column('Storage Locations', locations, locationId, (id) async { locationId = id; await _loadBins(); }, warehouseId == null ? null : () async {
            final body = await _editDialog('Storage Location', null, showStorageType: true); if (body != null) { body['warehouseId'] = warehouseId; await _save('/v2/storage-configuration/locations', body); await _loadLocations(); }
          }, (row) async { final body = await _editDialog('Storage Location', row, showStorageType: true); if (body != null) { body['warehouseId'] = warehouseId; await _save('/v2/storage-configuration/locations', body); await _loadLocations(); }})),
          const SizedBox(width: 12),
          Expanded(child: _column('Storage Bins', bins, null, (_) async {}, locationId == null ? null : () async {
            final body = await _editDialog('Storage Bin', null, showCapacity: true); if (body != null) { body['locationId'] = locationId; await _save('/v2/storage-configuration/bins', body); await _loadBins(); }
          }, (row) async { final body = await _editDialog('Storage Bin', row, showCapacity: true); if (body != null) { body['locationId'] = locationId; await _save('/v2/storage-configuration/bins', body); await _loadBins(); }})),
        ]),
      ),
    );
  }

  Widget _column(String title, List<Map<String, dynamic>> rows, String? selected, Future<void> Function(String?) onSelect, VoidCallback? onAdd, Future<void> Function(Map<String, dynamic>) onEdit) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(onPressed: onAdd, icon: const Icon(Icons.add))]),
      const Divider(),
      if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No records configured.')),
      ...rows.map((row) => ListTile(
        selected: selected == row['id']?.toString(),
        title: Text('${row['code']} - ${row['name']}'),
        subtitle: Text((row['active'] == true || row['active'] == 1) ? 'Active' : 'Inactive'),
        onTap: () => onSelect(row['id']?.toString()),
        trailing: IconButton(onPressed: () => onEdit(row), icon: const Icon(Icons.edit_outlined)),
      )),
    ])));
  }
}
