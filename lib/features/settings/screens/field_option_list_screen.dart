import 'package:flutter/material.dart';
import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';

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
      // First get the list of distinct fields
      final fields = await _service.getFields();
      
      // Then get all options to group them
      final options = await _service.getOptions();
      
      final Map<String, List<FieldOption>> groups = {};
      
      // Initialize groups with empty lists for all fields
      for (var field in fields) {
        final fieldCode = field['code']?.toString() ?? '';
        if (fieldCode.isNotEmpty) {
          groups[fieldCode] = [];
        }
      }
      
      // Populate the groups with actual options
      for (var option in options) {
        if (!groups.containsKey(option.field)) {
          groups[option.field] = [];
        }
        groups[option.field]!.add(option);
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
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addField() async {
    final fieldController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Field'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fieldController,
                decoration: const InputDecoration(labelText: 'Field Name/Code (e.g. GENDER)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );

    if (result == true) {
      final fieldName = fieldController.text.trim().toUpperCase();
      if (fieldName.isEmpty) return;

      try {
        await _service.addField({
          'description': fieldName,
          'validFrom': DateTime.now().toIso8601String().split('T')[0],
          'validTo': '2099-12-31'
        });
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _addOrEditOption({FieldOption? option, String? initialField}) async {
    final fieldController = TextEditingController(text: option?.field ?? initialField ?? '');
    final descriptionController = TextEditingController(text: option?.description ?? '');
    final bool isEditing = option != null;

    String deriveCode(String description) => description
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String previewCode = isEditing ? option.code : deriveCode(descriptionController.text);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  child: Icon(isEditing ? Icons.edit_outlined : Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(isEditing ? 'Edit Option' : 'Add Option'),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: fieldController,
                    decoration: const InputDecoration(labelText: 'Field', border: OutlineInputBorder()),
                    enabled: !isEditing && initialField == null,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      helperText: 'Code is generated automatically from the description.',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => previewCode = isEditing ? option.code : deriveCode(value)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generated code', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(previewCode.isEmpty ? 'TYPE-DESCRIPTION-FIRST' : previewCode, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Type: TENANT', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                label: Text(isEditing ? 'UPDATE' : 'CREATE'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      try {
        final field = fieldController.text.trim().toUpperCase();
        final description = descriptionController.text.trim();
        if (field.isEmpty || description.isEmpty) return;
        final data = {
          'field': field,
          'code': isEditing ? option.code : deriveCode(description),
          'description': description,
          'type': 'TENANT',
          'validFrom': option?.validFrom ?? DateTime.now().toIso8601String().split('T')[0],
          'validTo': option?.validTo ?? '2099-12-31',
        };

        if (isEditing) {
          await _service.updateOption(option.field, option.code, data);
        } else {
          await _service.saveOption(field, data);
        }
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deleteOption(FieldOption option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Option'),
        content: Text('Are you sure you want to delete ${option.description}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteOption(option.field, option.code);
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedFields.length,
                  itemBuilder: (context, index) {
                    final field = sortedFields[index];
                    final options = _groupedOptions[field]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(field, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(options.isEmpty ? 'No options' : '${options.length} options'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addOrEditOption(initialField: field),
                        ),
                        children: options.isEmpty 
                          ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No options defined for this field', style: TextStyle(color: Colors.grey)))]
                          : options.map((opt) => ListTile(
                          title: Text(opt.description),
                          subtitle: Text('Code: ${opt.code} | Type: ${opt.type}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _addOrEditOption(option: opt),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _deleteOption(opt),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}
