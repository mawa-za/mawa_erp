import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/funeral_api.dart';
import '../../data/models/funeral_package_dto.dart';
import '../widgets/funeral_money_text.dart';

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
        _error = e.toString();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate package: $e')));
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
                      child: Text(
                        package.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                FuneralMoneyText(cents: package.basePriceCents),
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
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _inclusionsController;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    _nameController = TextEditingController(text: package?.name ?? '');
    _priceController = TextEditingController(
      text: package == null ? '' : (package.basePriceCents / 100).toStringAsFixed(2),
    );
    _inclusionsController = TextEditingController(text: package?.inclusions.join('\n') ?? '');
    _active = package?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _inclusionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
    final inclusions = _inclusionsController.text
        .split(RegExp(r'[\n;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final package = FuneralPackageDto(
      id: widget.package?.id ?? '',
      name: _nameController.text.trim(),
      basePriceCents: (price * 100).round(),
      inclusions: inclusions,
      inclusionsJson: jsonEncode(inclusions),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save funeral package: $e')));
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
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Package name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Package name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Base price',
                    prefixText: 'R ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
                    if (amount == null || amount < 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inclusionsController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Inclusions',
                    helperText: 'Enter one inclusion per line',
                    alignLabelWithHint: true,
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
