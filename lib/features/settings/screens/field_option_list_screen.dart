import 'package:flutter/material.dart';
import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FieldOptionListScreen extends StatefulWidget {
  const FieldOptionListScreen({super.key});

  @override
  State<FieldOptionListScreen> createState() => _FieldOptionListScreenState();
}

class _FieldOptionListScreenState extends State<FieldOptionListScreen> {
  final FieldService _service = FieldService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _fields = [];
  Map<String, List<FieldOption>> _groupedOptions = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fields = await _service.getFields();
      final options = await _service.getOptions();
      final Map<String, List<FieldOption>> groups = {};

      for (final field in fields) {
        final fieldCode = field['code']?.toString() ?? '';
        if (fieldCode.isNotEmpty) groups[fieldCode] = [];
      }

      for (final option in options) {
        groups.putIfAbsent(option.field, () => []);
        groups[option.field]!.add(option);
      }

      for (final values in groups.values) {
        values.sort((a, b) => a.description.compareTo(b.description));
      }

      if (mounted) {
        setState(() {
          _fields = fields;
          _groupedOptions = groups;
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

  String _generatedCode(String description) {
    return description.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
  }

  String _fieldLabel(Map<String, dynamic> field) {
    final code = field['code']?.toString() ?? '';
    final description = field['description']?.toString().trim() ?? '';
    if (description.isEmpty || description.toUpperCase() == code.toUpperCase()) {
      return code;
    }
    return '$description ($code)';
  }

  Future<void> _addField() async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Field'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: descriptionController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Description',
                helperText: 'The field code is generated automatically.',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a description'
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _service.addField({
        'description': descriptionController.text.trim(),
      });
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

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
    fieldItems.sort(
      (a, b) => _fieldLabel(a).compareTo(_fieldLabel(b)),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Field Option' : 'Add Field Option'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedField != null &&
                            fieldItems.any(
                              (field) => field['code']?.toString() == selectedField,
                            )
                        ? selectedField
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Field',
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
                    autofocus: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      helperText: 'Code and type are set automatically.',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a description'
                        : null,
                  ),
                  if (!isEditing && descriptionController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Generated code: ${_generatedCode(descriptionController.text)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(isEditing ? 'UPDATE' : 'CREATE'),
            ),
          ],
        ),
      ),
    );

    if (result != true || selectedField == null) return;

    try {
      final data = <String, dynamic>{
        'description': descriptionController.text.trim(),
      };

      if (isEditing) {
        await _service.updateOption(option.field, option.code, data);
      } else {
        await _service.saveOption(selectedField!, data);
      }
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteOption(FieldOption option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Option'),
        content: Text('Are you sure you want to delete ${option.description}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteOption(option.field, option.code);
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedFields = _groupedOptions.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Field Options'),
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _addField, icon: const Icon(Icons.add_box_outlined)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedFields.length,
                  itemBuilder: (context, index) {
                    final field = sortedFields[index];
                    final options = _groupedOptions[field]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(
                          field,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          options.isEmpty
                              ? 'No options'
                              : '${options.length} options',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addOrEditOption(initialField: field),
                        ),
                        children: options.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No options defined for this field',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ]
                            : options
                                .map(
                                  (opt) => ListTile(
                                    title: Text(opt.description),
                                    subtitle: Text('Code: ${opt.code}'),
                                    trailing: opt.type.toUpperCase() == 'TENANT'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _addOrEditOption(option: opt),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _deleteOption(opt),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                      ),
                    );
                  },
                ),
    );
  }
}
