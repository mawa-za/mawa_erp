import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/models/product_lookup.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../invoicing/screens/invoice_pdf_preview_screen.dart';
import '../models/appointment_service_order.dart';
import '../services/appointment_service_order_service.dart';

class AppointmentServiceOrderScreen extends StatefulWidget {
  const AppointmentServiceOrderScreen({
    super.key,
    required this.serviceOrderId,
  });

  final String serviceOrderId;

  @override
  State<AppointmentServiceOrderScreen> createState() =>
      _AppointmentServiceOrderScreenState();
}

class _AppointmentServiceOrderScreenState
    extends State<AppointmentServiceOrderScreen> {
  final AppointmentServiceOrderService _service =
      AppointmentServiceOrderService();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_ZA',
    symbol: 'R ',
    decimalDigits: 2,
  );

  AppointmentServiceOrder? _order;
  List<AppointmentServiceOrderLine> _lines = [];
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
      final order = results[0] as AppointmentServiceOrder;
      if (!mounted) return;
      setState(() {
        _order = order;
        _products = results[1] as List<ProductLookup>;
        _lines = List<AppointmentServiceOrderLine>.from(order.lines);
        _serviceDate = order.serviceDate ?? DateTime.now();
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

  Future<AppointmentServiceOrder?> _save({bool showMessage = true}) async {
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
        serviceDate: _serviceDate,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        assignedEmployeePartnerId: order.assignedEmployeePartnerId,
        lines: _lines,
      );
      if (!mounted) return saved;
      setState(() {
        _order = saved;
        _lines = List<AppointmentServiceOrderLine>.from(saved.lines);
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

  Future<void> _addOrEditLine({int? index}) async {
    final initial = index == null ? null : _lines[index];
    String? selectedProductId = initial?.productId;
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

    final line = await showDialog<AppointmentServiceOrderLine>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Add Service or Product' : 'Edit Line'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                Navigator.pop(
                  context,
                  AppointmentServiceOrderLine(
                    id: initial?.id,
                    productId: selectedProductId,
                    description: description.text.trim(),
                    quantity: parsedQuantity,
                    unitPriceCents: (parsedPrice * 100).round(),
                    discountCents: (parsedDiscount * 100).round(),
                    taxCents: (parsedTax * 100).round(),
                    employeePartnerId: initial?.employeePartnerId,
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Order ${order.serviceOrderNo}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: constraints.maxWidth > 1400 ? 1400 : constraints.maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(order),
                  const SizedBox(height: 18),
                  _buildOrderDetails(order),
                  const SizedBox(height: 18),
                  _buildLines(),
                  const SizedBox(height: 18),
                  _buildTotals(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving || _readOnly ? null : () => _save(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Service Order'),
              ),
              const Spacer(),
              FilledButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppointmentServiceOrder order) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 32,
          runSpacing: 16,
          children: [
            _info('Customer', order.customerName, Icons.person_outline),
            _info(
              'Appointment',
              order.appointmentNo.isEmpty ? order.appointmentId : order.appointmentNo,
              Icons.event_outlined,
            ),
            _info(
              'Responsible Employee',
              order.assignedEmployeeName,
              Icons.badge_outlined,
            ),
            _info(
              'Order Total',
              _money.format(_totalCents / 100),
              Icons.payments_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value, IconData icon) {
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(AppointmentServiceOrder order) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Execution Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
                      DropdownMenuItem(
                        value: 'CONFIRMED',
                        child: Text('Confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('Cancelled'),
                      ),
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
      ),
    );
  }

  Widget _buildLines() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Services and Products Delivered',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add the actual services, retail products and extras supplied to the customer.',
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _readOnly ? null : _addOrEditLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Line'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No service order lines added.')),
              )
            else
              ...List.generate(_lines.length, (index) {
                final line = _lines[index];
                final total = (line.quantity * line.unitPriceCents).round() -
                    line.discountCents +
                    line.taxCents;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    line.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${line.quantity} × ${_money.format(line.unitPriceCents / 100)}'
                    '${line.discountCents > 0 ? ' • Discount ${_money.format(line.discountCents / 100)}' : ''}'
                    '${line.taxCents > 0 ? ' • Tax ${_money.format(line.taxCents / 100)}' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _money.format(total / 100),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (!_readOnly)
                        IconButton(
                          tooltip: 'Edit line',
                          onPressed: () => _addOrEditLine(index: index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (!_readOnly)
                        IconButton(
                          tooltip: 'Remove line',
                          onPressed: () => setState(() => _lines.removeAt(index)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 420,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _totalRow('Subtotal', _subtotalCents),
                _totalRow('Discount', _discountCents),
                _totalRow('Tax', _taxCents),
                const Divider(height: 24),
                _totalRow('Service Order Total', _totalCents, bold: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, int cents, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money.format(cents / 100), style: style),
        ],
      ),
    );
  }
}
