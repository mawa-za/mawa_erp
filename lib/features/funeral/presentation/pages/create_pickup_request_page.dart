import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/field_option.dart';
import '../../../../core/services/field_service.dart';
import '../../data/funeral_api.dart';
import '../../data/models/create_pickup_request_dto.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CreatePickupRequestPage extends StatefulWidget {
  const CreatePickupRequestPage({super.key});

  @override
  State<CreatePickupRequestPage> createState() => _CreatePickupRequestPageState();
}

class _CreatePickupRequestPageState extends State<CreatePickupRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = FuneralApi();
  final _deceasedNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  List<FieldOption> _salesAreas = [];
  String? _pickupLocationCode;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSalesAreas();
  }

  @override
  void dispose() {
    _deceasedNameController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesAreas() async {
    try {
      final options = await FieldService().getOptionsByField('SALES-AREA');
      if (mounted) {
        setState(() {
          _salesAreas = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Could not load pickup areas: $e'))),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _api.createPickupRequest(
        CreatePickupRequestDto(
          deceasedName: _deceasedNameController.text.trim(),
          pickupLocationCode: _pickupLocationCode!,
          contactPerson: _contactPersonController.text.trim(),
          contactNumber: _contactNumberController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup request created successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Pickup Request')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _deceasedNameController,
                    decoration: const InputDecoration(
                      labelText: 'Deceased Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Deceased name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _pickupLocationCode,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Location',
                      helperText: 'Configured from SALES-AREA.',
                      border: OutlineInputBorder(),
                    ),
                    items: _salesAreas
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.code,
                            child: Text(option.description),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _pickupLocationCode = value),
                    validator: (value) => value == null ? 'Pickup location is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactPersonController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Person',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Contact person is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      helperText: 'Enter exactly 10 numeric digits.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) => RegExp(r'^\d{10}$').hasMatch(value ?? '')
                        ? null
                        : 'Contact number must be exactly 10 numeric digits',
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The assigned driver will assess injuries and capture any required photos after arriving at the pickup location.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Request'),
                  ),
                ],
              ),
            ),
    );
  }
}
