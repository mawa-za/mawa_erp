import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import '../widgets/membership_plan_dropdown.dart';
import 'membership_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showCreateMember = false;

  Partner? _selectedMember;
  MembershipPlan? _selectedPlan;
  DateTime _dateJoined = DateTime.now();
  DateTime _startDate = DateTime.now();

  String? _selectedIdentityType;
  DateTime? _dateOfBirth;
  final _identityNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool get _isCreatingNewMember =>
      _showCreateMember && _selectedMember == null;
  bool get _isSaId =>
      (_selectedIdentityType ?? '').trim().toUpperCase() == 'SA-ID';

  String _upper(String value) => value.trim().toUpperCase();
  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _saveMembership() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a membership plan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Partner? member = _selectedMember;

      if (member == null && _showCreateMember) {
        member = await _createMemberPartner();
      }

      if (member == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select an existing member or create a new member',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final payload = {
        'memberId': member.id,
        'planId': _selectedPlan!.id,
        'startDate': _formatDate(_startDate),
        'joinDate': _formatDate(_dateJoined),
        'status': 'ACTIVE',
      };

      final membershipId =
          await MembershipService().createMembership(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCreatingNewMember
                ? 'Member and membership created successfully'
                : 'Membership created successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              MembershipDetailScreen(membershipId: membershipId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Error: $e')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Partner> _createMemberPartner() async {
    final payload = <String, dynamic>{
      'type': 'INDIVIDUAL',
      'partnerType': 'INDIVIDUAL',
      'name1': _upper(_lastNameController.text),
      'name2': _upper(_firstNameController.text),
      'name3': _upper(_middleNameController.text),
      'identityType': _selectedIdentityType?.trim(),
      'identityNumber': _identityNumberController.text.trim(),
      'birthDate': _dateOfBirth?.toIso8601String(),
      'status': 'ACTIVE',
    };

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
        title: const Text('Create Membership'),
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
                '1. MEMBER SELECTION',
                Icons.person_search_outlined,
              ),
              const SizedBox(height: 16),
              _buildMemberSelectionCard(colorScheme),
              if (_showCreateMember && _selectedMember == null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'NEW MEMBER DETAILS',
                  Icons.person_add_alt_1_outlined,
                ),
                const SizedBox(height: 16),
                _buildNewMemberCard(colorScheme),
              ],
              const SizedBox(height: 32),
              _buildSectionTitle(
                '2. PLAN CONFIGURATION',
                Icons.card_membership_outlined,
              ),
              const SizedBox(height: 16),
              _buildCard([
                MembershipPlanDropdown(
                  value: _selectedPlan?.id,
                  onChanged: (plan) => setState(() => _selectedPlan = plan),
                  validator: (value) =>
                      value == null ? 'Please select a plan' : null,
                ),
                const SizedBox(height: 24),
                _buildDatePickerField(
                  'Date Joined',
                  _dateJoined,
                  Icons.calendar_today,
                  (date) => setState(() => _dateJoined = date),
                ),
                const SizedBox(height: 16),
                _buildDatePickerField(
                  'Policy Start Date',
                  _startDate,
                  Icons.event_available,
                  (date) => setState(() => _startDate = date),
                ),
              ]),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveMembership,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isCreatingNewMember
                              ? 'CREATE MEMBER & MEMBERSHIP'
                              : 'CREATE MEMBERSHIP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
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

  Widget _buildMemberSelectionCard(ColorScheme colorScheme) {
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
              _showCreateMember
                  ? 'membership-search-create'
                  : 'membership-search-select',
            ),
            role: '',
            partnerType: 'INDIVIDUAL',
            label: 'Search for an existing person...',
            onPartnerSelected: (partner) {
              setState(() {
                _selectedMember = partner;
                if (partner != null) {
                  _showCreateMember = false;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedMember = null;
                _showCreateMember = !_showCreateMember;
              });
            },
            icon: Icon(
              _showCreateMember
                  ? Icons.search
                  : Icons.person_add_alt_1_outlined,
            ),
            label: Text(
              _showCreateMember
                  ? 'Search existing person'
                  : 'Person not found? Create new member',
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
          if (_selectedMember != null) ...[
            const SizedBox(height: 16),
            _buildSelectedPartnerSummary(_selectedMember!, colorScheme),
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

  Widget _buildNewMemberCard(ColorScheme colorScheme) {
    return _buildCard([
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Capture the new member details. For an SA-ID, the date of birth is derived automatically.',
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
          if (!_isCreatingNewMember) return null;
          if ((value ?? '').trim().isEmpty) return 'ID Type is required';
          return null;
        },
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _identityNumberController,
        'ID Number',
        Icons.confirmation_number_outlined,
        keyboardType: _isSaId ? TextInputType.number : TextInputType.text,
        inputFormatters: _isSaId
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ]
            : null,
        onChanged: _onIdentityNumberChanged,
        validator: (value) {
          if (!_isCreatingNewMember) return null;
          final idNumber = (value ?? '').trim();
          if (idNumber.isEmpty) return 'ID Number is required';
          if (_isSaId) {
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
        if (!_isCreatingNewMember) return null;
        if (_dateOfBirth == null) {
          return _isSaId
              ? 'Enter a valid SA-ID to determine Date of Birth'
              : 'Date of Birth is required';
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
            if (!_isCreatingNewMember || !requiredWhenCreating) return null;
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

  Widget _buildDatePickerField(
    String label,
    DateTime date,
    IconData icon,
    ValueChanged<DateTime> onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
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
