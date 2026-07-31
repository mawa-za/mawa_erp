import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/funeral_api.dart';
import '../../data/models/funeral_package_dto.dart';
import '../widgets/funeral_money_text.dart';
import '../../../../core/models/product_lookup.dart';
import '../../../../core/services/product_lookup_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralPackageSetupPage extends StatefulWidget {
  const FuneralPackageSetupPage({super.key});

  @override
  State<FuneralPackageSetupPage> createState() => _FuneralPackageSetupPageState();
}

class _FuneralPackageSetupPageState extends State<FuneralPackageSetupPage> {
  final FuneralApi _api = FuneralApi();
  List<FuneralPackageDto> _packages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final packages = await _api.getFuneralPackages(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _openPackageDialog([FuneralPackageDto? package]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _FuneralPackageDialog(package: package),
    );

    if (saved == true && mounted) {
      await _loadPackages();
    }
  }

  Future<void> _deactivatePackage(FuneralPackageDto package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate package?'),
        content: Text('This will hide ${package.name} from new funeral service requests.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteFuneralPackage(package.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funeral package deactivated')));
      await _loadPackages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to deactivate package: $e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Package Setup'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPackages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPackageDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Package'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadPackages, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('No funeral packages configured yet'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openPackageDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Funeral Package'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final package = _packages[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(package.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          if (package.productCode.isNotEmpty)
                            Text(package.productCode, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(package.active ? 'Active' : 'Inactive'),
                      avatar: Icon(package.active ? Icons.check_circle : Icons.block, size: 18),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openPackageDialog(package);
                        if (value == 'deactivate') _deactivatePackage(package);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (package.active) const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FuneralMoneyText(cents: package.basePriceCents),
                    const SizedBox(width: 10),
                    Chip(label: Text(package.pricingMode == 'FIXED_PRICE' ? 'Fixed package price' : 'Total of items')),
                  ],
                ),
                if (package.inclusions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: package.inclusions.map((item) => Chip(label: Text(item))).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FuneralPackageDialog extends StatefulWidget {
  const _FuneralPackageDialog({this.package});

  final FuneralPackageDto? package;

  @override
  State<_FuneralPackageDialog> createState() => _FuneralPackageDialogState();
}

class _FuneralPackageDialogState extends State<_FuneralPackageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _api = FuneralApi();
  late final TextEditingController _productCodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _fixedPriceController;
  String _pricingMode = 'ITEM_TOTAL';
  List<ProductLookup> _catalog = [];
  late List<FuneralPackageProductDto> _products;
  bool _loadingProducts = true;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    _productCodeController = TextEditingController(text: package?.productCode ?? '');
    _nameController = TextEditingController(text: package?.name ?? '');
    _pricingMode = package?.pricingMode ?? 'ITEM_TOTAL';
    _fixedPriceController = TextEditingController(
      text: package == null ? '' : (package.basePriceCents / 100).toStringAsFixed(2),
    );
    _products = List.of(package?.products ?? const []);
    _loadProducts();
    _active = package?.active ?? true;
  }

  Future<void> _loadProducts() async {
    try {
      final service = ProductLookupService();
      final results = await Future.wait([
        service.getProducts(type: 'PHYSICAL-PRODUCT', forceRefresh: true, strictType: true),
        service.getProducts(type: 'CONSUMABLE', forceRefresh: true, strictType: true),
        service.getProducts(type: 'SERVICE', forceRefresh: true, strictType: true),
        service.getProducts(type: 'TOMBSTONE', forceRefresh: true, strictType: true),
      ]);
      final byId = <String, ProductLookup>{};
      for (final product in results.expand((items) => items)) {
        final key = product.id.isNotEmpty ? product.id : product.code;
        if (key.isNotEmpty) byId[key] = product;
      }
      final catalog = byId.values.toList()
        ..sort((a, b) => a.description.toLowerCase().compareTo(b.description.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Failed to load products: $e'))),
      );
    }
  }

  @override
  void dispose() {
    _productCodeController.dispose();
    _nameController.dispose();
    _fixedPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    if (_products.isEmpty) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one product'))); return; }
    final fixedPriceCents = ((double.tryParse(_fixedPriceController.text.trim()) ?? 0) * 100).round();
    if (_pricingMode == 'FIXED_PRICE' && fixedPriceCents <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a fixed package price greater than zero')));
      return;
    }

    final package = FuneralPackageDto(
      id: widget.package?.id ?? '',
      productId: widget.package?.productId ?? '',
      productCode: _productCodeController.text.trim(),
      name: _nameController.text.trim(),
      pricingMode: _pricingMode,
      basePriceCents: _pricingMode == 'FIXED_PRICE'
          ? fixedPriceCents
          : _products.fold(0, (sum, item) => sum + item.lineTotalCents),
      inclusions: _products.map((e) => '${e.quantity} x ${e.productDescription}').toList(),
      inclusionsJson: jsonEncode(_products.map((e) => e.toJson()).toList()),
      products: _products,
      active: _active,
    );

    try {
      if (widget.package == null) {
        await _api.createFuneralPackage(package);
      } else {
        await _api.updateFuneralPackage(package);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to save funeral package: $e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.package == null ? 'New Funeral Package' : 'Edit Funeral Package'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _productCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Package product code',
                    helperText: 'Leave blank to generate a code automatically. This is the linked Product Maintenance code.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Package name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Package name is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _pricingMode,
                  decoration: const InputDecoration(
                    labelText: 'Package pricing',
                    helperText: 'Choose a fixed package price or calculate the package from included items.',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'FIXED_PRICE', child: Text('Fixed package price')),
                    DropdownMenuItem(value: 'ITEM_TOTAL', child: Text('Price made up of included items')),
                  ],
                  onChanged: (value) => setState(() => _pricingMode = value ?? 'ITEM_TOTAL'),
                ),
                if (_pricingMode == 'FIXED_PRICE') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fixedPriceController,
                    decoration: const InputDecoration(labelText: 'Fixed package price', prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Enter a valid fixed price' : null,
                  ),
                ],
                const SizedBox(height: 12),
                if (_loadingProducts) const LinearProgressIndicator() else DropdownButtonFormField<ProductLookup>(
                  decoration: const InputDecoration(labelText: 'Add package component', helperText: 'Only Physical Products, Consumables, Services and Tombstones are allowed.'),
                  items: _catalog.map((p)=>DropdownMenuItem(value:p,child:Text('${p.code} - ${p.description}'))).toList(),
                  onChanged: (p) { if (p == null || _products.any((e)=>e.productId==p.id)) return; setState(()=>_products.add(FuneralPackageProductDto(productId:p.id,productCode:p.code,productDescription:p.description,quantity:1,unitPriceCents:p.priceCents))); },
                ),
                const SizedBox(height: 12),
                ..._products.asMap().entries.map((entry) { final i=entry.key; final item=entry.value; return ListTile(
                  contentPadding: EdgeInsets.zero, title: Text(item.productDescription), subtitle: Text('R ${(item.unitPriceCents/100).toStringAsFixed(2)} each'),
                  leading: SizedBox(width:70,child:TextFormField(initialValue:item.quantity.toString(),keyboardType:TextInputType.number,onChanged:(v){final q=int.tryParse(v)??0;_products[i]=FuneralPackageProductDto(productId:item.productId,productCode:item.productCode,productDescription:item.productDescription,quantity:q,unitPriceCents:item.unitPriceCents);})),
                  trailing: IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>_products.removeAt(i))),
                );}),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _pricingMode == 'FIXED_PRICE'
                        ? 'Included item value: R ${(_products.fold(0, (s, e) => s + e.lineTotalCents) / 100).toStringAsFixed(2)} (not used as package price)'
                        : 'Package total: R ${(_products.fold(0, (s, e) => s + e.lineTotalCents) / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: const Text('Active'),
                  subtitle: const Text('Active packages can be selected on funeral service requests'),
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
