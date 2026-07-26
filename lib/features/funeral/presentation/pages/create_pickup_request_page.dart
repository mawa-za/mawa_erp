import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api_client.dart';
import '../../../../core/models/field_option.dart';
import '../../../../core/services/field_service.dart';
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
  final _picker = ImagePicker();
  final _deceasedNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _injuryDetailsController = TextEditingController();

  List<FieldOption> _salesAreas = [];
  final List<XFile> _injuryPhotos = [];
  String? _pickupLocationCode;
  bool _corpseInjured = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSalesAreas();
  }

  Future<void> _loadSalesAreas() async {
    try {
      final options = await FieldService().getOptionsByField('SALES-AREA');
      if (mounted) setState(() { _salesAreas = options; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load pickup areas: $e')));
      }
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo != null && mounted) setState(() => _injuryPhotos.add(photo));
  }

  Future<void> _uploadPhotos(String pickupId) async {
    for (final photo in _injuryPhotos) {
      final bytes = await photo.readAsBytes();
      final extension = photo.name.contains('.') ? photo.name.split('.').last : 'jpg';
      final response = await ApiClient().post('/v2/attachment', body: {
        'objectId': pickupId,
        'documentType': 'PICKUP-INJURY-PHOTO',
        'extension': extension,
        'file': base64Encode(bytes),
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Pickup was created but an injury photo could not be uploaded: ${response.body}');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_corpseInjured && _injuryPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one injury photo from the camera or photo library.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await _api.createPickupRequest(CreatePickupRequestDto(
        deceasedName: _deceasedNameController.text.trim(),
        pickupLocationCode: _pickupLocationCode!,
        corpseInjured: _corpseInjured,
        injuryDetails: _injuryDetailsController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
      ));
      if (_corpseInjured && result.id != null) await _uploadPhotos(result.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup request created successfully')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    decoration: const InputDecoration(labelText: 'Deceased Name', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Deceased name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _pickupLocationCode,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Location',
                      helperText: 'Configured from SALES-AREA.',
                      border: OutlineInputBorder(),
                    ),
                    items: _salesAreas.map((option) => DropdownMenuItem(
                      value: option.code,
                      child: Text(option.description),
                    )).toList(),
                    onChanged: (value) => setState(() => _pickupLocationCode = value),
                    validator: (value) => value == null ? 'Pickup location is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactPersonController,
                    decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Contact person is required' : null,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    validator: (value) => RegExp(r'^\d{10}$').hasMatch(value ?? '')
                        ? null : 'Contact number must be exactly 10 numeric digits',
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Is the corpse injured?'),
                            subtitle: const Text('Injury photos are required before pickup completion.'),
                            value: _corpseInjured,
                            onChanged: (value) => setState(() {
                              _corpseInjured = value;
                              if (!value) _injuryPhotos.clear();
                            }),
                          ),
                          if (_corpseInjured) ...[
                            TextFormField(
                              controller: _injuryDetailsController,
                              maxLines: 3,
                              decoration: const InputDecoration(labelText: 'Describe the injuries', border: OutlineInputBorder()),
                              validator: (value) => _corpseInjured && (value == null || value.trim().isEmpty)
                                  ? 'Injury details are required' : null,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _addPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Take Photo'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _addPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Photo Library'),
                                ),
                              ],
                            ),
                            if (_injuryPhotos.isNotEmpty)
                              ..._injuryPhotos.asMap().entries.map((entry) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.image_outlined),
                                title: Text(entry.value.name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => _injuryPhotos.removeAt(entry.key)),
                                ),
                              )),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Request'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _deceasedNameController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _injuryDetailsController.dispose();
    super.dispose();
  }
}
