import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stock_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

enum InventoryDocumentType { quotation, purchaseOrder, goodsReceipt, salesOrder }

Future<bool?> showInventoryDocumentDialog({
  required BuildContext context,
  required StockService service,
  required InventoryDocumentType type,
  required List<Map<String, dynamic>> warehouses,
  required List<Map<String, dynamic>> storageLocations,
  Map<String, dynamic>? sourceDocument,
  bool editExisting = false,
  bool readOnly = false,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => InventoryDocumentDialog(
        service: service,
        type: type,
        warehouses: warehouses,
        storageLocations: storageLocations,
        sourceDocument: sourceDocument,
        editExisting: editExisting,
        readOnly: readOnly,
      ),
    ),
  );
}

class InventoryDocumentDialog extends StatefulWidget {
  final StockService service;
  final InventoryDocumentType type;
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> storageLocations;
  final Map<String, dynamic>? sourceDocument;
  final bool editExisting;
  final bool readOnly;

  const InventoryDocumentDialog({
    super.key,
    required this.service,
    required this.type,
    required this.warehouses,
    required this.storageLocations,
    this.sourceDocument,
    this.editExisting = false,
    this.readOnly = false,
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
        if (widget.readOnly) return 'View Quotation';
        return widget.editExisting ? 'Edit Quotation' : 'Create Quotation';
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
  String get _documentDateKey {
    if (_isQuotation) return 'quotation_date';
    if (_isPurchaseOrder || _isSalesOrder) return 'order_date';
    return 'receipt_date';
  }
  String get _secondaryDateKey {
    if (_isQuotation) return 'valid_until';
    if (_isPurchaseOrder) return 'expected_delivery_date';
    if (_isSalesOrder) return 'requested_delivery_date';
    return 'receipt_date';
  }
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
    _notesController.text = widget.editExisting
        ? _text(widget.sourceDocument?['notes'])
        : widget.sourceDocument == null
            ? ''
            : 'Created from ${_sourceNumber(widget.sourceDocument!)}';
    if (widget.editExisting && widget.sourceDocument != null) {
      _documentDate = _parseDate(widget.sourceDocument![_documentDateKey]) ?? DateTime.now();
      _secondaryDate = _parseDate(widget.sourceDocument![_secondaryDateKey]);
    }
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
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(_title),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: widget.readOnly ? null : [
          if (compact)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                tooltip: _saveActionLabel,
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 19),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saveActionLabel),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 1200
                ? 32.0
                : constraints.maxWidth >= 700
                    ? 24.0
                    : 16.0;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      24,
                      horizontalPadding,
                      36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: IgnorePointer(
                          ignoring: widget.readOnly,
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDocumentOverviewCard(colorScheme),
                            const SizedBox(height: 24),
                            _buildSectionCard(
                              icon: _isCustomerDocument
                                  ? Icons.person_outline_rounded
                                  : Icons.local_shipping_outlined,
                              title: _partnerLabel,
                              subtitle: _isCustomerDocument
                                  ? 'Select the customer for this document.'
                                  : 'Select the supplier for this document.',
                              child: _buildPartnerSearch(),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Icons.description_outlined,
                              title: _documentDetailsTitle,
                              subtitle: _documentDetailsSubtitle,
                              child: _buildGeneralDetails(),
                            ),
                            const SizedBox(height: 20),
                            _buildLineSection(),
                            const SizedBox(height: 20),
                            _buildNotesSection(),
                          ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomSummary(totals, colorScheme),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _saveActionLabel {
    if (_isGoodsReceipt) return 'Receive Items';
    if (_isQuotation) return widget.editExisting ? 'Update Quotation' : 'Create Quotation';
    if (_isPurchaseOrder) return 'Create Purchase Order';
    return 'Create Sales Order';
  }

  String get _documentDetailsTitle {
    if (_isQuotation) return 'Quotation details';
    if (_isPurchaseOrder) return 'Purchase order details';
    if (_isGoodsReceipt) return 'Goods receipt details';
    return 'Sales order details';
  }

  String get _documentDetailsSubtitle =>
      'Capture the document reference, dates and fulfilment details.';

  Widget _buildDocumentOverviewCard(ColorScheme colorScheme) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withOpacity(0.75),
              colorScheme.primaryContainer.withOpacity(0.28),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_iconForType(), color: colorScheme.onPrimary, size: 26),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _documentHeroTitle,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _documentHeroSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String get _documentHeroTitle {
    switch (widget.type) {
      case InventoryDocumentType.quotation:
        return widget.editExisting ? 'Quotation ${_sourceNumber(widget.sourceDocument ?? const {})}' : 'New customer quotation';
      case InventoryDocumentType.purchaseOrder:
        return 'New supplier purchase order';
      case InventoryDocumentType.goodsReceipt:
        return widget.sourceDocument == null
            ? 'New goods receipt'
            : 'Receive purchase order';
      case InventoryDocumentType.salesOrder:
        return 'New customer sales order';
    }
  }

  String get _documentHeroSubtitle {
    switch (widget.type) {
      case InventoryDocumentType.quotation:
        if (widget.readOnly) {
          return 'Review the customer, validity, quotation lines, VAT and totals. This quotation has already been converted and is read-only.';
        }
        return widget.editExisting
            ? 'Review or update the customer, validity, quotation lines, VAT and totals.'
            : 'Prepare a professional quotation with customer, validity, product lines, VAT and totals.';
      case InventoryDocumentType.purchaseOrder:
        return 'Capture the supplier, receiving destination, ordered items, tax and total commitment.';
      case InventoryDocumentType.goodsReceipt:
        return 'Record the stock received and the warehouse location where it must be handled.';
      case InventoryDocumentType.salesOrder:
        return 'Capture the customer order, delivery details, products, pricing, VAT and totals.';
    }
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildGeneralDetails() => Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 280,
            child: TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: _referenceLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: _buildDateField(
              _isGoodsReceipt ? 'Receipt Date' : 'Document Date',
              _documentDate,
              (date) => setState(() => _documentDate = date),
            ),
          ),
          SizedBox(
            width: 240,
            child: _buildDateField(
              _secondaryDateLabel,
              _secondaryDate,
              (date) => setState(() => _secondaryDate = date),
              nullable: true,
            ),
          ),
          if (_isPurchaseOrder || _isGoodsReceipt || _isSalesOrder)
            SizedBox(width: 290, child: _warehouseDropdown()),
          if (_isPurchaseOrder || _isGoodsReceipt)
            SizedBox(
              width: 290,
              child: _locationDropdown(
                label: _isPurchaseOrder ? 'Receiving Location' : 'Storage Location',
              ),
            ),
        ],
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

