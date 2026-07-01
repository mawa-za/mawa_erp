import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../models/dependent.dart';

class AddDependentScreen extends StatefulWidget {
  final String membershipId;
  const AddDependentScreen({super.key, required this.membershipId});

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showCreatePartner = false;

  Partner? _selectedPartner;
  DependentType _selectedType = DependentType.OTHER;

  String? _selectedIdentityType;
  DateTime? _dateOfBirth;
  final _identityNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool get _isCreatingNewPartner => _showCreatePartner && _selectedPartner == null;

  String _normalise(String value) => value.trim();
  String _upper(String value) => _normalise(value).toUpperCase();

  bool get _hasIdentityType => (_selectedIdentityType ?? '').trim().isNotEmpty;
  bool get _hasIdentityNumber => _identityNumberController.text.trim().isNotEmpty;
  bool get _hasIdentityPair => _hasIdentityType && _hasIdentityNumber;

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<Partner> _createDependentPartner() async {
    final payload = <String, dynamic>{
      'partnerType': 'INDIVIDUAL',
      'name1': _upper(_lastNameController.text),
      'name2': _upper(_firstNameController.text),
      'name3': _upper(_middleNameController.text),
      'birthDate': _dateOfBirth?.toIso8601String(),
    };

    if (_hasIdentityPair) {
      payload['identityType'] = _selectedIdentityType!.trim();
      payload['identityNumber'] = _identityNumberController.text.trim();
    }

    return PartnerService().createPartner(payload);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Partner? partner = _selectedPartner;

      if (partner == null && _showCreatePartner) {
        partner = await _createDependentPartner();
      }

      if (partner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an existing person or create a new partner'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final payload = {
        'dependentPartnerId': partner.id,
        'dependentType': _selectedType.name,
        'active': true,
        'membershipId': widget.membershipId,
      };

      await MembershipService().addDependent(widget.membershipId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dependent added successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Add Dependent'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('PERSON SELECTION', Icons.person_search_outlined),
              const SizedBox(height: 16),
              _buildPersonSelectionCard(colorScheme),
              if (_showCreatePartner && _selectedPartner == null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('NEW PARTNER DETAILS', Icons.person_add_alt_1_outlined),
                const SizedBox(height: 16),
                _buildNewPartnerCard(colorScheme),
              ],
              const SizedBox(height: 32),
              _buildSectionTitle('RELATIONSHIP DETAILS', Icons.people_outline),
              const SizedBox(height: 16),
              _buildCard([
                DropdownButtonFormField<DependentType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Relationship Type',
                    prefixIcon: Icon(Icons.people_outline, color: colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: DependentType.values.where((e) => e != DependentType.ANY).map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
              ]),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(
                          _isCreatingNewPartner ? 'CREATE PARTNER & ADD DEPENDENT' : 'ADD DEPENDENT',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonSelectionCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartnerSearchDropdown(
            key: ValueKey(_showCreatePartner ? 'dependent-search-create' : 'dependent-search-select'),
            role: 'INDIVIDUAL',
            label: 'Search by Name or ID...',
            onPartnerSelected: (p) {
              setState(() {
                _selectedPartner = p;
                if (p != null) {
                  _showCreatePartner = false;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPartner = null;
                      _showCreatePartner = !_showCreatePartner;
                    });
                  },
                  icon: Icon(_showCreatePartner ? Icons.search : Icons.person_add_alt_1_outlined),
                  label: Text(_showCreatePartner ? 'Search existing partner' : 'Person not found? Create new partner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedPartner != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedPartner!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (_selectedPartner!.number.isNotEmpty) 'No: ${_selectedPartner!.number}',
                            if (_selectedPartner!.identityNumber.isNotEmpty) _selectedPartner!.identityNumber,
                          ].join(' • '),
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewPartnerCard(ColorScheme colorScheme) {
    return _buildCard([
      Text(
        'Capture identity details when available. If ID Type and ID Number are not both captured, Date of Birth is mandatory.',
        style: TextStyle(color: Colors.grey[700], fontSize: 13),
      ),
      const SizedBox(height: 16),
      AppDropdownField(
        field: 'ID-TYPE',
        label: 'ID Type',
        icon: Icons.badge_outlined,
        value: _selectedIdentityType,
        onChanged: (val) => setState(() => _selectedIdentityType = val),
        validator: (val) {
          if (!_isCreatingNewPartner) return null;
          final hasType = (val ?? '').trim().isNotEmpty;
          if (!hasType && _hasIdentityNumber) return 'ID Type is required when ID Number is captured';
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _identityNumberController,
        'ID Number',
        Icons.confirmation_number_outlined,
        requiredWhenCreating: false,
        validator: (val) {
          if (!_isCreatingNewPartner) return null;
          final hasNumber = (val ?? '').trim().isNotEmpty;
          if (!hasNumber && _hasIdentityType) return 'ID Number is required when ID Type is captured';
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(_firstNameController, 'First Name', Icons.person_outline),
      const SizedBox(height: 16),
      _buildTextField(_middleNameController, 'Middle Name (Optional)', Icons.person_outline, requiredWhenCreating: false),
      const SizedBox(height: 16),
      _buildTextField(_lastNameController, 'Last Name', Icons.person_outline),
      const SizedBox(height: 16),
      FormField<DateTime>(
        validator: (_) {
          if (!_isCreatingNewPartner) return null;
          if (!_hasIdentityPair && _dateOfBirth == null) {
            return 'Date of Birth is required when ID Type and ID Number are not captured';
          }
          return null;
        },
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  await _selectDateOfBirth();
                  state.didChange(_dateOfBirth);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: state.hasError ? colorScheme.error : Colors.grey.shade300)),
                    errorText: state.errorText,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _dateOfBirth == null ? 'Select date' : DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
                    style: TextStyle(color: _dateOfBirth == null ? Colors.grey[600] : Colors.black87),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ]);
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredWhenCreating = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator ??
          (val) {
            if (!_isCreatingNewPartner || !requiredWhenCreating) return null;
            if (val == null || val.trim().isEmpty) return 'Required';
            return null;
          },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey[700],
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.white),
      ),
      child: Column(children: children),
    );
  }

  @override
  void dispose() {
    _identityNumberController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
