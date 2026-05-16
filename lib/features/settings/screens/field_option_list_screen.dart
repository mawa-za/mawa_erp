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
  List<FieldOption> _options = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final options = await _service.getOptions();
      if (mounted) {
        setState(() {
          _options = options;
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

  Map<String, List<FieldOption>> _groupOptions() {
    final Map<String, List<FieldOption>> groups = {};
    for (var option in _options) {
      if (!groups.containsKey(option.field)) {
        groups[option.field] = [];
      }
      groups[option.field]!.add(option);
    }
    return groups;
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
        final data = {
          'field': fieldController.text.trim().toUpperCase(),
          'code': codeController.text.trim().toUpperCase(),
          'description': descriptionController.text.trim(),
          'type': typeController.text.trim(),
          'validFrom': option?.validFrom ?? DateTime.now().toIso8601String().split('T')[0],
          'validTo': option?.validTo ?? '2099-12-31',
        };

        if (isEditing) {
          await _service.updateOption(option.field, option.code, data);
        } else {
          await _service.saveOption(data);
        }
        _fetchOptions();
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
        _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupOptions();
    final sortedFields = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Field Options'),
        actions: [
          IconButton(onPressed: _fetchOptions, icon: const Icon(Icons.refresh)),
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
                    final options = grouped[field]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(field, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${options.length} options'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addOrEditOption(initialField: field),
                        ),
                        children: options.map((opt) => ListTile(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditOption(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
