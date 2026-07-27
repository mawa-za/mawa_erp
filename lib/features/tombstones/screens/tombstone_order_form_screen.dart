import 'package:flutter/material.dart';
import '../models/tombstone_models.dart';
import '../services/tombstone_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class TombstoneOrderFormScreen extends StatefulWidget {
  const TombstoneOrderFormScreen({super.key});

  @override
  State<TombstoneOrderFormScreen> createState() => _TombstoneOrderFormScreenState();
}

class _TombstoneOrderFormScreenState extends State<TombstoneOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TombstoneService();
  final _customer = TextEditingController();
  final _membership = TextEditingController();
  final _deceasedPartner = TextEditingController();
  final _deceasedName = TextEditingController();
  final _funeralService = TextEditingController();
  final _cemetery = TextEditingController();
  final _cemeteryArea = TextEditingController();
  final _grave = TextEditingController();
  final _salesArea = TextEditingController();
  final _notes = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final List<_OrderItemInput> _items = [_OrderItemInput()];
  String _fundingMethod = 'CASH';
  DateTime? _expectedInstallationDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_customer, _membership, _deceasedPartner, _deceasedName, _funeralService, _cemetery, _cemeteryArea, _grave, _salesArea, _notes, _discount]) {
      controller.dispose();
    }
    for (final item in _items) item.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final order = await _service.createOrder({
        'customerPartnerId': _customer.text.trim(),
        'membershipId': _blank(_membership.text),
        'deceasedPartnerId': _blank(_deceasedPartner.text),
        'deceasedName': _deceasedName.text.trim(),
        'funeralServiceId': _blank(_funeralService.text),
        'cemeteryName': _blank(_cemetery.text),
        'cemeteryArea': _blank(_cemeteryArea.text),
        'graveNumber': _blank(_grave.text),
        'salesArea': _blank(_salesArea.text),
        'expectedInstallationDate': _expectedInstallationDate?.toIso8601String().split('T').first,
        'fundingMethod': _fundingMethod,
        'discountCents': _moneyToCents(_discount.text),
        'notes': _blank(_notes.text),
        'items': _items.map((e) => e.toJson()).toList(),
      });
      if (!mounted) return;
      Navigator.of(context).pop<TombstoneOrder>(order);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Tombstone Order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null) _errorBanner(_error!),
            _section('Customer and deceased', [
              _field(_customer, 'Customer Partner ID', required: true),
              _field(_membership, 'Membership ID'),
              _field(_deceasedPartner, 'Deceased Partner ID'),
              _field(_deceasedName, 'Deceased Name', required: true),
              _field(_funeralService, 'Linked Funeral Service ID'),
            ]),
            _section('Cemetery and installation', [
              _field(_cemetery, 'Cemetery'),
              _field(_cemeteryArea, 'Cemetery Area'),
              _field(_grave, 'Grave Number'),
              _field(_salesArea, 'Sales Area'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expected Installation Date'),
                subtitle: Text(_expectedInstallationDate == null ? 'Not selected' : _expectedInstallationDate!.toIso8601String().split('T').first),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: _expectedInstallationDate ?? DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) setState(() => _expectedInstallationDate = date);
                },
              ),
            ]),
            _section('Funding', [
              DropdownButtonFormField<String>(
                value: _fundingMethod,
                decoration: const InputDecoration(labelText: 'Funding Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'LAYBY', child: Text('Lay-by')),
                  DropdownMenuItem(value: 'FUNERAL_COVER', child: Text('Funeral Cover')),
                  DropdownMenuItem(value: 'COMBINATION', child: Text('Combination')),
                ],
                onChanged: (value) => setState(() => _fundingMethod = value ?? 'CASH'),
              ),
              const SizedBox(height: 12),
              _field(_discount, 'Order Discount (R)', keyboardType: TextInputType.number),
            ]),
            _buildItems(),
            _section('Notes', [_field(_notes, 'Notes', maxLines: 4)]),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text('Create Tombstone Order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Order Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_OrderItemInput())),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ]),
            const SizedBox(height: 8),
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Card(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_items.length > 1) IconButton(
                        tooltip: 'Remove item',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () { setState(() { _items.removeAt(index); item.dispose(); }); },
                      ),
                    ]),
                    _field(item.description, 'Description', required: true),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(width: 220, child: _field(item.productId, 'Product ID')),
                      SizedBox(width: 180, child: _field(item.material, 'Material')),
                      SizedBox(width: 180, child: _field(item.colour, 'Colour')),
                      SizedBox(width: 180, child: _field(item.dimensions, 'Dimensions')),
                    ]),
                    const SizedBox(height: 10),
                    _field(item.inscription, 'Inscription', maxLines: 3),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(width: 140, child: _field(item.quantity, 'Quantity', required: true, keyboardType: TextInputType.number)),
                      SizedBox(width: 160, child: _field(item.unitPrice, 'Unit Price (R)', required: true, keyboardType: TextInputType.number)),
                      SizedBox(width: 140, child: _field(item.tax, 'Tax (R)', keyboardType: TextInputType.number)),
                      SizedBox(width: 140, child: _field(item.discount, 'Discount (R)', keyboardType: TextInputType.number)),
                    ]),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        ...children.expand((w) => [w, const SizedBox(height: 12)]),
      ]),
    ),
  );

  Widget _field(TextEditingController controller, String label, {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null : null,
    );
  }

  Widget _errorBanner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 8), Expanded(child: Text(message))]),
  );

  static int _moneyToCents(String value) => ((double.tryParse(value.trim()) ?? 0) * 100).round();
  static String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
}

class _OrderItemInput {
  final productId = TextEditingController();
  final description = TextEditingController();
  final material = TextEditingController();
  final colour = TextEditingController();
  final dimensions = TextEditingController();
  final inscription = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController(text: '0');
  final tax = TextEditingController(text: '0');
  final discount = TextEditingController(text: '0');

  Map<String, dynamic> toJson() => {
    'productId': productId.text.trim().isEmpty ? null : productId.text.trim(),
    'itemType': 'TOMBSTONE',
    'description': description.text.trim(),
    'material': material.text.trim().isEmpty ? null : material.text.trim(),
    'colour': colour.text.trim().isEmpty ? null : colour.text.trim(),
    'dimensions': dimensions.text.trim().isEmpty ? null : dimensions.text.trim(),
    'inscriptionText': inscription.text.trim().isEmpty ? null : inscription.text.trim(),
    'quantity': double.tryParse(quantity.text.trim()) ?? 1,
    'unitPriceCents': _cents(unitPrice.text),
    'taxCents': _cents(tax.text),
    'discountCents': _cents(discount.text),
  };

  void dispose() {
    for (final c in [productId, description, material, colour, dimensions, inscription, quantity, unitPrice, tax, discount]) c.dispose();
  }

  static int _cents(String value) => ((double.tryParse(value.trim()) ?? 0) * 100).round();
}