  Widget _warehouseDropdown() => SearchableDropdownFormField<String>(
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
    return SearchableDropdownFormField<String>(
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

  Widget _buildLineSection() => _buildSectionCard(
        icon: Icons.list_alt_rounded,
        title: 'Line items',
        subtitle:
            'Select a product or service, then confirm the description, quantity and pricing.',
        trailing: FilledButton.tonalIcon(
          onPressed: _addLine,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add item'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            _lines.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == _lines.length - 1 ? 0 : 14,
              ),
              child: _buildLineRow(index),
            ),
          ),
        ),
      );

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    final colorScheme = Theme.of(context).colorScheme;
    final subtotal = _lineSubtotal(line);
    final vat = subtotal * (_toDouble(line.taxRateController.text) / 100);
    final total = subtotal + vat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.85),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final product = _productSearch(line);
          final description = TextFormField(
            controller: line.descriptionController,
            decoration: _inputDecoration(
              label: 'Description',
              hint: _isGoodsReceipt ? 'Item received' : 'Line description',
              icon: Icons.notes_rounded,
            ),
            maxLines: 2,
          );
          final quantity = TextFormField(
            controller: line.quantityController,
            decoration: _inputDecoration(label: 'Quantity'),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (value) => _toDouble(value) <= 0 ? 'Invalid quantity' : null,
          );
          final uom = TextFormField(
            controller: line.uomController,
            decoration: _inputDecoration(label: 'UOM'),
          );
          final unitPrice = TextFormField(
            controller: line.unitPriceController,
            decoration: _inputDecoration(
              label: _isGoodsReceipt ? 'Unit cost' : 'Unit price',
              prefix: 'R ',
            ),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          );
          final taxRate = TextFormField(
            controller: line.taxRateController,
            decoration: _inputDecoration(label: 'VAT', suffix: '%'),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          );
          final batch = TextFormField(
            controller: line.batchController,
            decoration: _inputDecoration(
              label: 'Batch number',
              icon: Icons.qr_code_2_rounded,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Line item',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: _lines.length == 1
                        ? 'At least one item is required'
                        : 'Remove item',
                    onPressed:
                        _lines.length == 1 ? null : () => _removeLine(index),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: product),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: description),
                    const SizedBox(width: 12),
                    SizedBox(width: 100, child: quantity),
                    const SizedBox(width: 12),
                    SizedBox(width: 90, child: uom),
                    const SizedBox(width: 12),
                    SizedBox(width: 145, child: unitPrice),
                    const SizedBox(width: 12),
                    SizedBox(width: 105, child: taxRate),
                  ],
                )
              else ...[
                product,
                const SizedBox(height: 12),
                description,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: quantity),
                    const SizedBox(width: 12),
                    Expanded(child: uom),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: unitPrice),
                    const SizedBox(width: 12),
                    Expanded(child: taxRate),
                  ],
                ),
              ],
              if (_isGoodsReceipt) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: wide ? 300 : null,
                  child: batch,
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.7),
                  ),
                ),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildLineMetric('Subtotal', subtotal),
                    _buildLineMetric('VAT', vat),
                    _buildLineMetric('Line total', total, emphasised: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _productSearch(_InventoryLineDraft line) {
    final colorScheme = Theme.of(context).colorScheme;
    return SearchAnchor(
      searchController: line.productSearchController,
      builder: (context, controller) => SearchBar(
        controller: controller,
        hintText: line.productCode.isEmpty
            ? 'Product or service'
            : line.productCode,
        leading: Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(
          BorderSide(color: colorScheme.outlineVariant),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        onTap: () => controller.openView(),
        onChanged: (_) => controller.openView(),
      ),
      suggestionsBuilder: (context, controller) async {
        final products =
            await widget.service.searchProducts(controller.text.trim());
        if (products.isEmpty) {
          return const [
            ListTile(
              leading: Icon(Icons.search_off_rounded),
              title: Text('No products found'),
            ),
          ];
        }
        return products.take(25).map((product) {
          final price = _productPrice(product);
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.inventory_2_outlined, size: 19),
            ),
            title: Text(
              '${_text(product['code'])} - ${_text(product['description'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    String? prefix,
    String? suffix,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefix,
      suffixText: suffix,
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildLineMetric(
    String label,
    double value, {
    bool emphasised = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'R ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasised ? 14 : 12,
            fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
            color: emphasised ? colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() => _buildSectionCard(
        icon: Icons.notes_rounded,
        title: 'Notes',
        subtitle: 'Add any commercial, delivery or internal notes for this document.',
        child: TextFormField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Optional notes',
            border: OutlineInputBorder(),
          ),
        ),
      );

  Widget _buildBottomSummary(
    Map<String, double> totals,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final summary = Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _buildSummaryMetric('Subtotal', totals['subtotal'] ?? 0),
                _buildSummaryMetric('VAT', totals['tax'] ?? 0),
                _buildSummaryMetric(
                  'Total',
                  totals['total'] ?? 0,
                  emphasised: true,
                ),
              ],
            );
            final Widget saveButton = widget.readOnly
                ? const Chip(
                    avatar: Icon(Icons.lock_outline, size: 18),
                    label: Text('Read only'),
                  )
                : SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 19),
                      label: Text(_saveActionLabel),
                    ),
                  );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            saveButton,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: 24),
                            saveButton,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    double value, {
    bool emphasised = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: emphasised ? 150 : 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'R ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasised ? 19 : 14,
              fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
              color: emphasised ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

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
          if (widget.editExisting && widget.sourceDocument != null) {
            await widget.service.updateQuotation(
              _text(widget.sourceDocument!['id']),
              customerPartnerId: _partnerId,
              customerReference: _referenceController.text.trim(),
              quotationDate: _dateFormat.format(_documentDate),
              validUntil: _secondaryDate == null ? null : _dateFormat.format(_secondaryDate!),
              requestedDeliveryDate: null,
              notes: _notesController.text.trim(),
              lines: validLines.map(_commercialLinePayload).toList(),
            );
          } else {
            await widget.service.createQuotation(
              customerPartnerId: _partnerId,
              customerReference: _referenceController.text.trim(),
              quotationDate: _dateFormat.format(_documentDate),
              validUntil: _secondaryDate == null ? null : _dateFormat.format(_secondaryDate!),
              requestedDeliveryDate: null,
              notes: _notesController.text.trim(),
              lines: validLines.map(_commercialLinePayload).toList(),
            );
          }
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
      _snack(friendlyErrorMessage(e), isError: true);
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

  DateTime? _parseDate(dynamic value) {
    final text = _text(value).trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
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
