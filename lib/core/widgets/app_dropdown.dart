import 'package:flutter/material.dart';
import '../models/field_option.dart';
import '../services/field_service.dart';

class AppDropdownField extends StatefulWidget {
  final String field;
  final String? value;
  final String label;
  final IconData? icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const AppDropdownField({
    super.key,
    required this.field,
    this.value,
    required this.label,
    this.icon,
    required this.onChanged,
    this.validator,
  });

  @override
  State<AppDropdownField> createState() => _AppDropdownFieldState();
}

class _AppDropdownFieldState extends State<AppDropdownField> {
  List<FieldOption>? _options;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await FieldService().getOptionsByField(widget.field);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TextFormField(
        decoration: _inputDecoration(widget.label, widget.icon).copyWith(
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        readOnly: true,
      );
    }

    if (_error != null) {
      return TextFormField(
        decoration: _inputDecoration(widget.label, widget.icon).copyWith(
          suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOptions),
        ),
        readOnly: true,
        initialValue: 'Error loading options',
      );
    }

    final options = _options ?? [];

    // Ensure the current value exists in the options, otherwise null it
    final currentValue = options.any((o) => o.code == widget.value) ? widget.value : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: _inputDecoration(widget.label, widget.icon),
      items: options.map((opt) {
        return DropdownMenuItem(
          value: opt.code,
          child: Text(opt.description, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: widget.onChanged,
      validator: widget.validator,
      isExpanded: true,
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
