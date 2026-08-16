import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../models/field_option.dart';
import '../services/field_service.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

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

  @override
  void didUpdateWidget(covariant AppDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field) {
      _loadOptions();
    }
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final options = await FieldService().getOptionsByField(widget.field);
      options.sort(
        (a, b) => a.description.toLowerCase().compareTo(
              b.description.toLowerCase(),
            ),
      );
      if (!mounted) return;
      setState(() {
        _options = options;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TextFormField(
        decoration: _inputDecoration(widget.label, widget.icon).copyWith(
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        readOnly: true,
      );
    }

    if (_error != null) {
      return TextFormField(
        decoration: _inputDecoration(widget.label, widget.icon).copyWith(
          errorText: _error,
          suffixIcon: IconButton(
            tooltip: 'Reload options',
            icon: const Icon(Icons.refresh),
            onPressed: _loadOptions,
          ),
        ),
        readOnly: true,
      );
    }

    final options = <FieldOption>[...?_options];
    final currentValue = widget.value?.trim();
    if (currentValue != null &&
        currentValue.isNotEmpty &&
        !options.any((option) => option.code == currentValue)) {
      options.insert(
        0,
        FieldOption(
          field: widget.field,
          code: currentValue,
          type: 'LEGACY',
          description: _humanise(currentValue),
          validFrom: '',
          validTo: '',
        ),
      );
    }

    return SearchableDropdownFormField<String>(
      value: currentValue != null &&
              currentValue.isNotEmpty &&
              options.any((option) => option.code == currentValue)
          ? currentValue
          : null,
      decoration: _inputDecoration(widget.label, widget.icon).copyWith(
        helperText: options.isEmpty
            ? 'No options configured. Add values under Field Options.'
            : null,
      ),
      hint: Text(options.isEmpty ? 'No options available' : 'Select ${widget.label.toLowerCase()}'),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option.code,
          child: Text(
            option.description,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: options.isEmpty ? null : widget.onChanged,
      validator: widget.validator,
      isExpanded: true,
    );
  }

  String _humanise(String value) {
    return value
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
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
