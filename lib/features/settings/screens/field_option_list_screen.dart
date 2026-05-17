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
    final codeController = TextEditingController(text: option?.code ?? '');
    final descriptionController = TextEditingController(text: option?.description ?? '');
    final typeController = TextEditingController(text: option?.type ?? '');
    
    final bool isEditing = option != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Option' : 'Add Option'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fieldController,
                decoration: const InputDecoration(labelText: 'Field Name (e.g. GENDER)'),
                enabled: !isEditing && initialField == null,
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code (e.g. M)'),
                enabled: !isEditing,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (e.g. Male)'),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEditing ? 'UPDATE' : 'CREATE'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final field = fieldController.text.trim().toUpperCase();
        final data = {
          'field': field,
          'code': codeController.text.trim().toUpperCase(),
          'description': descriptionController.text.trim(),
          'type': typeController.text.trim(),
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
