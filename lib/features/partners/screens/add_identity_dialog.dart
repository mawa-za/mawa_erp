import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../models/partner_identity.dart';

class AddIdentityDialog extends StatefulWidget {
  final String partnerId;

  const AddIdentityDialog({super.key, required this.partnerId});

  @override
  State<AddIdentityDialog> createState() => _AddIdentityDialogState();
}

class _AddIdentityDialogState extends State<AddIdentityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  String? _selectedType = 'SA-ID';
  DateTime? _validFrom;
  DateTime? _validTo;
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context, bool isValidFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isValidFrom) {
          _validFrom = picked;
        } else {
          _validTo = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final identity = PartnerIdentity(
      partner: widget.partnerId,
      type: _selectedType ?? '',
      number: _numberController.text,
      validFrom: _validFrom,
      validTo: _validTo,
    );

    try {
      final response = await ApiClient().post(
        '/v2/partner/${widget.partnerId}/identity',
        body: identity.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to add identity: ${response.body.isNotEmpty ? response.body : response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Identity'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDropdownField(
                field: 'ID-TYPE',
                label: 'Identity Type',
                value: _selectedType,
                onChanged: (val) => setState(() => _selectedType = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Identity Number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_validFrom == null ? 'Valid From' : 'Valid From: ${DateFormat('yyyy-MM-dd').format(_validFrom!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_validTo == null ? 'Valid To' : 'Valid To: ${DateFormat('yyyy-MM-dd').format(_validTo!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
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

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }
}
