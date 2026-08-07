import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/models/product_lookup.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../invoicing/screens/invoice_pdf_preview_screen.dart';
import '../models/service_order.dart';
import '../services/service_order_service.dart';

class ServiceOrderScreen extends StatefulWidget {
  const ServiceOrderScreen({
    super.key,
    required this.serviceOrderId,
  });

  final String serviceOrderId;

  @override
  State<ServiceOrderScreen> createState() =>
      _ServiceOrderScreenState();
}

class _ServiceOrderScreenState
    extends State<ServiceOrderScreen> {
  final ServiceOrderService _service =
      ServiceOrderService();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_ZA',
    symbol: 'R ',
    decimalDigits: 2,
  );

  ServiceOrder? _order;
  List<ServiceOrderLine> _lines = [];
  List<ProductLookup> _products = [];
  DateTime _serviceDate = DateTime.now();
  String _status = 'DRAFT';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.get(widget.serviceOrderId),
        ProductLookupService().getProducts(),
      ]);
      final order = results[0] as ServiceOrder;
      if (!mounted) return;
      setState(() {
        _order = order;
        _products = results[1] as List<ProductLookup>;
        _lines = List<ServiceOrderLine>.from(order.lines);
        _serviceDate = order.orderDate ?? DateTime.now();
        _status = order.status;
        _locationController.text = order.location;
        _notesController.text = order.notes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  int get _subtotalCents => _lines.fold(
        0,
        (total, line) =>
            total + (line.quantity * line.unitPriceCents).round(),
      );

  int get _discountCents =>
      _lines.fold(0, (total, line) => total + line.discountCents);

  int get _taxCents => _lines.fold(0, (total, line) => total + line.taxCents);

  int get _totalCents =>
      (_subtotalCents - _discountCents + _taxCents)
          .clamp(0, 1 << 62)
          .toInt();

  bool get _readOnly => _order?.isInvoiced == true;

  Future<ServiceOrder?> _save({bool showMessage = true}) async {
    final order = _order;
    if (order == null) return null;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one service or product.'),
        ),
      );
      return null;
    }
    setState(() => _saving = true);
    try {
      final saved = await _service.update(
        id: order.id,
        status: _status,
        orderDate: _serviceDate,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        assignedEmployeePartnerId: order.assignedEmployeePartnerId,
        lines: _lines,
      );
      if (!mounted) return saved;
      setState(() {
        _order = saved;
        _lines = List<ServiceOrderLine>.from(saved.lines);
        _status = saved.status;
      });
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service order saved.')),
        );
      }
      return saved;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Failed to save service order: $error')),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createOrOpenInvoice() async {
    final existingInvoiceId = _order?.invoiceId;
    if (existingInvoiceId != null && existingInvoiceId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoicePdfPreviewScreen(invoiceId: existingInvoiceId),
        ),
      );
      return;
    }

    final saved = await _save(showMessage: false);
    if (saved == null) return;
    setState(() => _saving = true);
    try {
      final invoice = await _service.createInvoice(saved.id);
      final invoiceId = (invoice['id'] ?? '').toString();
      if (!mounted) return;
      if (invoiceId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created, but no invoice id was returned.'),
          ),
        );
        return;
      }
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoicePdfPreviewScreen(invoiceId: invoiceId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage('Failed to invoice service order: $error'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final base = initial ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _enumLabel(String value) => value
      .toLowerCase()
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _addOrEditLine({int? index}) async {
    final initial = index == null ? null : _lines[index];
    String? selectedProductId = initial?.productId;
    String itemType = initial?.itemType ?? 'SERVICE';
    String completionStatus = initial?.completionStatus ?? 'NOT_STARTED';
    DateTime? scheduledStartAt = initial?.scheduledStartAt;
    DateTime? scheduledEndAt = initial?.scheduledEndAt;
    final description = TextEditingController(text: initial?.description ?? '');
    final quantity = TextEditingController(
      text: (initial?.quantity ?? 1).toStringAsFixed(
        (initial?.quantity ?? 1) % 1 == 0 ? 0 : 2,
      ),
    );
    final unitPrice = TextEditingController(
      text: initial == null
          ? ''
          : (initial.unitPriceCents / 100).toStringAsFixed(2),
    );
    final discount = TextEditingController(
      text: initial == null
          ? '0.00'
          : (initial.discountCents / 100).toStringAsFixed(2),
    );
    final tax = TextEditingController(
      text: initial == null
          ? '0.00'
          : (initial.taxCents / 100).toStringAsFixed(2),
    );

    final line = await showDialog<ServiceOrderLine>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Add Service Order Line' : 'Edit Line'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _products.any((product) => product.id == selectedProductId)
                        ? selectedProductId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Service / Product',
                      border: OutlineInputBorder(),
                    ),
                    items: _products
                        .map(
                          (product) => DropdownMenuItem(
                            value: product.id,
                            child: Text(
                              '${product.code} - ${product.description}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedProductId = value);
                      if (value == null) return;
                      final product =
                          _products.firstWhere((item) => item.id == value);
                      description.text = product.description;
                      unitPrice.text =
                          (product.priceCents / 100).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: itemType,
                          decoration: const InputDecoration(
                            labelText: 'Line Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'SERVICE', child: Text('Service')),
                            DropdownMenuItem(value: 'PRODUCT', child: Text('Product')),
                            DropdownMenuItem(value: 'CONSUMABLE', child: Text('Consumable')),
                            DropdownMenuItem(value: 'PACKAGE', child: Text('Package')),
                            DropdownMenuItem(value: 'ASSET', child: Text('Asset')),
                            DropdownMenuItem(value: 'CHARGE', child: Text('Additional Charge')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => itemType = value ?? 'SERVICE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: completionStatus,
                          decoration: const InputDecoration(
                            labelText: 'Completion Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'NOT_STARTED', child: Text('Not Started')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                            DropdownMenuItem(value: 'NOT_REQUIRED', child: Text('Not Required')),
                          ],
                          onChanged: (value) => setDialogState(
                            () => completionStatus = value ?? 'NOT_STARTED',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantity,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: unitPrice,
                          decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            prefixText: 'R ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: discount,
                          decoration: const InputDecoration(
                            labelText: 'Discount',
                            prefixText: 'R ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: tax,
                          decoration: const InputDecoration(
                            labelText: 'Tax',
                            prefixText: 'R ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await _pickDateTime(scheduledStartAt);
                            if (picked != null) {
                              setDialogState(() => scheduledStartAt = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Scheduled Start',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.schedule_outlined),
                            ),
                            child: Text(
                              scheduledStartAt == null
                                  ? 'Not specified'
                                  : DateFormat('dd MMM yyyy HH:mm')
                                      .format(scheduledStartAt!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await _pickDateTime(
                              scheduledEndAt ?? scheduledStartAt,
                            );
                            if (picked != null) {
                              setDialogState(() => scheduledEndAt = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Scheduled End',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.schedule_outlined),
                            ),
                            child: Text(
                              scheduledEndAt == null
                                  ? 'Not specified'
                                  : DateFormat('dd MMM yyyy HH:mm')
                                      .format(scheduledEndAt!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (scheduledStartAt != null || scheduledEndAt != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setDialogState(() {
                          scheduledStartAt = null;
                          scheduledEndAt = null;
                        }),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear line schedule'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedQuantity = double.tryParse(
                  quantity.text.trim().replaceAll(',', '.'),
                );
                final parsedPrice = double.tryParse(
                  unitPrice.text.trim().replaceAll(',', '.'),
                );
                final parsedDiscount = double.tryParse(
                      discount.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                final parsedTax = double.tryParse(
                      tax.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                if (description.text.trim().isEmpty ||
                    parsedQuantity == null ||
                    parsedQuantity <= 0 ||
                    parsedPrice == null ||
                    parsedPrice < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a description, valid quantity and valid unit price.',
                      ),
                    ),
                  );
                  return;
                }
                if (scheduledStartAt != null &&
                    scheduledEndAt != null &&
                    !scheduledEndAt!.isAfter(scheduledStartAt!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scheduled end must be after scheduled start.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  ServiceOrderLine(
                    id: initial?.id,
                    productId: selectedProductId,
                    itemType: itemType,
                    description: description.text.trim(),
                    quantity: parsedQuantity,
                    unitPriceCents: (parsedPrice * 100).round(),
                    discountCents: (parsedDiscount * 100).round(),
                    taxCents: (parsedTax * 100).round(),
                    employeePartnerId: initial?.employeePartnerId,
                    scheduledStartAt: scheduledStartAt,
                    scheduledEndAt: scheduledEndAt,
                    completionStatus: completionStatus,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    tax.dispose();

    if (line == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _pickServiceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null && mounted) setState(() => _serviceDate = date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Order')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text(_error ?? 'Service order could not be loaded.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('Service Order ${order.serviceOrderNo}'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (!_readOnly)
            if (compact)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filled(
                  tooltip: 'Save Service Order',
                  onPressed: _saving ? null : () => _save(),
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
                  onPressed: _saving ? null : () => _save(),
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
                  label: const Text('Save Service Order'),
                ),
              ),
        ],
      ),
      body: LayoutBuilder(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(order),
                          const SizedBox(height: 24),
                          _buildCustomerSection(order, colorScheme),
                          const SizedBox(height: 20),
                          _buildOrderDetails(),
                          const SizedBox(height: 20),
                          _buildLines(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomSummary(order, colorScheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ServiceOrder order) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
            child: Icon(
              Icons.build_circle_outlined,
              color: colorScheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Order ${order.serviceOrderNo}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete the customer and service details, then add the products or services delivered.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              _enumLabel(_status),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(
    ServiceOrder order,
    ColorScheme colorScheme,
  ) {
    return _buildSectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Customer',
      subtitle: 'Customer linked to this service order.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.person_outline_rounded, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (order.primarySourceLabel.isNotEmpty)
                        'Source ${order.primarySourceLabel}',
                      if (order.assignedEmployeeName.isNotEmpty)
                        'Responsible ${order.assignedEmployeeName}',
                    ].join('  •  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return _buildSectionCard(
      icon: Icons.description_outlined,
      title: 'Service execution details',
      subtitle: 'Capture status, service date, location and operational notes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                  ],
                  onChanged: _readOnly
                      ? null
                      : (value) => setState(() => _status = value!),
                ),
              ),
              SizedBox(
                width: 260,
                child: InkWell(
                  onTap: _readOnly ? null : _pickServiceDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Service Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_serviceDate)),
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: TextFormField(
                  controller: _locationController,
                  readOnly: _readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            readOnly: _readOnly,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Operational Notes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLines() {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Line items',
      subtitle:
          'Review the services, products and extras included in this service order.',
      trailing: FilledButton.tonalIcon(
        onPressed: _readOnly ? null : _addOrEditLine,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add item'),
      ),
      child: _lines.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No service order lines added.')),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(_lines.length, (index) {
                final line = _lines[index];
                final subtotal = (line.quantity * line.unitPriceCents).round();
                final total = subtotal - line.discountCents + line.taxCents;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _lines.length - 1 ? 0 : 14,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFCFD),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.85),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withOpacity(0.65),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Line item',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    line.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_readOnly)
                              IconButton(
                                tooltip: 'Edit item',
                                onPressed: () => _addOrEditLine(index: index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            if (!_readOnly)
                              IconButton(
                                tooltip: _lines.length == 1
                                    ? 'At least one item is required'
                                    : 'Remove item',
                                onPressed: _lines.length == 1
                                    ? null
                                    : () => setState(
                                          () => _lines.removeAt(index),
                                        ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _serviceLineFact(
                              'Type',
                              _enumLabel(line.itemType),
                              colorScheme,
                            ),
                            _serviceLineFact(
                              'Status',
                              _enumLabel(line.completionStatus),
                              colorScheme,
                            ),
                            _serviceLineFact(
                              'Quantity',
                              '${line.quantity}',
                              colorScheme,
                            ),
                            _serviceLineFact(
                              'Unit price',
                              _money.format(line.unitPriceCents / 100),
                              colorScheme,
                            ),
                            if (line.scheduledStartAt != null)
                              _serviceLineFact(
                                'Scheduled',
                                DateFormat('dd MMM yyyy HH:mm')
                                    .format(line.scheduledStartAt!),
                                colorScheme,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
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
                              _serviceLineMetric('Subtotal', subtotal),
                              if (line.discountCents > 0)
                                _serviceLineMetric(
                                  'Discount',
                                  line.discountCents,
                                  negative: true,
                                ),
                              _serviceLineMetric('VAT', line.taxCents),
                              _serviceLineMetric(
                                'Line total',
                                total,
                                emphasised: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  Widget _serviceLineFact(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _serviceLineMetric(
    String label,
    int valueCents, {
    bool emphasised = false,
    bool negative = false,
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
          '${negative ? '- ' : ''}${_money.format(valueCents / 100)}',
          style: TextStyle(
            fontSize: emphasised ? 14 : 12,
            fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
            color: emphasised ? colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSummary(
    ServiceOrder order,
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
            final compact = constraints.maxWidth < 760;
            final summary = Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _buildSummaryMetric('Subtotal', _subtotalCents),
                if (_discountCents > 0)
                  _buildSummaryMetric(
                    'Discount',
                    _discountCents,
                    negative: true,
                  ),
                _buildSummaryMetric('VAT', _taxCents),
                _buildSummaryMetric(
                  'Total',
                  _totalCents,
                  emphasised: true,
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (!_readOnly)
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(),
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
                      label: const Text('Save Service Order'),
                    ),
                  ),
                SizedBox(
                  height: 46,
                  child: FilledButton.tonalIcon(
                    onPressed: _saving ||
                            (order.invoiceId == null && _status == 'CANCELLED')
                        ? null
                        : _createOrOpenInvoice,
                    icon: Icon(
                      order.invoiceId == null
                          ? Icons.receipt_long_outlined
                          : Icons.open_in_new,
                    ),
                    label: Text(
                      order.invoiceId == null ? 'Create Invoice' : 'Open Invoice',
                    ),
                  ),
                ),
              ],
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
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: 24),
                            actions,
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
    int cents, {
    bool emphasised = false,
    bool negative = false,
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
            '${negative ? '- ' : ''}${_money.format(cents / 100)}',
            style: TextStyle(
              fontSize: emphasised ? 19 : 14,
              fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
              color: emphasised
                  ? colorScheme.primary
                  : negative
                      ? colorScheme.error
                      : null,
            ),
          ),
        ],
      ),
    );
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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

}
