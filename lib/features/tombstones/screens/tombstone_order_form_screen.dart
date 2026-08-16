import 'package:flutter/material.dart';
import '../models/tombstone_models.dart';
import '../services/tombstone_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Create Tombstone Order'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (compact)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                tooltip: 'Create tombstone order',
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
                label: const Text('Create Tombstone Order'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDocumentOverviewCard(colorScheme),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _errorBanner(_error!),
                            ],
                            const SizedBox(height: 24),
                            _buildSectionCard(
                              icon: Icons.person_outline_rounded,
                              title: 'Customer & Deceased',
                              subtitle:
                                  'Link the customer, membership and deceased details for this tombstone order.',
                              child: _buildCustomerAndDeceasedSection(),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Icons.place_outlined,
                              title: 'Installation Details',
                              subtitle:
                                  'Capture the cemetery, grave and expected installation information.',
                              child: _buildInstallationSection(),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Funding',
                              subtitle:
                                  'Select how the order will be funded and capture any order-level discount.',
                              child: _buildFundingSection(),
                            ),
                            const SizedBox(height: 20),
                            _buildItemsSection(),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              icon: Icons.notes_outlined,
                              title: 'Notes',
                              subtitle:
                                  'Add any instructions or information that should remain with this order.',
                              child: _field(_notes, 'Notes', maxLines: 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomSummary(colorScheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentOverviewCard(ColorScheme colorScheme) {
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
              Icons.account_balance_outlined,
              color: colorScheme.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New tombstone order',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete the customer and installation details, then add the products or services included in the order.',
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

  Widget _buildCustomerAndDeceasedSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final fields = [
          _field(_customer, 'Customer Partner ID', required: true),
          _field(_membership, 'Membership ID'),
          _field(_deceasedPartner, 'Deceased Partner ID'),
          _field(_deceasedName, 'Deceased Name', required: true),
          _field(_funeralService, 'Linked Funeral Service ID'),
        ];
        if (!wide) {
          return Column(
            children: fields
                .expand((field) => [field, const SizedBox(height: 14)])
                .toList()
              ..removeLast(),
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: fields
              .map((field) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: field))
              .toList(),
        );
      },
    );
  }

  Widget _buildInstallationSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final fieldWidth = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: fieldWidth, child: _field(_cemetery, 'Cemetery')),
            SizedBox(width: fieldWidth, child: _field(_cemeteryArea, 'Cemetery Area')),
            SizedBox(width: fieldWidth, child: _field(_grave, 'Grave Number')),
            SizedBox(width: fieldWidth, child: _field(_salesArea, 'Sales Area')),
            SizedBox(
              width: fieldWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: _expectedInstallationDate ??
                        DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) setState(() => _expectedInstallationDate = date);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expected Installation Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _expectedInstallationDate == null
                        ? 'Not selected'
                        : _expectedInstallationDate!.toIso8601String().split('T').first,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFundingSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final fieldWidth = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: fieldWidth,
              child: SearchableDropdownFormField<String>(
                value: _fundingMethod,
                decoration: const InputDecoration(
                  labelText: 'Funding Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'LAYBY', child: Text('Lay-by')),
                  DropdownMenuItem(value: 'FUNERAL_COVER', child: Text('Funeral Cover')),
                  DropdownMenuItem(value: 'COMBINATION', child: Text('Combination')),
                ],
                onChanged: (value) => setState(() => _fundingMethod = value ?? 'CASH'),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _field(
                _discount,
                'Order Discount (R)',
                keyboardType: TextInputType.number,
                refreshTotals: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemsSection() {
    return _buildSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Order Items',
      subtitle: 'Add the tombstone products and services included in this order.',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _items.add(_OrderItemInput())),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Item'),
      ),
      child: Column(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Item ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        'R ${(_itemTotalCents(item) / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (_items.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remove item',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                              item.dispose();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(item.description, 'Description', required: true),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, itemConstraints) {
                      final wide = itemConstraints.maxWidth >= 760;
                      final width = wide
                          ? (itemConstraints.maxWidth - 36) / 4
                          : itemConstraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: width, child: _field(item.productId, 'Product ID')),
                          SizedBox(width: width, child: _field(item.material, 'Material')),
                          SizedBox(width: width, child: _field(item.colour, 'Colour')),
                          SizedBox(width: width, child: _field(item.dimensions, 'Dimensions')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(item.inscription, 'Inscription', maxLines: 3),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, itemConstraints) {
                      final wide = itemConstraints.maxWidth >= 760;
                      final width = wide
                          ? (itemConstraints.maxWidth - 36) / 4
                          : itemConstraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _field(
                              item.quantity,
                              'Quantity',
                              required: true,
                              keyboardType: TextInputType.number,
                              refreshTotals: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _field(
                              item.unitPrice,
                              'Unit Price (R)',
                              required: true,
                              keyboardType: TextInputType.number,
                              refreshTotals: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _field(
                              item.tax,
                              'Tax (R)',
                              keyboardType: TextInputType.number,
                              refreshTotals: true,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _field(
                              item.discount,
                              'Discount (R)',
                              keyboardType: TextInputType.number,
                              refreshTotals: true,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomSummary(ColorScheme colorScheme) {
    final subtotal = _items.fold<int>(0, (sum, item) {
      final quantity = double.tryParse(item.quantity.text.trim()) ?? 0;
      final unit = _moneyToCents(item.unitPrice.text);
      return sum + (quantity * unit).round();
    });
    final itemTax = _items.fold<int>(0, (sum, item) => sum + _moneyToCents(item.tax.text));
    final itemDiscount = _items.fold<int>(0, (sum, item) => sum + _moneyToCents(item.discount.text));
    final orderDiscount = _moneyToCents(_discount.text);
    final rawTotal = subtotal + itemTax - itemDiscount - orderDiscount;
    final total = rawTotal < 0 ? 0 : rawTotal;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final totals = Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _summaryValue('Subtotal', subtotal),
                      if (itemTax > 0) _summaryValue('Tax', itemTax),
                      if (itemDiscount + orderDiscount > 0)
                        _summaryValue('Discount', -(itemDiscount + orderDiscount)),
                      _summaryValue('Total', total, emphasized: true),
                    ],
                  );
                  final save = SizedBox(
                    height: 46,
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
                      label: const Text('Create Tombstone Order'),
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        totals,
                        const SizedBox(height: 12),
                        save,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: totals),
                      const SizedBox(width: 24),
                      save,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryValue(String label, int cents, {bool emphasized = false}) {
    final negative = cents < 0;
    final amount = cents.abs() / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${negative ? '- ' : ''}R ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasized ? 18 : 14,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  int _itemTotalCents(_OrderItemInput item) {
    final quantity = double.tryParse(item.quantity.text.trim()) ?? 0;
    final subtotal = (quantity * _moneyToCents(item.unitPrice.text)).round();
    final total = subtotal + _moneyToCents(item.tax.text) - _moneyToCents(item.discount.text);
    return total < 0 ? 0 : total;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool refreshTotals = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: refreshTotals ? (_) => setState(() {}) : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? '$label is required'
              : null
          : null,
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
