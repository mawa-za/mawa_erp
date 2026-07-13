import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../models/product_maintenance.dart';
import '../services/product_maintenance_service.dart';

class ProductMaintenanceScreen extends StatefulWidget {
  const ProductMaintenanceScreen({super.key});

  @override
  State<ProductMaintenanceScreen> createState() => _ProductMaintenanceScreenState();
}

class _ProductMaintenanceScreenState extends State<ProductMaintenanceScreen> {
  final ProductMaintenanceService _service = ProductMaintenanceService();
  final FieldService _fieldService = FieldService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductMaintenanceItem> _products = [];
  List<FieldOption> _productTypes = [];
  List<FieldOption> _uoms = [];
  List<FieldOption> _pricingTypes = [];
  String? _selectedTypeFilter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _loadOptions('PRODUCT-TYPE', _defaultProductTypes()),
        _loadOptions('UOM', _defaultUoms()),
        _loadOptions('PRICING-TYPE', _defaultPricingTypes()),
      ]);
      _productTypes = results[0];
      _uoms = results[1];
      _pricingTypes = results[2];
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<FieldOption>> _loadOptions(String field, List<FieldOption> fallback) async {
    try {
      final options = await _fieldService.getOptionsByField(field);
      return options.isEmpty ? fallback : _mergeOptions(options, fallback);
    } catch (_) {
      return fallback;
    }
  }

  List<FieldOption> _mergeOptions(List<FieldOption> primary, List<FieldOption> fallback) {
    final byCode = <String, FieldOption>{};
    for (final option in fallback) {
      byCode[option.code.toUpperCase()] = option;
    }
    for (final option in primary) {
      if (option.code.trim().isNotEmpty) byCode[option.code.toUpperCase()] = option;
    }
    return byCode.values.toList()..sort((a, b) => a.description.compareTo(b.description));
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts(
        type: _selectedTypeFilter,
        query: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openProductDialog({ProductMaintenanceItem? product}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductDialog(
        product: product,
        productTypes: _productTypes,
        uoms: _uoms,
        pricingTypes: _pricingTypes,
        service: _service,
      ),
    );
    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _confirmDelete(ProductMaintenanceItem product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${product.code} - ${product.description}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
      }
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_ZA', symbol: 'R ');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _openProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('New Product'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadProducts(),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedTypeFilter,
                    decoration: const InputDecoration(labelText: 'Product Type'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All product types')),
                      ..._productTypes.map((type) => DropdownMenuItem<String?>(
                            value: type.code,
                            child: Text(type.description.isEmpty ? type.code : type.description),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedTypeFilter = value);
                      _loadProducts();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadInitialData)
                    : _products.isEmpty
                        ? _EmptyState(onCreate: () => _openProductDialog())
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1180
                                  ? 3
                                  : constraints.maxWidth >= 760
                                      ? 2
                                      : 1;
                              final aspectRatio = columns == 1 ? 2.15 : 1.65;

                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: aspectRatio,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: _products.length,
                                itemBuilder: (context, index) {
                                  final product = _products[index];
                                  final colorScheme = Theme.of(context).colorScheme;
                                  return Card(
                                    elevation: 0,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant.withOpacity(0.55),
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _openProductDialog(product: product),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.primaryContainer.withOpacity(0.55),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    Icons.inventory_2_outlined,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        product.description.trim().isEmpty
                                                            ? product.code
                                                            : product.description,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(fontWeight: FontWeight.w700),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        product.code,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  tooltip: 'Product actions',
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _openProductDialog(product: product);
                                                    } else if (value == 'delete') {
                                                      _confirmDelete(product);
                                                    }
                                                  },
                                                  itemBuilder: (_) => const [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.edit_outlined),
                                                          SizedBox(width: 10),
                                                          Text('Edit'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.delete_outline),
                                                          SizedBox(width: 10),
                                                          Text('Delete'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _ProductMetaChip(
                                                  icon: Icons.category_outlined,
                                                  label: _optionLabel(product.type),
                                                ),
                                                _ProductMetaChip(
                                                  icon: Icons.straighten_outlined,
                                                  label: _optionLabel(product.baseUnitOfMeasure),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Text(
                                                  'Selling price',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  currency.format(product.price),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: colorScheme.primary,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _optionLabel(FieldOption? option) {
    if (option == null) return '-';
    return option.description.trim().isEmpty ? option.code : option.description;
  }

  List<FieldOption> _defaultProductTypes() => [
        FieldOption(field: 'PRODUCT-TYPE', code: 'GENERAL', type: 'TENANT', description: 'General', validFrom: '', validTo: ''),
        FieldOption(field: 'PRODUCT-TYPE', code: 'FUNERAL-PACKAGE', type: 'TENANT', description: 'Funeral Package', validFrom: '', validTo: ''),
        FieldOption(field: 'PRODUCT-TYPE', code: 'FUNERAL-EXTRA', type: 'TENANT', description: 'Funeral Extra', validFrom: '', validTo: ''),
      ];

  List<FieldOption> _defaultUoms() => [
        FieldOption(field: 'UOM', code: 'EA', type: 'TENANT', description: 'Each', validFrom: '', validTo: ''),
        FieldOption(field: 'UOM', code: 'UNIT', type: 'TENANT', description: 'Unit', validFrom: '', validTo: ''),
      ];

  List<FieldOption> _defaultPricingTypes() => [
        FieldOption(field: 'PRICING-TYPE', code: 'SELLING-PRICE', type: 'TENANT', description: 'Selling Price', validFrom: '', validTo: ''),
      ];
}

class _ProductMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProductMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  final ProductMaintenanceItem? product;
  final List<FieldOption> productTypes;
  final List<FieldOption> uoms;
  final List<FieldOption> pricingTypes;
  final ProductMaintenanceService service;

  const _ProductDialog({
    this.product,
    required this.productTypes,
    required this.uoms,
    required this.pricingTypes,
    required this.service,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  String? _typeCode;
  String? _uomCode;
  String? _pricingTypeCode;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _codeController = TextEditingController(text: product?.code ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(text: product == null || product.price == 0 ? '' : product.price.toStringAsFixed(2));
    _typeCode = _resolveCode(product?.type?.code, widget.productTypes, fallback: widget.productTypes.isNotEmpty ? widget.productTypes.first.code : 'GENERAL');
    _uomCode = _resolveCode(product?.baseUnitOfMeasure?.code, widget.uoms, fallback: widget.uoms.isNotEmpty ? widget.uoms.first.code : 'EA');
    _pricingTypeCode = _resolveCode(product?.pricingType, widget.pricingTypes, fallback: 'SELLING-PRICE');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _resolveCode(String? code, List<FieldOption> options, {required String fallback}) {
    if (code != null && code.trim().isNotEmpty) {
      final match = options.where((option) => option.code.toUpperCase() == code.toUpperCase()).toList();
      if (match.isNotEmpty) return match.first.code;
      return code;
    }
    return fallback;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
      if (_isEditing) {
        await widget.service.updateProduct(
          id: widget.product!.id,
          code: _codeController.text,
          description: _descriptionController.text,
          type: _typeCode ?? 'GENERAL',
          uom: _uomCode ?? 'EA',
          price: price,
          pricingType: _pricingTypeCode ?? 'SELLING-PRICE',
        );
      } else {
        await widget.service.createProduct(
          code: _codeController.text,
          description: _descriptionController.text,
          type: _typeCode ?? 'GENERAL',
          uom: _uomCode ?? 'EA',
          price: price,
          pricingType: _pricingTypeCode ?? 'SELLING-PRICE',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'New Product'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Product Code'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Product code is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _typeCode,
                  decoration: const InputDecoration(labelText: 'Product Type'),
                  items: _dropdownItems(_typeCode, widget.productTypes),
                  onChanged: (value) => setState(() => _typeCode = value),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Product type is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _uomCode,
                  decoration: const InputDecoration(labelText: 'Base Unit of Measure'),
                  items: _dropdownItems(_uomCode, widget.uoms),
                  onChanged: (value) => setState(() => _uomCode = value),
                  validator: (value) => value == null || value.trim().isEmpty ? 'UOM is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _pricingTypeCode,
                        decoration: const InputDecoration(labelText: 'Pricing Type'),
                        items: _dropdownItems(_pricingTypeCode, widget.pricingTypes),
                        onChanged: (value) => setState(() => _pricingTypeCode = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Selling Price'),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
                          if (parsed == null) return 'Valid price is required';
                          if (parsed < 0) return 'Price cannot be negative';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _dropdownItems(String? currentValue, List<FieldOption> options) {
    final map = <String, String>{};
    for (final option in options) {
      if (option.code.trim().isNotEmpty) {
        map[option.code] = option.description.trim().isEmpty ? option.code : option.description;
      }
    }
    if (currentValue != null && currentValue.trim().isNotEmpty && !map.containsKey(currentValue)) {
      map[currentValue] = currentValue;
    }
    return map.entries
        .map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)))
        .toList();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          const Text('No products found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Create products for invoices, funeral packages and extras.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('New Product')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            const Text('Could not load products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
