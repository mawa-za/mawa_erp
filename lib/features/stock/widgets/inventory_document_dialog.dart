import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stock_service.dart';

enum InventoryDocumentType { quotation, purchaseOrder, goodsReceipt, salesOrder }

Future<bool?> showInventoryDocumentDialog({
  required BuildContext context,
  required StockService service,
  required InventoryDocumentType type,
  required List<Map<String, dynamic>> warehouses,
  required List<Map<String, dynamic>> storageLocations,
  Map<String, dynamic>? sourceDocument,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InventoryDocumentDialog(
      service: service,
      type: type,
      warehouses: warehouses,
      storageLocations: storageLocations,
      sourceDocument: sourceDocument,
    ),
  );
}

class InventoryDocumentDialog extends StatefulWidget {
  final StockService service;
  final InventoryDocumentType type;
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> storageLocations;
  final Map<String, dynamic>? sourceDocument;

  const InventoryDocumentDialog({
    super.key,
    required this.service,
    required this.type,
    required this.warehouses,
    required this.storageLocations,
    this.sourceDocument,
  });

  @override
  State<InventoryDocumentDialog> createState() => _InventoryDocumentDialogState();
}

class _InventoryDocumentDialogState extends State<InventoryDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _partnerSearchController = SearchController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  bool _saving = false;
  Map<String, dynamic>? _selectedPartner;
  String? _selectedWarehouseId;
  String? _selectedLocationId;
  DateTime _documentDate = DateTime.now();
  DateTime? _secondaryDate;
  final List<_InventoryLineDraft> _lines = [];

  bool get _isQuotation => widget.type == InventoryDocumentType.quotation;
  bool get _isPurchaseOrder => widget.type == InventoryDocumentType.purchaseOrder;
  bool get _isGoodsReceipt => widget.type == InventoryDocumentType.goodsReceipt;
  bool get _isSalesOrder => widget.type == InventoryDocumentType.salesOrder;
  bool get _isCustomerDocument => _isQuotation || _isSalesOrder;
  bool get _isSupplierDocument => _isPurchaseOrder || _isGoodsReceipt;

  String get _title {
    switch (widget.type) {
      case InventoryDocumentType.quotation:
        return 'Create Quotation';
      case InventoryDocumentType.purchaseOrder:
        return 'Create Purchase Order';
      case InventoryDocumentType.goodsReceipt:
        return widget.sourceDocument == null ? 'Create Goods Receipt' : 'Receive Purchase Order';
      case InventoryDocumentType.salesOrder:
        return 'Create Sales Order';
    }
  }

  String get _partnerLabel => _isCustomerDocument ? 'Customer' : 'Supplier';
  String get _referenceLabel => _isCustomerDocument ? 'Customer Reference' : 'Supplier Reference';
  String get _secondaryDateLabel {
    if (_isQuotation) return 'Valid Until';
    if (_isPurchaseOrder || _isGoodsReceipt) return 'Expected / Receipt Date';
    return 'Requested Delivery Date';
  }

  @override
  void initState() {
    super.initState();
    _selectedWarehouseId = _firstNonEmpty(widget.sourceDocument?['warehouse_id']) ?? _firstId(widget.warehouses);
    _selectedLocationId = _firstNonEmpty(widget.sourceDocument?['receiving_location_id']) ??
        _firstNonEmpty(widget.sourceDocument?['storage_location_id']) ??
        _firstLocationForWarehouse(_selectedWarehouseId);
    _referenceController.text = _text(widget.sourceDocument?['supplier_reference'] ?? widget.sourceDocument?['customer_reference']);
    _notesController.text = widget.sourceDocument == null ? '' : 'Created from ${_sourceNumber(widget.sourceDocument!)}';
    _initPartnerFromSource();
    _initLines();
  }

  void _initPartnerFromSource() {
    final source = widget.sourceDocument;
    if (source == null) return;
    final id = _text(source[_isCustomerDocument ? 'customer_partner_id' : 'supplier_partner_id']);
    if (id.isEmpty) return;
    _selectedPartner = {
      'id': id,
      'partnerId': id,
      'partnerNo': source[_isCustomerDocument ? 'customer_no' : 'supplier_no'],
      'no': source[_isCustomerDocument ? 'customer_no' : 'supplier_no'],
      'name1': source[_isCustomerDocument ? 'customer_name' : 'supplier_name'],
    };
    _partnerSearchController.text = _partnerName(_selectedPartner!);
  }

  void _initLines() {
    final sourceLines = widget.sourceDocument?['lines'];
    if (sourceLines is List && sourceLines.isNotEmpty) {
      for (final rawLine in sourceLines) {
        final line = Map<String, dynamic>.from(rawLine as Map);
        if (_isGoodsReceipt && line.containsKey('open_qty')) {
          final openQty = _toDouble(line['open_qty']);
          if (openQty <= 0) continue;
          _lines.add(_InventoryLineDraft.fromPurchaseOrderLine(line));
        } else {
          _lines.add(_InventoryLineDraft.fromExistingLine(line, forGoodsReceipt: _isGoodsReceipt));
        }
      }
    }
    if (_lines.isEmpty) {
      _lines.add(_InventoryLineDraft());
      if (!_isGoodsReceipt) _lines.add(_InventoryLineDraft());
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    _partnerSearchController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(colorScheme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPartnerAndGeneralSection(),
                      const SizedBox(height: 16),
                      _buildLineSection(),
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ),
              _buildTotalsBar(totals, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        child: Row(
          children: [
            Icon(_iconForType(), color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(_title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(onPressed: _saving ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
          ],
        ),
      );

  Widget _buildPartnerAndGeneralSection() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document Header', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 360, child: _buildPartnerSearch()),
                  SizedBox(width: 240, child: TextFormField(
                    controller: _referenceController,
                    decoration: InputDecoration(labelText: _referenceLabel, border: const OutlineInputBorder()),
                  )),
                  SizedBox(width: 200, child: _buildDateField(_isGoodsReceipt ? 'Receipt Date' : 'Document Date', _documentDate, (date) => setState(() => _documentDate = date))),
                  SizedBox(width: 220, child: _buildDateField(_secondaryDateLabel, _secondaryDate, (date) => setState(() => _secondaryDate = date), nullable: true)),
                  if (_isPurchaseOrder || _isGoodsReceipt || _isSalesOrder)
                    SizedBox(width: 260, child: _warehouseDropdown()),
                  if (_isPurchaseOrder || _isGoodsReceipt)
                    SizedBox(width: 260, child: _locationDropdown(label: _isPurchaseOrder ? 'Receiving Location' : 'Storage Location')),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildPartnerSearch() {
    return SearchAnchor(
      searchController: _partnerSearchController,
      builder: (context, controller) => SearchBar(
        controller: controller,
        hintText: 'Search $_partnerLabel',
        leading: const Icon(Icons.search),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade400)),
        onTap: () => controller.openView(),
        onChanged: (_) => controller.openView(),
      ),
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        if (query.length < 2) return [ListTile(title: Text('Type at least 2 characters to search $_partnerLabel'))];
        final partners = await widget.service.searchPartners(query, role: _isCustomerDocument ? 'CUSTOMER' : 'SUPPLIER');
        if (partners.isEmpty) return [const ListTile(title: Text('No partners found'))];
        return partners.take(20).map((partner) => ListTile(
              leading: CircleAvatar(child: Icon(_isCustomerDocument ? Icons.person_outline : Icons.local_shipping_outlined)),
              title: Text(_partnerName(partner), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('No: ${_text(partner['partnerNo'] ?? partner['number'] ?? partner['no'])}'),
              onTap: () {
                setState(() {
                  _selectedPartner = partner;
                  controller.closeView(_partnerName(partner));
                });
              },
            ));
      },
    );
  }

  Widget _buildDateField(String label, DateTime? date, ValueChanged<DateTime> onPicked, {bool nullable = false}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(date == null && nullable ? 'Optional' : _dateFormat.format(date ?? DateTime.now()))),
          ],
        ),
      ),
    );
  }

  Widget _warehouseDropdown() => DropdownButtonFormField<String>(
        value: _selectedWarehouseId?.isNotEmpty == true ? _selectedWarehouseId : null,
        decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
        items: widget.warehouses.map((w) => DropdownMenuItem<String>(
              value: _text(w['id']),
              child: Text('${_text(w['warehouse_code'])} - ${_text(w['name'])}', overflow: TextOverflow.ellipsis),
            )).toList(),
        onChanged: (value) => setState(() {
          _selectedWarehouseId = value;
          _selectedLocationId = _firstLocationForWarehouse(value);
        }),
        validator: (value) => (_isPurchaseOrder || _isGoodsReceipt || _isSalesOrder) && (value == null || value.isEmpty) ? 'Required' : null,
      );

  Widget _locationDropdown({required String label}) {
    final locations = widget.storageLocations.where((loc) => _selectedWarehouseId == null || _text(loc['warehouse_id']) == _selectedWarehouseId).toList();
    return DropdownButtonFormField<String>(
      value: locations.any((loc) => _text(loc['id']) == _selectedLocationId) ? _selectedLocationId : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: locations.map((loc) => DropdownMenuItem<String>(
            value: _text(loc['id']),
            child: Text('${_text(loc['location_code'])} - ${_text(loc['name'])}', overflow: TextOverflow.ellipsis),
          )).toList(),
      onChanged: (value) => setState(() => _selectedLocationId = value),
      validator: (value) => (_isPurchaseOrder || _isGoodsReceipt) && (value == null || value.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildLineSection() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Line Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                  OutlinedButton.icon(onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('Add Item')),
                ],
              ),
              const SizedBox(height: 12),
              _buildLineHeader(),
              ...List.generate(_lines.length, _buildLineRow),
            ],
          ),
        ),
      );

  Widget _buildLineHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: Colors.grey.shade100,
        child: const Row(children: [
          SizedBox(width: 32, child: Text('#')),
          Expanded(flex: 3, child: Text('Product')),
          SizedBox(width: 8),
          Expanded(flex: 3, child: Text('Description')),
          SizedBox(width: 8),
          SizedBox(width: 90, child: Text('Qty')),
          SizedBox(width: 8),
          SizedBox(width: 80, child: Text('UOM')),
          SizedBox(width: 8),
          SizedBox(width: 120, child: Text('Unit Price/Cost')),
          SizedBox(width: 8),
          SizedBox(width: 90, child: Text('VAT %')),
          SizedBox(width: 8),
          SizedBox(width: 130, child: Text('Line Total')),
          SizedBox(width: 40),
        ]),
      );

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 32, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text('${index + 1}'))),
        Expanded(flex: 3, child: _productSearch(line)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: TextFormField(controller: line.descriptionController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), maxLines: 2)),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: TextFormField(controller: line.quantityController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), validator: (v) => _toDouble(v) <= 0 ? 'Qty' : null)),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: TextFormField(controller: line.uomController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: TextFormField(controller: line.unitPriceController, decoration: const InputDecoration(prefixText: 'R ', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: TextFormField(controller: line.taxRateController, decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
        const SizedBox(width: 8),
        SizedBox(width: 130, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_money(_lineTotal(line)), style: const TextStyle(fontWeight: FontWeight.bold)))),
        SizedBox(width: 40, child: IconButton(icon: const Icon(Icons.delete_outline), onPressed: _lines.length == 1 ? null : () => _removeLine(index))),
      ]),
    );
  }

  Widget _productSearch(_InventoryLineDraft line) {
    return SearchAnchor(
      searchController: line.productSearchController,
      builder: (context, controller) => SearchBar(
        controller: controller,
        hintText: line.productCode.isEmpty ? 'Search product' : line.productCode,
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade400)),
        onTap: () => controller.openView(),
        onChanged: (_) => controller.openView(),
      ),
      suggestionsBuilder: (context, controller) async {
        final products = await widget.service.searchProducts(controller.text.trim());
        if (products.isEmpty) return [const ListTile(title: Text('No products found'))];
        return products.take(25).map((product) {
          final price = _productPrice(product);
          return ListTile(
            dense: true,
            title: Text('${_text(product['code'])} - ${_text(product['description'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Price: ${_money(price)}'),
            onTap: () {
              setState(() {
                line.productId = _text(product['id']);
                line.productCode = _text(product['code']);
                line.productSearchController.text = line.productCode;
                line.descriptionController.text = _text(product['description']);
                line.unitPriceController.text = price.toStringAsFixed(2);
                line.uomController.text = _productUom(product);
                controller.closeView(line.productCode);
              });
            },
          );
        });
      },
    );
  }

  Widget _buildNotesSection() => TextFormField(
        controller: _notesController,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
      );

  Widget _buildTotalsBar(Map<String, double> totals, ColorScheme colorScheme) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(child: Wrap(spacing: 18, runSpacing: 8, children: [
                _summaryPill('Subtotal', totals['subtotal'] ?? 0),
                _summaryPill('VAT', totals['tax'] ?? 0),
                _summaryPill('Grand Total', totals['total'] ?? 0, isTotal: true),
              ])),
              TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(_isGoodsReceipt ? 'Receive Items' : 'Save Document'),
              ),
            ],
          ),
        ),
      );

  Widget _summaryPill(String label, double amount, {bool isTotal = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isTotal ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(_money(amount), style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: FontWeight.bold)),
        ]),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartner == null && !_isGoodsReceipt) {
      _snack('Please select $_partnerLabel', isError: true);
      return;
    }
    final validLines = _lines.where((line) => line.hasProduct && _toDouble(line.quantityController.text) > 0).toList();
    if (validLines.isEmpty) {
      _snack('Please add at least one product line', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      switch (widget.type) {
        case InventoryDocumentType.quotation:
          await widget.service.createQuotation(
            customerPartnerId: _partnerId,
            customerReference: _referenceController.text.trim(),
            validUntil: _secondaryDate == null ? null : _dateFormat.format(_secondaryDate!),
            requestedDeliveryDate: null,
            notes: _notesController.text.trim(),
            lines: validLines.map(_commercialLinePayload).toList(),
          );
          break;
        case InventoryDocumentType.purchaseOrder:
          await widget.service.createPurchaseOrder(
            supplierPartnerId: _partnerId,
            supplierReference: _referenceController.text.trim(),
            expectedDeliveryDate: _secondaryDate == null ? null : _dateFormat.format(_secondaryDate!),
            warehouseId: _selectedWarehouseId,
            receivingLocationId: _selectedLocationId,
            notes: _notesController.text.trim(),
            lines: validLines.map(_commercialLinePayload).toList(),
          );
          break;
        case InventoryDocumentType.goodsReceipt:
          if (widget.sourceDocument != null) {
            await widget.service.receivePurchaseOrder(
              _text(widget.sourceDocument!['id']),
              warehouseId: _selectedWarehouseId,
              storageLocationId: _selectedLocationId,
              supplierReference: _referenceController.text.trim(),
              notes: _notesController.text.trim(),
              lines: validLines.map(_goodsReceiptLinePayload).toList(),
            );
          } else {
            await widget.service.createGoodsReceipt(
              warehouseId: _selectedWarehouseId ?? '',
              storageLocationId: _selectedLocationId ?? '',
              supplierPartnerId: _partnerId,
              supplierReference: _referenceController.text.trim(),
              notes: _notesController.text.trim(),
              lines: validLines.map(_goodsReceiptLinePayload).toList(),
            );
          }
          break;
        case InventoryDocumentType.salesOrder:
          await widget.service.createSalesOrder(
            customerPartnerId: _partnerId,
            customerReference: _referenceController.text.trim(),
            warehouseId: _selectedWarehouseId,
            requestedDeliveryDate: _secondaryDate == null ? null : _dateFormat.format(_secondaryDate!),
            notes: _notesController.text.trim(),
            lines: validLines.map(_salesLinePayload).toList(),
          );
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _commercialLinePayload(_InventoryLineDraft line) => {
        'productId': line.productId,
        'productCode': line.productCode,
        'description': line.descriptionController.text.trim(),
        'quantity': _toDouble(line.quantityController.text),
        'uom': line.uomController.text.trim().isEmpty ? 'EA' : line.uomController.text.trim(),
        'unitPrice': _toDouble(line.unitPriceController.text),
        'taxRate': _toDouble(line.taxRateController.text),
      };

  Map<String, dynamic> _salesLinePayload(_InventoryLineDraft line) => _commercialLinePayload(line);

  Map<String, dynamic> _goodsReceiptLinePayload(_InventoryLineDraft line) => {
        if (line.purchaseOrderLineId != null && line.purchaseOrderLineId!.isNotEmpty) 'purchaseOrderLineId': line.purchaseOrderLineId,
        'productId': line.productId,
        'productCode': line.productCode,
        'description': line.descriptionController.text.trim(),
        'quantity': _toDouble(line.quantityController.text),
        'uom': line.uomController.text.trim().isEmpty ? 'EA' : line.uomController.text.trim(),
        if (line.batchController.text.trim().isNotEmpty) 'batchNo': line.batchController.text.trim(),
        'unitCost': _toDouble(line.unitPriceController.text),
        'taxRate': _toDouble(line.taxRateController.text),
      };

  void _addLine() => setState(() => _lines.add(_InventoryLineDraft()));

  void _removeLine(int index) => setState(() {
        _lines[index].dispose();
        _lines.removeAt(index);
      });

  Map<String, double> _calculateTotals() {
    double subtotal = 0;
    double tax = 0;
    for (final line in _lines) {
      final lineSubtotal = _lineSubtotal(line);
      subtotal += lineSubtotal;
      tax += lineSubtotal * (_toDouble(line.taxRateController.text) / 100);
    }
    return {'subtotal': subtotal, 'tax': tax, 'total': subtotal + tax};
  }

  double _lineSubtotal(_InventoryLineDraft line) => _toDouble(line.quantityController.text) * _toDouble(line.unitPriceController.text);
  double _lineTotal(_InventoryLineDraft line) => _lineSubtotal(line) * (1 + (_toDouble(line.taxRateController.text) / 100));

  String? get _partnerId {
    if (_selectedPartner == null) return null;
    return _text(_selectedPartner!['id'] ?? _selectedPartner!['partnerId']);
  }

  String _firstLocationForWarehouse(String? warehouseId) {
    for (final loc in widget.storageLocations) {
      if (warehouseId == null || _text(loc['warehouse_id']) == warehouseId) return _text(loc['id']);
    }
    return '';
  }

  String? _firstId(List<Map<String, dynamic>> rows) => rows.isEmpty ? null : _text(rows.first['id']);
  String? _firstNonEmpty(dynamic value) => _text(value).isEmpty ? null : _text(value);
  String _sourceNumber(Map<String, dynamic> source) => _text(source['purchase_order_no'] ?? source['quotation_no'] ?? source['sales_order_no'] ?? source['receipt_no']);

  IconData _iconForType() {
    switch (widget.type) {
      case InventoryDocumentType.quotation:
        return Icons.request_quote_outlined;
      case InventoryDocumentType.purchaseOrder:
        return Icons.assignment_outlined;
      case InventoryDocumentType.goodsReceipt:
        return Icons.call_received_outlined;
      case InventoryDocumentType.salesOrder:
        return Icons.shopping_cart_outlined;
    }
  }

  String _partnerName(Map<String, dynamic> partner) {
    final explicit = _text(partner['fullName'] ?? partner['displayName']);
    if (explicit.isNotEmpty) return explicit;
    final org = _text(partner['name1']);
    final first = _text(partner['name2']);
    final middle = _text(partner['name3']);
    final name = [first, middle, org].where((part) => part.trim().isNotEmpty).join(' ').trim();
    return name.isEmpty ? _text(partner['partnerNo'] ?? partner['number'] ?? partner['no'] ?? 'Unnamed Partner') : name;
  }

  double _productPrice(Map<String, dynamic> product) {
    final direct = _toDouble(product['price'] ?? product['unitPrice'] ?? product['amount']);
    if (direct > 0) return direct;
    final pricings = product['pricings'];
    if (pricings is List && pricings.isNotEmpty && pricings.first is Map) {
      return _toDouble((pricings.first as Map)['value']);
    }
    return 0;
  }

  String _productUom(Map<String, dynamic> product) {
    final raw = product['baseUnitOfMeasure'] ?? product['base_unit_of_measure'] ?? product['uom'];
    if (raw is Map) return _text(raw['code'] ?? raw['description']).isEmpty ? 'EA' : _text(raw['code'] ?? raw['description']);
    return _text(raw).isEmpty ? 'EA' : _text(raw);
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : null));
  }

  String _money(double amount) => 'R ${amount.toStringAsFixed(2)}';
  String _text(dynamic value) => value == null ? '' : value.toString();
  double _toDouble(dynamic value) => double.tryParse(_text(value).replaceAll(',', '.')) ?? 0;
}

