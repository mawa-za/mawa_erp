import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryWorkcentreScreen extends StatefulWidget {
  final String workcentreId;
  final String title;
  final String description;
  final List<String> movementTypes;

  const InventoryWorkcentreScreen({
    super.key,
    required this.workcentreId,
    required this.title,
    required this.description,
    required this.movementTypes,
  });

  @override
  State<InventoryWorkcentreScreen> createState() => _InventoryWorkcentreScreenState();
}

class _InventoryWorkcentreScreenState extends State<InventoryWorkcentreScreen> {
  final StockService _service = StockService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _documents = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = <Map<String, dynamic>>[];
      for (final type in widget.movementTypes) {
        all.addAll(await _service.inventoryDocuments(type: type));
      }
      all.sort((a, b) => '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
      if (mounted) setState(() => _documents = all);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_error != null) _ErrorCard(message: _error!, onRetry: _load)
            else if (_documents.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No inventory documents found.')))
            else ..._documents.map(_documentTile),
          ],
        ),
      ),
    );
  }

  Widget _documentTile(Map<String, dynamic> doc) {
    final status = '${doc['status'] ?? ''}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text('${doc['document_no'] ?? ''}  •  ${doc['document_type'] ?? ''}'),
        subtitle: Text('${doc['reference_no'] ?? ''}${doc['notes'] == null ? '' : '\n${doc['notes']}'}'),
        isThreeLine: doc['notes'] != null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Chip(label: Text(status)),
          if (status == 'DRAFT') ...[
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Post', onPressed: () => _post('${doc['id']}')),
          ],
        ]),
      ),
    );
  }

  Future<void> _post(String id) async {
    try {
      await _service.submitInventoryDocument(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory document submitted / posted.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openCreateDialog() async {
    final warehouses = await _service.inventoryReferenceWarehouses(widget.workcentreId);
    final products = await _service.inventoryReferenceProducts(widget.workcentreId);
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _InventoryDocumentDialog(
        service: _service,
        workcentreId: widget.workcentreId,
        movementTypes: widget.movementTypes,
        warehouses: warehouses,
        products: products,
      ),
    );
    if (created == true) await _load();
  }
}

class _InventoryDocumentDialog extends StatefulWidget {
  final StockService service;
  final String workcentreId;
  final List<String> movementTypes;
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> products;

  const _InventoryDocumentDialog({required this.service, required this.workcentreId, required this.movementTypes, required this.warehouses, required this.products});

  @override
  State<_InventoryDocumentDialog> createState() => _InventoryDocumentDialogState();
}

class _InventoryDocumentDialogState extends State<_InventoryDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController(text: '1');
  final _batch = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _uom = TextEditingController(text: 'EA');
  final _expiry = TextEditingController();
  final _serials = TextEditingController();
  final _notes = TextEditingController();
  String? _type;
  String? _warehouseId;
  String? _destinationWarehouseId;
  String? _sourceLocationId;
  String? _destinationLocationId;
  String? _productId;
  String _sourceStatus = 'UNRESTRICTED';
  String _destinationStatus = 'UNRESTRICTED';
  List<Map<String, dynamic>> _sourceLocations = const [];
  List<Map<String, dynamic>> _destinationLocations = const [];
  bool _saving = false;

  static const _statuses = ['UNRESTRICTED','QUALITY','QUARANTINE','BLOCKED','DAMAGED','EXPIRED','SCRAP','IN_TRANSIT','RETURNS'];

  @override
  void initState() {
    super.initState();
    _type = widget.movementTypes.first;
    if (widget.warehouses.isNotEmpty) {
      _warehouseId = '${widget.warehouses.first['id']}';
      _destinationWarehouseId = _warehouseId;
      _loadLocations();
    }
  }

  bool get _needsSource => !{'GOODS_RECEIPT_PO','GOODS_RECEIPT_DIRECT','CUSTOMER_RETURN_RECEIPT','PRODUCTION_RECEIPT','STOCKTAKE_GAIN','ADJUSTMENT_IN','OTHER_RECEIPT','ASSEMBLY_RECEIPT','DISASSEMBLY_RECEIPT'}.contains(_type);
  bool get _needsDestination => !{'SALES_ISSUE','INTERNAL_CONSUMPTION','FUNERAL_SERVICE_ISSUE','SERVICE_ORDER_ISSUE','PRODUCTION_ISSUE','TOMBSTONE_INSTALLATION_ISSUE','RETURN_TO_SUPPLIER','DISPOSAL_ISSUE','STOCKTAKE_LOSS','ADJUSTMENT_OUT','OTHER_ISSUE','ASSEMBLY_CONSUMPTION','DISASSEMBLY_CONSUMPTION'}.contains(_type);

  Future<void> _loadLocations() async {
    if (_warehouseId != null) {
      _sourceLocations = await widget.service.inventoryReferenceLocations(widget.workcentreId, _warehouseId!);
      if (_sourceLocations.isNotEmpty && !_sourceLocations.any((e) => '${e['id']}' == _sourceLocationId)) _sourceLocationId = '${_sourceLocations.first['id']}';
    }
    if (_destinationWarehouseId != null) {
      _destinationLocations = await widget.service.inventoryReferenceLocations(widget.workcentreId, _destinationWarehouseId!);
      if (_destinationLocations.isNotEmpty && !_destinationLocations.any((e) => '${e['id']}' == _destinationLocationId)) _destinationLocationId = '${_destinationLocations.first['id']}';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New inventory document'),
      content: SizedBox(width: 650, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Movement type'), items: widget.movementTypes.map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_',' ')))).toList(), onChanged: (v) => setState(() => _type = v)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _warehouseId, decoration: const InputDecoration(labelText: 'Source / primary warehouse'), items: widget.warehouses.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['warehouse_code']} - ${e['name']}'))).toList(), onChanged: (v) async { _warehouseId=v; if (_destinationWarehouseId == null) _destinationWarehouseId=v; await _loadLocations(); }),
        if (_type == 'TRANSFER_OUT' || _type == 'TRANSFER_IN') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _destinationWarehouseId, decoration: const InputDecoration(labelText: 'Destination warehouse'), items: widget.warehouses.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['warehouse_code']} - ${e['name']}'))).toList(), onChanged: (v) async { _destinationWarehouseId=v; await _loadLocations(); }),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _productId, decoration: const InputDecoration(labelText: 'Product'), validator: (v) => v == null ? 'Select a product' : null, items: widget.products.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['code']} - ${e['description']}'))).toList(), onChanged: (v) => setState(() { _productId=v; final p=widget.products.firstWhere((e)=>'${e['id']}'==v, orElse:()=> <String,dynamic>{}); _uom.text='${p['uom'] ?? 'EA'}'; })),
        if (_needsSource) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _sourceLocationId, decoration: const InputDecoration(labelText: 'Source location'), validator: (v) => v == null ? 'Select a source location' : null, items: _sourceLocations.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['location_code']} - ${e['name']}'))).toList(), onChanged: (v) => setState(() => _sourceLocationId=v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _sourceStatus, decoration: const InputDecoration(labelText: 'Source stock status'), items: _statuses.map((e) => DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged:(v)=>setState(()=>_sourceStatus=v!)),
        ],
        if (_needsDestination) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _destinationLocationId, decoration: const InputDecoration(labelText: 'Destination location'), validator: (v) => v == null ? 'Select a destination location' : null, items: _destinationLocations.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['location_code']} - ${e['name']}'))).toList(), onChanged: (v) => setState(() => _destinationLocationId=v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _destinationStatus, decoration: const InputDecoration(labelText: 'Destination stock status'), items: _statuses.map((e) => DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged:(v)=>setState(()=>_destinationStatus=v!)),
        ],
        const SizedBox(height: 12),
        Row(children:[Expanded(child:TextFormField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: const TextInputType.numberWithOptions(decimal:true), validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter a quantity greater than zero' : null)),const SizedBox(width:12),SizedBox(width:120,child:TextFormField(controller:_uom,decoration:const InputDecoration(labelText:'UOM'),validator:(v)=>(v??'').trim().isEmpty?'Required':null))]),
        const SizedBox(height: 12),
        TextFormField(controller: _batch, decoration: const InputDecoration(labelText: 'Batch / lot (optional)')),
        const SizedBox(height: 12),
        TextFormField(controller: _expiry, decoration: const InputDecoration(labelText: 'Expiry date (YYYY-MM-DD, optional)')),
        const SizedBox(height: 12),
        TextFormField(controller: _serials, decoration: const InputDecoration(labelText: 'Serial numbers (comma separated, optional)'), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(controller: _cost, decoration: const InputDecoration(labelText: 'Unit cost'), keyboardType: const TextInputType.numberWithOptions(decimal:true)),
        const SizedBox(height: 12),
        TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
      ])))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context,false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Create draft')),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _type == null || _warehouseId == null) return;
    setState(() => _saving=true);
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      await widget.service.createInventoryDocument({
        'documentType': _type,
        'warehouseId': _warehouseId,
        if (_destinationWarehouseId != null) 'destinationWarehouseId': _destinationWarehouseId,
        'notes': _notes.text.trim(),
        'idempotencyKey': '${widget.workcentreId}:$now',
        'lines': [{
          'productId': _productId,
          'quantity': double.parse(_qty.text),
          'uom': _uom.text.trim().toUpperCase(),
          if (_needsSource) 'sourceLocationId': _sourceLocationId,
          if (_needsDestination) 'destinationLocationId': _destinationLocationId,
          if (_needsSource) 'sourceStockStatus': _sourceStatus,
          if (_needsDestination) 'destinationStockStatus': _destinationStatus,
          if (_batch.text.trim().isNotEmpty) 'batchNo': _batch.text.trim(),
          if (_expiry.text.trim().isNotEmpty) 'expiryDate': _expiry.text.trim(),
          if (_serials.text.trim().isNotEmpty) 'serialNumbers': _serials.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          'unitCost': double.tryParse(_cost.text) ?? 0,
        }],
      });
      if (mounted) Navigator.pop(context,true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving=false);
    }
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children:[Text(message),const SizedBox(height:12),FilledButton(onPressed:onRetry,child:const Text('Retry'))])));
}
