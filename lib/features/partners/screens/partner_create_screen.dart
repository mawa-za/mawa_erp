import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../../core/services/field_service.dart';
import '../../../core/models/field_option.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../models/partner.dart';
import 'partner_detail_screen.dart';

class PartnerCreateScreen extends StatefulWidget {
  final Partner? existingPartner;
  final bool isMemberContext;
  const PartnerCreateScreen({super.key, this.existingPartner, this.isMemberContext = false});

  @override
  State<PartnerCreateScreen> createState() => _PartnerCreateScreenState();
}

class _PartnerCreateScreenState extends State<PartnerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  late String _selectedType;
  final _name1Controller = TextEditingController(); // Last Name / Org Name
  final _name2Controller = TextEditingController(); // First Name
  final _name3Controller = TextEditingController(); // Middle Name
  final _name4Controller = TextEditingController();
  final _identityController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedTitle;
  String? _selectedMaritalStatus;
  String? _selectedGender;
  String? _selectedLanguage;
  DateTime? _birthDate;

  final List<PartnerAddress> _addresses = [];
  final List<String> _types = ['INDIVIDUAL', 'ORGANISATION', 'GROUP'];
  List<FieldOption> _roleOptions = [];
  final List<String> _selectedRoles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
    if (widget.existingPartner != null) {
      final p = widget.existingPartner!;
      _selectedType = p.type;
      _name1Controller.text = p.name1;
      _name2Controller.text = p.name2;
      _name3Controller.text = p.name3;
      _name4Controller.text = p.name4 ?? '';
      _identityController.text = p.identityNumber;
      _emailController.text = p.email;
      _phoneController.text = p.phone;
      _selectedTitle = p.title;
      _selectedMaritalStatus = p.maritalStatus;
      _selectedGender = p.gender;
      _selectedLanguage = p.language;
      if (p.birthDate != null) {
        try {
          _birthDate = DateTime.parse(p.birthDate!);
        } catch (_) {}
      }
      _addresses.addAll(p.addresses);
      _selectedRoles.addAll(p.roles);
    } else {
      _selectedType = 'INDIVIDUAL';
      // Add a default address
      _addresses.add(PartnerAddress(type: 'RESIDENTIAL', line1: '', city: '', state: '', postalCode: ''));
      if (widget.isMemberContext) {
        _selectedRoles.add('CUSTOMER');
      }
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await FieldService().getOptionsByField('PARTNER-ROLE');
      if (mounted) {
        setState(() {
          _roleOptions = roles;
        });
      }
    } catch (e) {
      debugPrint('Error loading roles: $e');
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _savePartner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'type': _selectedType,
      'name1': _name1Controller.text,
      'name2': _selectedType == 'INDIVIDUAL' ? _name2Controller.text : '',
      'name3': _selectedType == 'INDIVIDUAL' ? _name3Controller.text : '',
      'name4': _name4Controller.text,
      'identityNumber': _identityController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'title': _selectedTitle,
      'birthDate': _birthDate?.toIso8601String(),
      'maritalStatus': _selectedMaritalStatus,
      'gender': _selectedGender,
      'language': _selectedLanguage,
      'addresses': _addresses.map((a) => a.toJson()).toList(),
      'roles': _selectedRoles,
    };

    try {
      final response = widget.existingPartner == null
          ? await ApiClient().post('/v2/partner', body: payload)
          : await ApiClient().post('/v2/partner/${widget.existingPartner!.id}', body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? createdId = responseData['id'];

        if (mounted) {
          final entityName = widget.isMemberContext ? 'Member' : 'Partner';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$entityName ${widget.existingPartner == null ? "created" : "updated"} successfully'), behavior: SnackBarBehavior.floating),
          );
          
          if (widget.existingPartner == null && createdId != null) {
            // Navigate to details for new partner
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: createdId, isMemberContext: widget.isMemberContext))
            );
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        throw Exception('Failed to save partner: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addAddress() {
    setState(() {
      _addresses.add(PartnerAddress(type: 'RESIDENTIAL', line1: '', city: '', state: '', postalCode: ''));
    });
  }

  void _removeAddress(int index) {
    if (_addresses.length > 1) {
      setState(() => _addresses.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entityName = widget.isMemberContext ? 'Member' : 'Partner';
    final isEditingMember = widget.existingPartner != null && widget.isMemberContext;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.existingPartner == null ? 'Create $entityName' : 'Edit $entityName'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.category_outlined, '$entityName Type'),
              const SizedBox(height: 12),
              _buildTypeSelector(colorScheme),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.person_outline, 'Basic Details'),
              const SizedBox(height: 12),
              _buildBasicDetailsFields(isEditingMember),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.info_outline, 'Demographics & Language'),
              const SizedBox(height: 12),
              _buildDemographicsFields(),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.contact_mail_outlined, 'Contact Information'),
              const SizedBox(height: 12),
              _buildContactFields(),
              const SizedBox(height: 24),
              if (!widget.isMemberContext) ...[
                _buildSectionHeader(Icons.work_outline, '$entityName Roles'),
                const SizedBox(height: 12),
                _buildRolesFields(),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(Icons.location_on_outlined, 'Addresses'),
                  TextButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Address'),
                  ),
                ],
              ),
              ..._addresses.asMap().entries.map((entry) => _buildAddressForm(entry.key, entry.value, colorScheme)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _savePartner,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.existingPartner == null ? 'CREATE ${entityName.toUpperCase()}' : 'SAVE CHANGES', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    final bool isEditing = widget.existingPartner != null;
    final bool isLocked = isEditing; // Member type is permanent after creation
    
    return Row(
      children: _types.map((type) {
        final isSelected = _selectedType == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: isLocked ? null : () => setState(() => _selectedType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isLocked ? colorScheme.primary.withOpacity(0.6) : colorScheme.primary) 
                      : (isLocked ? Colors.grey[50] : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? colorScheme.primary : Colors.grey.shade300),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isLocked ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBasicDetailsFields(bool isEditingMember) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedType == 'INDIVIDUAL') ...[
              AppDropdownField(
                field: 'TITLE',
                label: 'Title',
                icon: Icons.person_outline,
                value: _selectedTitle,
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
              _buildTextField(_name2Controller, 'First Name', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_name3Controller, 'Middle Name (Optional)', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_name1Controller, 'Last Name', Icons.person_outline),
            ] else ...[
              _buildTextField(_name1Controller, _selectedType == 'ORGANISATION' ? 'Organisation Name' : 'Group Name', Icons.business_outlined),
            ],
            const SizedBox(height: 16),
            _buildTextField(_name4Controller, 'Alternative/Trading Name (Optional)', Icons.badge_outlined),
            const SizedBox(height: 16),
            _buildTextField(
              _identityController, 
              _selectedType == 'INDIVIDUAL' ? 'Identity Number' : 'Registration Number', 
              Icons.badge_outlined,
              enabled: !isEditingMember,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographicsFields() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_birthDate == null ? 'Birth Date' : "Birth Date: ${DateFormat('yyyy-MM-dd').format(_birthDate!)}"),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: _selectBirthDate,
            ),
            const Divider(),
            AppDropdownField(
              field: 'GENDER',
              label: 'Gender',
              icon: Icons.wc_outlined,
              value: _selectedGender,
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 16),
            AppDropdownField(
              field: 'MARITAL-STATUS',
              label: 'Marital Status',
              icon: Icons.favorite_outline,
              value: _selectedMaritalStatus,
              onChanged: (val) => setState(() => _selectedMaritalStatus = val),
            ),
            const SizedBox(height: 16),
            AppDropdownField(
              field: 'LANGUAGE',
              label: 'Preferred Language',
              icon: Icons.language_outlined,
              value: _selectedLanguage,
              onChanged: (val) => setState(() => _selectedLanguage = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactFields() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(_emailController, 'Email Address (Optional)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(_phoneController, 'Phone Number (Optional)', Icons.phone_outlined, keyboardType: TextInputType.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesFields() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _roleOptions.isEmpty
            ? const Center(
                child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            : Wrap(
                spacing: 8,
                runSpacing: 0,
                children: _roleOptions.map((role) {
                  final isSelected = _selectedRoles.contains(role.code);
                  return FilterChip(
                    label: Text(role.description, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(role.code);
                        } else {
                          _selectedRoles.remove(role.code);
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildAddressForm(int index, PartnerAddress addr, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Address ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (_addresses.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeAddress(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppDropdownField(
              field: 'ADDRESS-TYPE',
              label: 'Address Type',
              icon: Icons.home_outlined,
              value: addr.type,
              onChanged: (val) {
                if (val != null) setState(() => _addresses[index] = _updateAddress(addr, type: val));
              },
            ),
            const SizedBox(height: 16),
            _buildAddressTextField('Address Line 1 (Optional)', addr.line1, (val) => _addresses[index] = _updateAddress(addr, line1: val)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAddressTextField('City (Optional)', addr.city, (val) => _addresses[index] = _updateAddress(addr, city: val))),
                const SizedBox(width: 12),
                Expanded(child: _buildAddressTextField('State/Province (Optional)', addr.state, (val) => _addresses[index] = _updateAddress(addr, state: val))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAddressTextField('Postal Code (Optional)', addr.postalCode, (val) => _addresses[index] = _updateAddress(addr, postalCode: val))),
                const SizedBox(width: 12),
                Expanded(child: _buildAddressTextField('Country (Optional)', addr.country, (val) => _addresses[index] = _updateAddress(addr, country: val))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PartnerAddress _updateAddress(PartnerAddress addr, {String? type, String? line1, String? city, String? state, String? postalCode, String? country}) {
    return PartnerAddress(
      id: addr.id,
      type: type ?? addr.type,
      line1: line1 ?? addr.line1,
      city: city ?? addr.city,
      state: state ?? addr.state,
      postalCode: postalCode ?? addr.postalCode,
      country: country ?? addr.country,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, icon),
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(fontSize: 14, color: enabled ? Colors.black87 : Colors.grey[600]),
      validator: (val) {
        if (label.contains('(Optional)')) return null;
        if (val == null || val.isEmpty) return 'Required';
        return null;
      },
    );
  }

  Widget _buildAddressTextField(String label, String initialValue, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue,
      decoration: _inputDecoration(label, null),
      style: const TextStyle(fontSize: 13),
      onChanged: onChanged,
      validator: (val) {
        if (label.contains('(Optional)')) return null;
        if (val == null || val.isEmpty) return 'Required';
        return null;
      },
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

  @override
  void dispose() {
    _name1Controller.dispose();
    _name2Controller.dispose();
    _name3Controller.dispose();
    _name4Controller.dispose();
    _identityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
