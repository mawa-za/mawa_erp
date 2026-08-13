import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../../../core/theme/mawa_design.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class FieldOptionListScreen extends StatefulWidget {
  const FieldOptionListScreen({super.key});

  @override
  State<FieldOptionListScreen> createState() => _FieldOptionListScreenState();
}

class _FieldOptionListScreenState extends State<FieldOptionListScreen> {
  final FieldService _service = FieldService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _fields = const [];
  Map<String, List<FieldOption>> _groupedOptions = const {};
  String _searchTerm = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchData();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _searchTerm) return;
    setState(() => _searchTerm = value);
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fields = await _service.getFields();
      final options = await _service.getOptions();
      final groups = <String, List<FieldOption>>{};

      for (final field in fields) {
        final fieldCode = field['code']?.toString().trim() ?? '';
        if (fieldCode.isNotEmpty) groups[fieldCode] = <FieldOption>[];
      }

      for (final option in options) {
        groups.putIfAbsent(option.field, () => <FieldOption>[]);
        groups[option.field]!.add(option);
      }

      for (final values in groups.values) {
        values.sort(
          (a, b) => a.description.toLowerCase().compareTo(
                b.description.toLowerCase(),
              ),
        );
      }

      if (!mounted) return;
      setState(() {
        _fields = fields;
        _groupedOptions = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _generatedCode(String description) {
    return description.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
  }

  Map<String, dynamic>? _fieldDefinition(String code) {
    for (final field in _fields) {
      if (field['code']?.toString() == code) return field;
    }
    return null;
  }

  String _fieldDescription(String code) {
    final description = _fieldDefinition(code)?['description']?.toString().trim();
    return description == null || description.isEmpty ? _humanise(code) : description;
  }

  String _fieldLabel(Map<String, dynamic> field) {
    final code = field['code']?.toString() ?? '';
    final description = field['description']?.toString().trim() ?? '';
    if (description.isEmpty || description.toUpperCase() == code.toUpperCase()) {
      return code;
    }
    return '$description ($code)';
  }

  String _humanise(String value) {
    if (value.trim().isEmpty) return value;
    return value
        .trim()
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  List<String> get _visibleFields {
    final fields = _groupedOptions.keys.where((fieldCode) {
      if (_searchTerm.isEmpty) return true;
      final definition = _fieldDefinition(fieldCode);
      final fieldText = [
        fieldCode,
        definition?['description'],
        ...?_groupedOptions[fieldCode]?.expand(
          (option) => [option.code, option.description],
        ),
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
      return fieldText.contains(_searchTerm);
    }).toList();

    fields.sort(
      (a, b) => _fieldDescription(a).toLowerCase().compareTo(
            _fieldDescription(b).toLowerCase(),
          ),
    );
    return fields;
  }

  int get _optionCount => _groupedOptions.values.fold<int>(
        0,
        (total, options) => total + options.length,
      );

  Future<void> _addOrEditOption({
    FieldOption? option,
    String? initialField,
  }) async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController(
      text: option?.description ?? '',
    );
    final isEditing = option != null;
    String? selectedField = option?.field ?? initialField;

    final fieldItems = <Map<String, dynamic>>[..._fields];
    final knownCodes = fieldItems
        .map((field) => field['code']?.toString() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();
    if (selectedField != null &&
        selectedField!.isNotEmpty &&
        !knownCodes.contains(selectedField)) {
      fieldItems.add({
        'code': selectedField,
        'description': selectedField,
      });
    }
    fieldItems.sort((a, b) => _fieldLabel(a).compareTo(_fieldLabel(b)));

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final generatedCode = _generatedCode(descriptionController.text);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MawaDesign.dialogRadius),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: MawaDesign.redSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: MawaDesign.red,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Edit field option'
                                      : 'Add field option',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEditing
                                      ? 'Update the description shown to users.'
                                      : 'Add a tenant-maintained value to an existing system field.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: MawaDesign.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SearchableDropdownFormField<String>(
                        value: selectedField != null &&
                                fieldItems.any(
                                  (field) =>
                                      field['code']?.toString() == selectedField,
                                )
                            ? selectedField
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Field',
                          prefixIcon: Icon(Icons.data_object_rounded),
                        ),
                        items: fieldItems
                            .map(
                              (field) => DropdownMenuItem<String>(
                                value: field['code']?.toString(),
                                child: Text(
                                  _fieldLabel(field),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isEditing || initialField != null
                            ? null
                            : (value) => setDialogState(() {
                                  selectedField = value;
                                }),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Select a field'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                          helperText: 'The option code and type are set automatically.',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter a description'
                            : null,
                      ),
                      if (!isEditing && generatedCode.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: MawaDesign.surfaceMuted,
                            border: Border.all(color: MawaDesign.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.code_rounded,
                                size: 18,
                                color: MawaDesign.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Generated code: $generatedCode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(dialogContext, true);
                              }
                            },
                            icon: Icon(
                              isEditing ? Icons.save_outlined : Icons.add_rounded,
                            ),
                            label: Text(isEditing ? 'Save changes' : 'Add option'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final description = descriptionController.text.trim();
    descriptionController.dispose();
    if (result != true || selectedField == null) return;

    try {
      final data = <String, dynamic>{'description': description};
      if (isEditing) {
        await _service.updateOption(option.field, option.code, data);
      } else {
        await _service.saveOption(selectedField!, data);
      }
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Field option updated successfully.'
                  : 'Field option added successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteOption(FieldOption option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: MawaDesign.red),
        title: const Text('Remove field option?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            '“${option.description}” will no longer be available for selection. Existing records that use this code are not changed.',
            textAlign: TextAlign.center,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep option'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MawaDesign.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove option'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteOption(option.field, option.code);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field option removed.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleFields = _visibleFields;
    return Scaffold(
      backgroundColor: MawaDesign.page,
      appBar: AppBar(
        title: const Text('Field Options'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _fetchData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _fetchData)
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: MawaDesign.responsivePagePadding(
                      MediaQuery.sizeOf(context).width,
                    ),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 18),
                      _buildSearch(context),
                      const SizedBox(height: 18),
                      if (visibleFields.isEmpty)
                        _EmptySearchState(
                          hasSearch: _searchTerm.isNotEmpty,
                          onClear: () => _searchController.clear(),
                        )
                      else
                        ...visibleFields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildFieldCard(context, field),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: MawaDesign.surface,
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        border: Border.all(color: MawaDesign.border),
        boxShadow: MawaDesign.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintain selectable values',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Fields are controlled by database migrations. Add, edit or remove tenant-specific options for the fields already available.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: MawaDesign.textMuted),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatPill(
                icon: Icons.data_object_rounded,
                value: '${_groupedOptions.length}',
                label: 'Fields',
              ),
              _StatPill(
                icon: Icons.tune_rounded,
                value: '$_optionCount',
                label: 'Options',
              ),
              FilledButton.icon(
                onPressed: _fields.isEmpty ? null : () => _addOrEditOption(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add option'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                description,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search fields or options',
        hintText: 'Search by field name, code or option',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchTerm.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: MawaDesign.surface,
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, String field) {
    final options = _groupedOptions[field] ?? const <FieldOption>[];
    final description = _fieldDescription(field);
    return Container(
      decoration: BoxDecoration(
        color: MawaDesign.surface,
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        border: Border.all(color: MawaDesign.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: MawaDesign.infoSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.list_alt_rounded, color: MawaDesign.info),
        ),
        title: Text(description),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CodeBadge(value: field),
              Text(
                options.isEmpty
                    ? 'No options configured'
                    : '${options.length} option${options.length == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: MawaDesign.textMuted),
              ),
            ],
          ),
        ),
        trailing: IconButton.filledTonal(
          tooltip: 'Add option to $description',
          onPressed: () => _addOrEditOption(initialField: field),
          icon: const Icon(Icons.add_rounded),
        ),
        children: [
          const Divider(height: 1),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(
                    Icons.playlist_add_rounded,
                    size: 34,
                    color: MawaDesign.textSubtle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No selectable values have been added yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: MawaDesign.textMuted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _addOrEditOption(initialField: field),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add first option'),
                  ),
                ],
              ),
            )
          else
            ...options.map((option) => _buildOptionRow(context, option)),
        ],
      ),
    );
  }

  Widget _buildOptionRow(BuildContext context, FieldOption option) {
    final tenantMaintained = option.type.toUpperCase() == 'TENANT';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: MawaDesign.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MawaDesign.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tenantMaintained
                  ? MawaDesign.successSoft
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tenantMaintained ? Icons.person_outline : Icons.lock_outline,
              size: 18,
              color: tenantMaintained
                  ? MawaDesign.success
                  : Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.description,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    _CodeBadge(value: option.code),
                    Text(
                      tenantMaintained ? 'Tenant maintained' : 'System option',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: MawaDesign.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (tenantMaintained)
            PopupMenuButton<String>(
              tooltip: 'Option actions',
              onSelected: (action) {
                if (action == 'edit') _addOrEditOption(option: option);
                if (action == 'delete') _deleteOption(option);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit option'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: MawaDesign.red),
                    title: Text('Remove option'),
                  ),
                ),
              ],
            )
          else
            const Tooltip(
              message: 'System options can only be changed by migration.',
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.lock_outline, color: MawaDesign.textSubtle),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MawaDesign.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MawaDesign.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MawaDesign.textMuted),
          const SizedBox(width: 7),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: MawaDesign.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  final String value;

  const _CodeBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: MawaDesign.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MawaDesign.border),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MawaDesign.textMuted,
              fontFamily: 'monospace',
            ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClear;

  const _EmptySearchState({required this.hasSearch, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: MawaDesign.surface,
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        border: Border.all(color: MawaDesign.border),
      ),
      child: Column(
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.list_alt_rounded,
            size: 46,
            color: MawaDesign.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No matching fields found' : 'No fields are available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            hasSearch
                ? 'Try a different field name, field code or option.'
                : 'New fields must be deployed through a database migration.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: MawaDesign.textMuted),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onClear, child: const Text('Clear search')),
          ],
        ],
      ),
    );
  }
}
