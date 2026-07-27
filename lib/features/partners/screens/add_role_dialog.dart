import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/services/field_service.dart';
import '../../../core/models/field_option.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddRoleDialog extends StatefulWidget {
  final String partnerId;
  final List<String> currentRoles;

  const AddRoleDialog({
    super.key,
    required this.partnerId,
    required this.currentRoles,
  });

  @override
  State<AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends State<AddRoleDialog> {
  List<FieldOption> _availableRoles = [];
  final List<String> _selectedRoles = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRoles.addAll(widget.currentRoles);
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await FieldService().getOptionsByField('PARTNER-ROLE');
      if (mounted) {
        setState(() {
          _availableRoles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final response = await ApiClient().post(
        '/v2/partner/${widget.partnerId}/role',
        body: _selectedRoles,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw AppException('Failed to update roles');
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
      title: const Text('Manage Partner Roles'),
      content: _isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableRoles.length,
                itemBuilder: (context, index) {
                  final role = _availableRoles[index];
                  final isSelected = _selectedRoles.contains(role.code);
                  return CheckboxListTile(
                    title: Text(role.description),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedRoles.add(role.code);
                        } else {
                          _selectedRoles.remove(role.code);
                        }
                      });
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _isLoading ? null : _submit,
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Roles'),
        ),
      ],
    );
  }
}
