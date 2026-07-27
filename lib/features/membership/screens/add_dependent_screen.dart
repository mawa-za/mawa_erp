import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../models/dependent.dart';
import '../services/membership_service.dart';

class AddDependentScreen extends StatefulWidget {
  final String membershipId;

  const AddDependentScreen({
    super.key,
    required this.membershipId,
  });

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _showCreatePartner = false;

  Partner? _selectedPartner;
  DependentType _selectedType = DependentType.OTHER;
  String? _selectedIdentityType;
  DateTime? _dateOfBirth;

  bool get _isCreatingNewPartner =>
      _showCreatePartner && _selectedPartner == null;
  bool get _isSaId =>
      (_selectedIdentityType ?? '').trim().toUpperCase() == 'SA-ID';
  bool get _hasIdentityType =>
      (_selectedIdentityType ?? '').trim().isNotEmpty;
  bool get _hasIdentityNumber =>
      _identityNumberController.text.trim().isNotEmpty;
  bool get _hasIdentityPair => _hasIdentityType && _hasIdentityNumber;

  String _upper(String value) => value.trim().toUpperCase();
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

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
            content: Text(
              'Please select an existing person or create a new dependent',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (partner.type.toUpperCase() != 'INDIVIDUAL') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A dependent must be an individual person'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final change = await MembershipService().addDependent(
        widget.membershipId,
        {
          'dependentPartnerId': partner.id,
          'dependentType': _selectedType.name,
          'reason': _reasonController.text.trim(),
        },
      );

      if (!mounted) return;

      final pending = change.status == 'PENDING_APPROVAL';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pending
                ? 'Dependent addition submitted for approval'
                : _isCreatingNewPartner
                    ? 'Dependent created and added successfully'
                    : 'Dependent added successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: pending ? Colors.orange[800] : Colors.green[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Partner> _createDependentPartner() async {
    final payload = <String, dynamic>{
      'type': 'INDIVIDUAL',
      'partnerType': 'INDIVIDUAL',
      'name1': _upper(_lastNameController.text),
      'name2': _upper(_firstNameController.text),
      'name3': _upper(_middleNameController.text),
      'birthDate': _dateOfBirth?.toIso8601String(),
      'status': 'ACTIVE',
    };

    if (_hasIdentityPair) {
      payload['identityType'] = _selectedIdentityType!.trim();
      payload['identityNumber'] = _identityNumberController.text.trim();
    }

