import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../../../core/routing/app_routes.dart';
import '../../assets/services/asset_register_service.dart';
import '../models/product_maintenance.dart';
import '../services/product_maintenance_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
  List<ProductTypeDefinition> _productTypes = [];
  List<ProductCategoryDefinition> _categories = [];
  List<FieldOption> _uoms = [];
  List<FieldOption> _pricingTypes = [];
  String? _selectedTypeFilter;
  String? _selectedCategoryFilter;
  String _selectedStatus = 'ALL';
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
      final results = await Future.wait<dynamic>([
        _service.getProductTypes(),
        _service.getCategories(activeOnly: false),
        _loadOptions('UOM', _defaultUoms()),
        _loadOptions('PRICING-TYPE', _defaultPricingTypes()),
      ]);
      _productTypes = results[0] as List<ProductTypeDefinition>;
      _categories = results[1] as List<ProductCategoryDefinition>;
      _uoms = results[2] as List<FieldOption>;
      _pricingTypes = results[3] as List<FieldOption>;
      await _loadProducts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<List<FieldOption>> _loadOptions(String field, List<FieldOption> fallback) async {
    try {
      final options = await _fieldService.getOptionsByField(field);
      if (options.isEmpty) return fallback;
      final byCode = <String, FieldOption>{for (final option in fallback) option.code.toUpperCase(): option};
      for (final option in options) {
        byCode[option.code.toUpperCase()] = option;
      }
      return byCode.values.toList()..sort((a, b) => a.description.compareTo(b.description));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts(
        type: _selectedTypeFilter,
        categoryId: _selectedCategoryFilter,
        query: _searchController.text,
      );
      products.sort((a, b) => a.description.compareTo(b.description));
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  List<ProductCategoryDefinition> get _filterCategories {
    return _categories
        .where((category) => category.active)
        .where((category) => _selectedTypeFilter == null || category.supportsType(_selectedTypeFilter!))
        .toList()
      ..sort((a, b) => a.fullPath.compareTo(b.fullPath));
  }

  List<ProductMaintenanceItem> get _visibleProducts {
    return _products.where((product) {
      if (_selectedStatus == 'ACTIVE' && !product.isActive) return false;
      if (_selectedStatus == 'INACTIVE' && product.isActive) return false;
      return true;
    }).toList();
  }

  Future<void> _openProductDialog({ProductMaintenanceItem? product}) async {
    if (product?.type?.code == 'FUNERAL-PACKAGE' || product?.managedByFuneralPackage == true) {
      context.go(AppRoutes.funeralPackageSetup);
      return;
    }
    final selectableTypes = _productTypes.where((type) => type.code != 'FUNERAL-PACKAGE').toList();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductDialog(
        product: product,
        productTypes: selectableTypes,
        categories: _categories.where((category) => category.active || category.id == product?.primaryCategory?.id).toList(),
        uoms: _uoms,
        pricingTypes: _pricingTypes,
        service: _service,
      ),
    );
    if (saved == true) await _loadProducts();
  }

  Future<void> _openCategoryMaintenance() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryMaintenanceDialog(
        service: _service,
        productTypes: _productTypes,
      ),
    );
    if (changed == true) {
      final categories = await _service.getCategories(activeOnly: false);
      if (mounted) {
        setState(() {
          _categories = categories;
          if (_selectedCategoryFilter != null && !_categories.any((item) => item.id == _selectedCategoryFilter && item.active)) {
            _selectedCategoryFilter = null;
          }
        });
      }
      await _loadProducts();
    }
  }

  Future<void> _confirmDelete(ProductMaintenanceItem product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${product.code} - ${product.description}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteProduct(product.id);
      await _loadProducts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_ZA', symbol: 'R ');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.funeralPackageSetup),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Funeral Packages'),
          ),
          TextButton.icon(
            onPressed: _openCategoryMaintenance,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Categories'),
          ),
          IconButton(onPressed: _loadInitialData, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _productTypes.isEmpty ? null : () => _openProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('New Product'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadProducts(),
                    decoration: const InputDecoration(labelText: 'Search code or description', prefixIcon: Icon(Icons.search)),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedTypeFilter,
                    decoration: const InputDecoration(labelText: 'Product Type'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All product types')),
                      ..._productTypes.map((type) => DropdownMenuItem<String?>(value: type.code, child: Text(type.name))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTypeFilter = value;
                        if (_selectedCategoryFilter != null && !_filterCategories.any((category) => category.id == _selectedCategoryFilter)) {
                          _selectedCategoryFilter = null;
                        }
                      });
                      _loadProducts();
                    },
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedCategoryFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Product Category'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                      ..._filterCategories.map((category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.fullPath, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategoryFilter = value);
                      _loadProducts();
                    },
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ALL', label: Text('All')),
                    ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                    ButtonSegment(value: 'INACTIVE', label: Text('Inactive')),
                  ],
                  selected: {_selectedStatus},
                  onSelectionChanged: (selection) => setState(() => _selectedStatus = selection.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadInitialData)
                    : _visibleProducts.isEmpty
                        ? _EmptyState(onCreate: () => _openProductDialog())
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _visibleProducts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final product = _visibleProducts[index];
                              final typeName = product.type?.description ?? product.type?.code ?? 'Unclassified';
                              final category = product.primaryCategory?.fullPath ?? 'No primary category';
                              return ListTile(
                                leading: CircleAvatar(child: Icon(_productIcon(product.type?.code))),
                                title: Text('${product.code} · ${product.description}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _Tag(label: typeName, icon: Icons.settings_suggest_outlined),
                                      _Tag(label: category, icon: Icons.account_tree_outlined),
                                      _Tag(
                                        label: product.availableForSale ? 'Available for sale' : 'Internal use only',
                                        icon: product.availableForSale ? Icons.point_of_sale : Icons.business_center_outlined,
                                      ),
                                      _Tag(label: currency.format(product.price), icon: Icons.payments_outlined),
                                    ],
                                  ),
                                ),
                                trailing: product.type?.code == 'FUNERAL-PACKAGE' || product.managedByFuneralPackage
                                    ? FilledButton.tonalIcon(
                                        onPressed: () => context.go(AppRoutes.funeralPackageSetup),
                                        icon: const Icon(Icons.inventory_2_outlined),
                                        label: const Text('Manage Package'),
                                      )
                                    : Wrap(
                                        children: [
                                          IconButton(onPressed: () => _openProductDialog(product: product), tooltip: 'Edit', icon: const Icon(Icons.edit_outlined)),
                                          IconButton(onPressed: () => _confirmDelete(product), tooltip: 'Delete', icon: const Icon(Icons.delete_outline)),
                                        ],
                                      ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  IconData _productIcon(String? type) {
    switch (type) {
      case 'CONSUMABLE':
        return Icons.cleaning_services_outlined;
      case 'SERVICE':
        return Icons.handyman_outlined;
      case 'ASSET':
        return Icons.laptop_mac_outlined;
      case 'FUNERAL-PACKAGE':
        return Icons.inventory_2_outlined;
      case 'TOMBSTONE':
        return Icons.account_balance_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  List<FieldOption> _defaultUoms() => [
        FieldOption(field: 'UOM', code: 'EA', type: 'TENANT', description: 'Each', validFrom: '', validTo: ''),
        FieldOption(field: 'UOM', code: 'L', type: 'TENANT', description: 'Litre', validFrom: '', validTo: ''),
        FieldOption(field: 'UOM', code: 'KG', type: 'TENANT', description: 'Kilogram', validFrom: '', validTo: ''),
        FieldOption(field: 'UOM', code: 'HOUR', type: 'TENANT', description: 'Hour', validFrom: '', validTo: ''),
      ];

  List<FieldOption> _defaultPricingTypes() => [
        FieldOption(field: 'PRICING-TYPE', code: 'SELLING-PRICE', type: 'TENANT', description: 'Selling Price', validFrom: '', validTo: ''),
      ];
}

class _ProductDialog extends StatefulWidget {
  final ProductMaintenanceItem? product;
  final List<ProductTypeDefinition> productTypes;
  final List<ProductCategoryDefinition> categories;
  final List<FieldOption> uoms;
  final List<FieldOption> pricingTypes;
  final ProductMaintenanceService service;

  const _ProductDialog({
    required this.product,
    required this.productTypes,
    required this.categories,
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
  late final TextEditingController _barcodesController;
  String? _typeCode;
  String? _categoryId;
  String? _uomCode;
  String? _pricingTypeCode;
  bool _availableForSale = true;
  bool _saving = false;
  final AssetRegisterService _assetService = AssetRegisterService();
  List<Map<String, dynamic>> _assets = const [];
  final Map<String, int> _assetCapacities = <String, int>{};
  final Map<String, String?> _assetNotes = <String, String?>{};
  bool _assetsLoading = false;

  ProductTypeDefinition? get _selectedType {
    for (final type in widget.productTypes) {
      if (type.code == _typeCode) return type;
    }
    return null;
  }

  List<ProductCategoryDefinition> get _availableCategories {
    if (_typeCode == null) return const [];
    return widget.categories.where((category) => category.active && category.supportsType(_typeCode!)).toList()
      ..sort((a, b) => a.fullPath.compareTo(b.fullPath));
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _codeController = TextEditingController(text: product?.code ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(text: product == null || product.price == 0 ? '' : product.price.toStringAsFixed(2));
    _barcodesController = TextEditingController(text: product?.barcodes.join(', ') ?? '');
    _typeCode = product == null
        ? (widget.productTypes.isEmpty ? null : widget.productTypes.first.code)
        : (widget.productTypes.any((item) => item.code == product.type?.code) ? product.type?.code : null);
    _categoryId = product?.primaryCategory?.id;
    _uomCode = product?.baseUnitOfMeasure?.code ?? (widget.uoms.isEmpty ? 'EA' : widget.uoms.first.code);
    _pricingTypeCode = product?.pricingType ?? (widget.pricingTypes.isEmpty ? 'SELLING-PRICE' : widget.pricingTypes.first.code);
    _availableForSale = product?.availableForSale ?? _selectedType?.defaultAvailableForSale ?? true;
    _loadHireAssets();
  }

  Future<void> _loadHireAssets() async {
    setState(() => _assetsLoading = true);
    try {
      final assets = await _assetService.list();
      if (widget.product != null && widget.product!.type?.code == 'SERVICE') {
        final links = await widget.service.getLinkedAssets(widget.product!.id);
        for (final link in links.where((item) => item.active)) {
          _assetCapacities[link.assetId] = link.capacity;
          _assetNotes[link.assetId] = link.notes;
        }
      }
      if (mounted) setState(() => _assets = assets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to load hire assets: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _assetsLoading = false);
    }
  }

  Map<String, dynamic>? _assetById(String id) {
    for (final asset in _assets) {
      if ((asset['id'] ?? '').toString() == id) return asset;
    }
    return null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _barcodesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final price = double.parse(_priceController.text.replaceAll(',', '.'));
      String productId;
      if (widget.product == null) {
        final created = await widget.service.createProduct(
          code: _codeController.text,
          description: _descriptionController.text,
          type: _typeCode!,
          categoryId: _categoryId!,
          availableForSale: _availableForSale,
          uom: _uomCode!,
          price: price,
          pricingType: _pricingTypeCode ?? 'SELLING-PRICE',
        );
        productId = created.id;
      } else {
        productId = widget.product!.id;
        await widget.service.updateProduct(
          id: productId,
          code: _codeController.text,
          description: _descriptionController.text,
          type: _typeCode!,
          categoryId: _categoryId!,
          availableForSale: _availableForSale,
          uom: _uomCode!,
          price: price,
          pricingType: _pricingTypeCode ?? 'SELLING-PRICE',
        );
      }
      final barcodes = _barcodesController.text
          .split(RegExp(r'[,;\n]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      await widget.service.replaceBarcodes(productId, barcodes);
      if (_typeCode == 'SERVICE') {
        final links = _assetCapacities.entries.map((entry) {
          final asset = _assetById(entry.key) ?? const <String, dynamic>{};
          return ProductAssetLink(
            assetId: entry.key,
            assetNo: (asset['asset_no'] ?? '').toString(),
            assetName: (asset['name'] ?? '').toString(),
            capacity: entry.value,
            reservedQuantity: 0,
            availableCapacity: entry.value,
            active: true,
            available: true,
            status: (asset['status'] ?? 'ACTIVE').toString(),
            condition: (asset['condition_status'] ?? 'GOOD').toString(),
            notes: _assetNotes[entry.key],
          );
        }).toList();
        await widget.service.replaceLinkedAssets(productId, links);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _selectedType;
    return AlertDialog(
      title: Text(widget.product == null ? 'New Product' : 'Edit Product'),
      content: SizedBox(
        width: 650,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Product Code'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Product code is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Description is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (widget.product != null && _typeCode == null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'This legacy product uses type ${widget.product?.type?.code ?? 'UNKNOWN'}. Select one of the supported product types and a primary category before saving.',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: _typeCode,
                  decoration: const InputDecoration(
                    labelText: 'Product Type',
                    helperText: 'Fixed system behaviour; tenants cannot add product types.',
                  ),
                  items: widget.productTypes.map((item) => DropdownMenuItem(value: item.code, child: Text(item.name))).toList(),
                  onChanged: (value) {
                    setState(() {
                      _typeCode = value;
                      if (_categoryId != null && !_availableCategories.any((category) => category.id == _categoryId)) {
                        _categoryId = null;
                      }
                      final selected = _selectedType;
                      if (widget.product == null && selected != null) {
                        _availableForSale = selected.defaultAvailableForSale;
                      }
                      if (value == 'SERVICE' && _assets.isEmpty && !_assetsLoading) {
                        _loadHireAssets();
                      }
                    });
                  },
                  validator: (value) => value == null ? 'Product type is required' : null,
                ),
                if (type != null) ...[
                  const SizedBox(height: 10),
                  _ProductBehaviourCard(type: type),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _availableCategories.any((item) => item.id == _categoryId) ? _categoryId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Product Category',
                    helperText: 'Tenant-configurable classification used for search, pricing and reporting.',
                  ),
                  items: _availableCategories
                      .map((category) => DropdownMenuItem(value: category.id, child: Text(category.fullPath, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) => value == null ? 'Product category is required' : null,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for external sale'),
                  subtitle: Text(
                    _typeCode == 'CONSUMABLE'
                        ? 'Consumables may be internal-only or saleable.'
                        : 'Controls whether this item can be selected in customer sales documents.',
                  ),
                  value: _availableForSale,
                  onChanged: (value) => setState(() => _availableForSale = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _uomCode,
                        decoration: const InputDecoration(labelText: 'Base Unit of Measure'),
                        items: _fieldItems(widget.uoms),
                        onChanged: (value) => setState(() => _uomCode = value),
                        validator: (value) => value == null ? 'UOM is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _pricingTypeCode,
                        decoration: const InputDecoration(labelText: 'Pricing Type'),
                        items: _fieldItems(widget.pricingTypes),
                        onChanged: (value) => setState(() => _pricingTypeCode = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Selling Price', prefixText: 'R '),
                        validator: (value) {
                          final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
                          if (amount == null) return 'Valid price is required';
                          if (amount < 0) return 'Price cannot be negative';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_typeCode == 'SERVICE') ...[
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reusable assets for this service', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text('Link the actual vehicles or equipment that can fulfil this customer-facing service. Capacity supports sets such as 100 chairs.'),
                          const SizedBox(height: 12),
                          if (_assetsLoading) const LinearProgressIndicator() else DropdownButtonFormField<String>(
                            value: null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Add operational asset'),
                            items: _assets
                                .where((asset) {
                                  final id = (asset['id'] ?? '').toString();
                                  final status = (asset['status'] ?? '').toString().toUpperCase();
                                  final condition = (asset['condition_status'] ?? '').toString().toUpperCase();
                                  return id.isNotEmpty &&
                                      !_assetCapacities.containsKey(id) &&
                                      status == 'ACTIVE' &&
                                      !const {'DAMAGED', 'POOR', 'LOST'}.contains(condition);
                                })
                                .map((asset) => DropdownMenuItem<String>(
                                      value: (asset['id'] ?? '').toString(),
                                      child: Text('${asset['asset_no'] ?? ''} - ${asset['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (assetId) {
                              if (assetId == null || assetId.isEmpty) return;
                              setState(() => _assetCapacities[assetId] = 1);
                            },
                          ),
                          const SizedBox(height: 8),
                          ..._assetCapacities.entries.map((entry) {
                            final asset = _assetById(entry.key) ?? const <String, dynamic>{};
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${asset['asset_no'] ?? entry.key} - ${asset['name'] ?? 'Asset'}'),
                              subtitle: Text('Status: ${asset['status'] ?? 'ACTIVE'} • Condition: ${asset['condition_status'] ?? 'GOOD'}'),
                              leading: SizedBox(
                                width: 90,
                                child: TextFormField(
                                  key: ValueKey('capacity-${entry.key}-${entry.value}'),
                                  initialValue: entry.value.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Capacity'),
                                  validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Required' : null,
                                  onChanged: (value) {
                                    final capacity = int.tryParse(value);
                                    if (capacity != null && capacity > 0) _assetCapacities[entry.key] = capacity;
                                  },
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove link',
                                icon: const Icon(Icons.link_off_outlined),
                                onPressed: () => setState(() {
                                  _assetCapacities.remove(entry.key);
                                  _assetNotes.remove(entry.key);
                                }),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _barcodesController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Barcodes',
                    hintText: 'Enter one or more barcodes separated by commas',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _fieldItems(List<FieldOption> options) {
    return options
        .map((option) => DropdownMenuItem(value: option.code, child: Text(option.description.isEmpty ? option.code : option.description)))
        .toList();
  }
}

class _ProductBehaviourCard extends StatelessWidget {
  final ProductTypeDefinition type;
  const _ProductBehaviourCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final rules = <String>[
      if (type.stockControlled) 'Stock controlled' else 'Non-stock',
      if (type.canBeReceived) 'Goods receipt enabled',
      if (type.canBePutAway) 'Putaway enabled',
      if (type.consumedOnIssue) 'Consumed on issue',
      if (type.returnable) 'Returnable',
      if (type.assetTracked) 'Asset register tracking',
      if (type.bundle) 'Bundle composition required',
      if (type.specialisedWorkflow) 'Specialised workflow',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type.description),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: rules.map((rule) => Chip(label: Text(rule))).toList()),
          ],
        ),
      ),
    );
  }
}

class _CategoryMaintenanceDialog extends StatefulWidget {
  final ProductMaintenanceService service;
  final List<ProductTypeDefinition> productTypes;
  const _CategoryMaintenanceDialog({required this.service, required this.productTypes});

  @override
  State<_CategoryMaintenanceDialog> createState() => _CategoryMaintenanceDialogState();
}

class _CategoryMaintenanceDialogState extends State<_CategoryMaintenanceDialog> {
  List<ProductCategoryDefinition> _categories = [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.service.getCategories(activeOnly: false);
      if (mounted) setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit([ProductCategoryDefinition? category]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryEditorDialog(
        category: category,
        categories: _categories,
        productTypes: widget.productTypes,
        service: widget.service,
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _deactivate(ProductCategoryDefinition category) async {
    try {
      await widget.service.deactivateCategory(category.id);
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Product Categories'),
      content: SizedBox(
        width: 820,
        height: 560,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Categories are tenant configurable and support parent-child relationships. Product types remain fixed system behaviour.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final category = _categories[index];
                            final typeMatches = widget.productTypes.where((type) => type.code == category.productType);
                            final String? typeName = typeMatches.isEmpty ? null : typeMatches.first.name;
                            return ListTile(
                              leading: Icon(category.active ? Icons.account_tree_outlined : Icons.block_outlined),
                              title: Text(category.fullPath),
                              subtitle: Text('${category.code}${typeName == null ? ' · Any compatible type' : ' · $typeName'}'),
                              enabled: category.active,
                              trailing: Wrap(
                                children: [
                                  IconButton(onPressed: () => _edit(category), icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                                  if (category.active)
                                    IconButton(onPressed: () => _deactivate(category), icon: const Icon(Icons.archive_outlined), tooltip: 'Deactivate'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _changed), child: const Text('Close')),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('New Category')),
      ],
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  final ProductCategoryDefinition? category;
  final List<ProductCategoryDefinition> categories;
  final List<ProductTypeDefinition> productTypes;
  final ProductMaintenanceService service;

  const _CategoryEditorDialog({
    required this.category,
    required this.categories,
    required this.productTypes,
    required this.service,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortController;
  String? _parentId;
  String? _productType;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _codeController = TextEditingController(text: category?.code ?? '');
    _nameController = TextEditingController(text: category?.name ?? '');
    _descriptionController = TextEditingController(text: category?.description ?? '');
    _sortController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    _parentId = category?.parentId;
    _productType = category?.productType;
    _active = category?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.category == null) {
        await widget.service.createCategory(
          code: _codeController.text,
          name: _nameController.text,
          description: _descriptionController.text,
          parentId: _parentId,
          productType: _productType,
          sortOrder: int.tryParse(_sortController.text) ?? 0,
        );
      } else {
        await widget.service.updateCategory(
          category: widget.category!,
          code: _codeController.text,
          name: _nameController.text,
          description: _descriptionController.text,
          parentId: _parentId,
          productType: _productType,
          active: _active,
          sortOrder: int.tryParse(_sortController.text) ?? 0,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = widget.categories
        .where((category) => category.id != widget.category?.id && (category.active || category.id == _parentId))
        .toList()
      ..sort((a, b) => a.fullPath.compareTo(b.fullPath));
    final selectedParents = parentOptions.where((category) => category.id == _parentId);
    final inheritedProductType = selectedParents.isEmpty ? null : selectedParents.first.productType;
    return AlertDialog(
      title: Text(widget.category == null ? 'New Product Category' : 'Edit Product Category'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                  onChanged: (value) {
                    if (widget.category == null && _codeController.text.trim().isEmpty) {
                      _codeController.text = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
                    }
                  },
                  validator: (value) => value == null || value.trim().isEmpty ? 'Category name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Category Code'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Category code is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _parentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Parent Category'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Root category')),
                    ...parentOptions.map((parent) => DropdownMenuItem<String?>(value: parent.id, child: Text(parent.fullPath))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _parentId = value;
                      final matches = parentOptions.where((item) => item.id == value);
                      final parent = matches.isEmpty ? null : matches.first;
                      if (parent?.productType != null) _productType = parent!.productType;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: inheritedProductType ?? _productType,
                  decoration: InputDecoration(
                    labelText: 'Applicable Product Type',
                    helperText: inheritedProductType == null
                        ? 'Leave blank when the category can classify more than one product type.'
                        : 'Inherited from the selected parent category.',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Any compatible product type')),
                    ...widget.productTypes.map((type) => DropdownMenuItem<String?>(value: type.code, child: Text(type.name))),
                  ],
                  onChanged: inheritedProductType == null ? (value) => setState(() => _productType = value) : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort Order'),
                ),
                if (widget.category != null)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Tag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)]),
    );
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
          const Icon(Icons.inventory_2_outlined, size: 56),
          const SizedBox(height: 12),
          const Text('No products found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Create a product and classify it by type and category.'),
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
            const Text('Could not load product data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