class _InventoryLineDraft {
  String? productId;
  String productCode;
  String? purchaseOrderLineId;
  final SearchController productSearchController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController uomController;
  final TextEditingController unitPriceController;
  final TextEditingController taxRateController;
  final TextEditingController batchController;

  _InventoryLineDraft({
    this.productId,
    this.productCode = '',
    this.purchaseOrderLineId,
    String description = '',
    String quantity = '1',
    String uom = 'EA',
    String unitPrice = '0.00',
    String taxRate = '15',
    String batchNo = '',
  })  : productSearchController = SearchController()..text = productCode,
        descriptionController = TextEditingController(text: description),
        quantityController = TextEditingController(text: quantity),
        uomController = TextEditingController(text: uom),
        unitPriceController = TextEditingController(text: unitPrice),
        taxRateController = TextEditingController(text: taxRate),
        batchController = TextEditingController(text: batchNo);

  factory _InventoryLineDraft.fromPurchaseOrderLine(Map<String, dynamic> line) => _InventoryLineDraft(
        productId: _s(line['product_id']),
        productCode: _s(line['product_code']),
        purchaseOrderLineId: _s(line['id']),
        description: _s(line['product_description'] ?? line['description']),
        quantity: _s(line['open_qty']).isEmpty ? _s(line['ordered_qty']) : _s(line['open_qty']),
        uom: _s(line['uom']).isEmpty ? 'EA' : _s(line['uom']),
        unitPrice: _s(line['unit_cost']).isEmpty ? _s(line['unit_price']) : _s(line['unit_cost']),
        taxRate: _s(line['tax_rate']).isEmpty ? '15' : _s(line['tax_rate']),
      );

  factory _InventoryLineDraft.fromExistingLine(Map<String, dynamic> line, {bool forGoodsReceipt = false}) => _InventoryLineDraft(
        productId: _s(line['product_id']),
        productCode: _s(line['product_code']),
        purchaseOrderLineId: _s(line['purchase_order_line_id']),
        description: _s(line['product_description'] ?? line['description']),
        quantity: _s(line['quantity'] ?? line['ordered_qty']),
        uom: _s(line['uom']).isEmpty ? 'EA' : _s(line['uom']),
        unitPrice: forGoodsReceipt ? _s(line['unit_cost']) : _s(line['unit_price'] ?? line['unit_cost']),
        taxRate: _s(line['tax_rate']).isEmpty ? '15' : _s(line['tax_rate']),
        batchNo: _s(line['batch_no']),
      );

  bool get hasProduct => (productId != null && productId!.isNotEmpty) || productCode.isNotEmpty;

  void dispose() {
    productSearchController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    uomController.dispose();
    unitPriceController.dispose();
    taxRateController.dispose();
    batchController.dispose();
  }

  static String _s(dynamic value) => value == null ? '' : value.toString();
}