    return PartnerService().createPartner(payload);
  }

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

  DateTime? _dateOfBirthFromSaId(String idNumber) {
    final digits = idNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null;

    final yy = int.tryParse(digits.substring(0, 2));
    final mm = int.tryParse(digits.substring(2, 4));
    final dd = int.tryParse(digits.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;

    final now = DateTime.now();
    try {
      var candidate = DateTime(2000 + yy, mm, dd);
      if (candidate.year != 2000 + yy ||
          candidate.month != mm ||
          candidate.day != dd) {
        return null;
      }
      if (candidate.isAfter(now)) {
        candidate = DateTime(1900 + yy, mm, dd);
      }
      if (candidate.month != mm ||
          candidate.day != dd ||
          candidate.isAfter(now)) {
        return null;
      }
      return candidate;
    } catch (_) {
      return null;
    }
  }

  void _onIdentityTypeChanged(String? value) {
    setState(() {
      _selectedIdentityType = value;
      if (_isSaId) {
        _dateOfBirth =
            _dateOfBirthFromSaId(_identityNumberController.text.trim());
      }
    });
  }

  void _onIdentityNumberChanged(String value) {
    if (!_isSaId) return;
    final derivedDate = _dateOfBirthFromSaId(value);
    if (derivedDate == _dateOfBirth) return;
    setState(() => _dateOfBirth = derivedDate);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Dependent'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(
                '1. PERSON SELECTION',
                Icons.person_search_outlined,
              ),
              const SizedBox(height: 16),
              _buildPersonSelectionCard(colorScheme),
              if (_showCreatePartner && _selectedPartner == null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'NEW DEPENDENT DETAILS',
                  Icons.person_add_alt_1_outlined,
                ),
                const SizedBox(height: 16),
                _buildNewPartnerCard(colorScheme),
              ],
              const SizedBox(height: 32),
              _buildSectionTitle(
                '2. RELATIONSHIP DETAILS',
                Icons.people_outline,
              ),
              const SizedBox(height: 16),
              _buildRelationshipCard(colorScheme),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_outlined),
                  label: Text(
                    _isCreatingNewPartner
                        ? 'CREATE & ADD DEPENDENT'
                        : 'ADD DEPENDENT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PartnerSearchDropdown(
            key: ValueKey(
              _showCreatePartner
                  ? 'dependent-search-create'
                  : 'dependent-search-select',
            ),
            role: '',
            partnerType: 'INDIVIDUAL',
            label: 'Search person by name or ID...',
            onPartnerSelected: (partner) {
              setState(() {
                _selectedPartner = partner;
                if (partner != null) {
                  _showCreatePartner = false;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedPartner = null;
                _showCreatePartner = !_showCreatePartner;
              });
            },
            icon: Icon(
              _showCreatePartner
                  ? Icons.search
                  : Icons.person_add_alt_1_outlined,
            ),
            label: Text(
              _showCreatePartner
                  ? 'Search existing person'
                  : 'Dependent not found? Create new dependent',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(
                color: colorScheme.primary.withOpacity(0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_selectedPartner != null) ...[
            const SizedBox(height: 16),
            _buildSelectedPartnerSummary(_selectedPartner!, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPartnerSummary(
    Partner partner,
    ColorScheme colorScheme,
  ) {
    return Container(
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
                Text(
                  partner.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (partner.number.isNotEmpty) 'No: ${partner.number}',
                    if (partner.identityNumber.isNotEmpty)
                      partner.identityNumber,
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPartnerCard(ColorScheme colorScheme) {
    return _buildCard([
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Capture identity details when available. If no identity is available, Date of Birth is required.',
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
      ),
      const SizedBox(height: 16),
      AppDropdownField(
        field: 'ID-TYPE',
        label: 'ID Type',
        icon: Icons.badge_outlined,
        value: _selectedIdentityType,
        onChanged: _onIdentityTypeChanged,
        validator: (value) {
          if (!_isCreatingNewPartner) return null;
          final hasType = (value ?? '').trim().isNotEmpty;
          if (!hasType && _hasIdentityNumber) {
            return 'ID Type is required when ID Number is captured';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _identityNumberController,
        'ID Number',
        Icons.confirmation_number_outlined,
        requiredWhenCreating: false,
        keyboardType: _isSaId ? TextInputType.number : TextInputType.text,
        inputFormatters: _isSaId
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ]
            : null,
        onChanged: _onIdentityNumberChanged,
        validator: (value) {
          if (!_isCreatingNewPartner) return null;
          final idNumber = (value ?? '').trim();
          if (idNumber.isEmpty && _hasIdentityType) {
            return 'ID Number is required when ID Type is captured';
          }
          if (_isSaId && idNumber.isNotEmpty) {
            final digits = idNumber.replaceAll(RegExp(r'\D'), '');
            if (digits.length != 13) {
              return 'SA-ID must be exactly 13 digits';
            }
            if (_dateOfBirthFromSaId(digits) == null) {
              return 'SA-ID contains an invalid date of birth';
            }
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _firstNameController,
        'First Name',
        Icons.person_outline,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _middleNameController,
        'Middle Name (Optional)',
        Icons.person_outline,
        requiredWhenCreating: false,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _lastNameController,
        'Last Name',
        Icons.person_outline,
      ),
      const SizedBox(height: 16),
      _buildBirthDateField(colorScheme),
    ]);
  }

  Widget _buildBirthDateField(ColorScheme colorScheme) {
    return FormField<DateTime>(
      validator: (_) {
        if (!_isCreatingNewPartner) return null;
        if (!_hasIdentityPair && _dateOfBirth == null) {
          return 'Date of Birth is required when identity details are not captured';
        }
        if (_isSaId && _hasIdentityPair && _dateOfBirth == null) {
          return 'Enter a valid SA-ID to determine Date of Birth';
        }
        return null;
      },
      builder: (state) {
        return InkWell(
          onTap: _isSaId
              ? null
              : () async {
                  await _selectDateOfBirth();
                  state.didChange(_dateOfBirth);
                },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText:
                  _isSaId ? 'Date of Birth (from SA-ID)' : 'Date of Birth',
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                color: colorScheme.primary,
              ),
              suffixIcon: _isSaId
                  ? const Icon(Icons.lock_outline, size: 18)
                  : const Icon(Icons.edit_calendar_outlined, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: state.hasError
                      ? colorScheme.error
                      : Colors.grey.shade300,
                ),
              ),
              errorText: state.errorText,
              filled: true,
              fillColor: Colors.white,
            ),
            child: Text(
              _dateOfBirth == null
                  ? (_isSaId ? 'Enter SA-ID number' : 'Select date')
                  : _formatDate(_dateOfBirth!),
              style: TextStyle(
                color: _dateOfBirth == null
                    ? Colors.grey[600]
                    : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRelationshipCard(ColorScheme colorScheme) {
    return _buildCard([
      DropdownButtonFormField<DependentType>(
        value: _selectedType,
        decoration: InputDecoration(
          labelText: 'Relationship Type',
          prefixIcon: Icon(Icons.people_outline, color: colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: DependentType.values
            .where(
              (type) =>
                  type != DependentType.ANY &&
                  type != DependentType.MAIN_MEMBER,
            )
            .map(
              (type) => DropdownMenuItem(
                value: type,
                child: Text(type.label),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedType = value!),
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _reasonController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Reason *',
          helperText:
              'Changes requested one month or more after membership creation require approval.',
          prefixIcon: Icon(Icons.notes_outlined, color: colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Reason is required'
            : null,
      ),
    ]);
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredWhenCreating = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator ??
          (value) {
            if (!_isCreatingNewPartner || !requiredWhenCreating) return null;
            if (value == null || value.trim().isEmpty) return 'Required';
            return null;
          },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Column(children: children),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _identityNumberController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
