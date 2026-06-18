import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/create_pickup_request_dto.dart';

class CreatePickupRequestPage extends StatefulWidget {
  const CreatePickupRequestPage({super.key});

  @override
  State<CreatePickupRequestPage> createState() => _CreatePickupRequestPageState();
}

class _CreatePickupRequestPageState extends State<CreatePickupRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = FuneralApi();
  bool _isLoading = false;

  final _deceasedNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  Future<void> _submit() async {
    debugPrint('CreatePickupRequest: _submit called');
    if (!_formKey.currentState!.validate()) {
      debugPrint('CreatePickupRequest: Validation failed');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final request = CreatePickupRequestDto(
        deceasedName: _deceasedNameController.text,
        pickupLocation: _locationController.text,
        contactPerson: _contactPersonController.text,
        contactNumber: _contactNumberController.text,
      );

      debugPrint('CreatePickupRequest: Sending request to API...');
      final result = await _api.createPickupRequest(request);
      debugPrint('CreatePickupRequest: Success! ID: ${result.id}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup request created successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('CreatePickupRequest: Error occurred: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Pickup Request')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _deceasedNameController,
                      decoration: const InputDecoration(labelText: 'Deceased Name*', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Pickup Location*', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Contact Person*', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: const InputDecoration(labelText: 'Contact Number*', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('Submit Request'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _deceasedNameController.dispose();
    _locationController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }
}
