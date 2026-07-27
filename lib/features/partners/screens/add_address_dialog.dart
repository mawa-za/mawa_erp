import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../models/partner.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddAddressDialog extends StatefulWidget {
  final String partnerId;

  const AddAddressDialog({super.key, required this.partnerId});

  @override
  State<AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<AddAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _line3Controller = TextEditingController();
  final _line4Controller = TextEditingController();
  final _suburbController = TextEditingController();
  final _townController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedProvince;
  final _postalCodeController = TextEditingController();
  
  String _selectedType = 'RESIDENTIAL';
  bool _isSubmitting = false;

  final List<String> _addressTypes = ['RESIDENTIAL', 'POSTAL', 'OFFICE', 'BILLING', 'SHIPPING'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'objectId': widget.partnerId,
      'type': _selectedType,
      'line1': _line1Controller.text,
      'line2': _line2Controller.text,
      'line3': _line3Controller.text,
      'line4': _line4Controller.text,
      'suburb': _suburbController.text,
      'town': _townController.text,
      'city': _cityController.text,
      'province': _selectedProvince,
      'postalCode': _postalCodeController.text,
    };

    try {
      final response = await ApiClient().post(
        '/v2/address',
        body: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw AppException('Failed to add address: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Address'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Address Type'),
                items: _addressTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              _buildTextField(_line1Controller, 'Address Line 1', true),
              _buildTextField(_line2Controller, 'Address Line 2', false),
              _buildTextField(_line3Controller, 'Address Line 3', false),
              _buildTextField(_line4Controller, 'Address Line 4', false),
              _buildTextField(_suburbController, 'Suburb', false),
              _buildTextField(_townController, 'Town', false),
              _buildTextField(_cityController, 'City', true),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppDropdownField(
                  field: 'PROVINCE',
                  label: 'Province',
                  value: _selectedProvince,
                  onChanged: (value) => setState(() => _selectedProvince = value),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
              ),
              _buildTextField(_postalCodeController, 'Postal Code', true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          border: const OutlineInputBorder(),
        ),
        validator: (val) => required && (val == null || val.isEmpty) ? 'Required' : null,
      ),
    );
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _line3Controller.dispose();
    _line4Controller.dispose();
    _suburbController.dispose();
    _townController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }
}
