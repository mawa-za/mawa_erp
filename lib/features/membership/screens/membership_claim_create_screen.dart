import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../../../core/api_client.dart';
import '../../../core/services/field_service.dart';
import '../../../core/models/field_option.dart';
import 'membership_claim_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class MembershipClaimCreateScreen extends StatefulWidget {
  final MembershipDetail membership;
  final Partner member;
  final Dependent? dependent; 
  final Partner? deceasedPartner;

  const MembershipClaimCreateScreen({
    super.key,
    required this.membership,
    required this.member,
    this.dependent,
    this.deceasedPartner,
  });

  @override
  State<MembershipClaimCreateScreen> createState() => _MembershipClaimCreateScreenState();
}

class _MembershipClaimCreateScreenState extends State<MembershipClaimCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoadingOptions = true;

  // Form fields
  final _amountController = TextEditingController();
  final _deathCertificateController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Banking details
  final _accHolderController = TextEditingController();
  final _accNumberController = TextEditingController();
  
  DateTime _dateOfDeath = DateTime.now();
  DateTime _burialDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoadingBenefit = false;
  int? _claimAmountCents;
  String? _selectedClaimTypeCode;
  String? _selectedPayoutMethod;
  String? _selectedAccType;
  String? _selectedBankCode;
  String? _selectedCauseOfDeathCode;
  
  List<FieldOption> _claimTypeOptions = [];
  List<FieldOption> _payoutMethodOptions = [];
  List<FieldOption> _accTypeOptions = [];
  List<FieldOption> _bankOptions = [];
  List<FieldOption> _causeOfDeathOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    
    final deceasedName = widget.deceasedPartner?.fullName ?? widget.member.fullName;
    final relationshipLabel = widget.dependent != null 
        ? DependentType.fromString(widget.dependent!.dependentType).label 
        : "Main Member";
    _notesController.text = 'Claim for $deceasedName ($relationshipLabel)';
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        FieldService().getOptionsByField('CLAIM-TYPE'),
        FieldService().getOptionsByField('PAYMENT-METHOD'),
        FieldService().getOptionsByField('BANK-ACCOUNT-TYPE'),
        FieldService().getOptionsByField('BANK-NAME'),
        FieldService().getOptionsByField('CAUSE-OF-DEATH'),
      ]);
      final configuredResponse = await ApiClient().get(
        '/v2/claim-type-configuration',
        queryParameters: {'enabledOnly': true},
      );
      final enabledTypes = <String>{};
      if (configuredResponse.statusCode == 200) {
        final decoded = jsonDecode(configuredResponse.body);
        if (decoded is List) {
          for (final item in decoded) {
            final row = Map<String, dynamic>.from(item as Map);
            enabledTypes.add((row['claim_type'] ?? row['claimType']).toString().toUpperCase());
          }
        }
      }

      setState(() {
        _claimTypeOptions = (results[0] as List<FieldOption>)
            .where((option) => enabledTypes.isEmpty || enabledTypes.contains(option.code.toUpperCase()))
            .toList();
        _payoutMethodOptions = results[1];
        _accTypeOptions = results[2];
        _bankOptions = results[3];
        _causeOfDeathOptions = results[4];
        
        if (_claimTypeOptions.isNotEmpty) _selectedClaimTypeCode = _claimTypeOptions.first.code;
        if (_payoutMethodOptions.isNotEmpty) _selectedPayoutMethod = _payoutMethodOptions.first.code;
        if (_accTypeOptions.isNotEmpty) _selectedAccType = _accTypeOptions.first.code;
        if (_bankOptions.isNotEmpty) _selectedBankCode = _bankOptions.first.code;
        if (_causeOfDeathOptions.isNotEmpty) _selectedCauseOfDeathCode = _causeOfDeathOptions.first.code;
        
        _isLoadingOptions = false;
      });
      await _loadBenefitAmount();
    } catch (e) {
      debugPrint('Error loading field options: $e');
      setState(() => _isLoadingOptions = false);
    }
  }

  Future<void> _loadBenefitAmount() async {
    if (_selectedClaimTypeCode == null) return;
    if (mounted) setState(() => _isLoadingBenefit = true);
    try {
      final deceasedPartnerId = widget.dependent?.dependentPartnerId ?? widget.member.id;
      final response = await ApiClient().get('/v2/membership-claim/benefit', queryParameters: {
        'membershipId': widget.membership.id,
        'claimType': _selectedClaimTypeCode,
        'deceasedPartnerId': deceasedPartnerId,
        'eventDate': DateFormat('yyyy-MM-dd').format(_dateOfDeath),
      });
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final cents = (data['claimAmountCents'] as num?)?.toInt();
      if (mounted) setState(() {
        _claimAmountCents = cents;
        _amountController.text = cents == null ? '' : (cents / 100).toStringAsFixed(2);
      });
    } catch (e) {
      if (mounted) {
        setState(() { _claimAmountCents = null; _amountController.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Plan benefit could not be determined: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBenefit = false);
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      if (_claimAmountCents == null) {
        throw AppException('The claim amount cannot be determined because the plan benefit is not configured.');
      }
      final int amountCents = _claimAmountCents!;
      
      final bool isCashClaim = _selectedClaimTypeCode == 'CASH';
      
      final selectedBank = _bankOptions.firstWhere(
        (opt) => opt.code == _selectedBankCode, 
        orElse: () => FieldOption(field: '', code: '', type: '', description: '', validFrom: '', validTo: '')
      );

      final selectedCause = _causeOfDeathOptions.firstWhere(
        (opt) => opt.code == _selectedCauseOfDeathCode,
        orElse: () => FieldOption(field: '', code: '', type: '', description: '', validFrom: '', validTo: '')
      );

      final payload = {
        "membershipId": widget.membership.id,
        "claimType": _selectedClaimTypeCode,
        "deceasedType": widget.dependent != null ? "DEPENDENT" : "MAIN_MEMBER",
        "deceasedPartnerId": widget.dependent?.dependentPartnerId ?? widget.member.id,
        "dateOfDeath": DateFormat('yyyy-MM-dd').format(_dateOfDeath),
        "claimDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "burialDate": DateFormat('yyyy-MM-dd').format(_burialDate),
        "causeOfDeath": selectedCause.code,
        "deathCertificateNo": _deathCertificateController.text.trim(),
        "claimAmountCents": amountCents,
        "notes": _notesController.text.trim(),
        "submit": false,
        "payoutMethod": isCashClaim ? _selectedPayoutMethod : null,
        "bankName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? selectedBank.description : null,
        "accountHolderName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accHolderController.text.trim() : null,
        "accountNumber": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accNumberController.text.trim() : null,
        "accountType": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _selectedAccType : null,
        "linkedClaimIds": []
      };

      final Map<String, dynamic> responseData = await MembershipService().createMembershipClaim(payload);
      final String? createdId = responseData['id'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Claim created successfully'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        
        if (createdId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MembershipClaimDetailScreen(claimId: createdId))
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Error: $e')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Process Claim'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoadingOptions 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(colorScheme),
                  const SizedBox(height: 32),
                  _buildSectionHeader(Icons.person_outline, '1. MEMBERSHIP HOLDER'),
                  const SizedBox(height: 12),
                  _buildMembershipHolderCard(colorScheme),
                  const SizedBox(height: 32),
                  _buildSectionHeader(Icons.assignment_outlined, '2. CLAIM DETAILS'),
                  const SizedBox(height: 12),
                  _buildClaimForm(colorScheme),
                  
                  if (_selectedClaimTypeCode == 'CASH') ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader(Icons.account_balance_outlined, '3. PAYOUT & BANKING'),
                    const SizedBox(height: 12),
                    _buildBankingForm(colorScheme),
                  ],
                  
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitClaim,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('CREATE MEMBERSHIP CLAIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    final deceasedName = widget.deceasedPartner?.fullName ?? widget.member.fullName;
    final relationshipLabel = widget.dependent != null 
        ? DependentType.fromString(widget.dependent!.dependentType).label 
        : "Main Member";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.purple.withOpacity(0.1),
                child: const Icon(Icons.person_off_outlined, color: Colors.purple, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DECEASED PERSON', style: TextStyle(color: Colors.purple[700], fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(deceasedName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('$relationshipLabel • Policy #${widget.membership.membershipNo}', 
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipHolderCard(ColorScheme colorScheme) {
    final member = widget.member;
    final identity = member.identityNumber.trim().isEmpty
        ? 'Identity not captured'
        : '${member.idType ?? 'ID'}: ${member.identityNumber}';

    return _buildCard([
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Text(
                member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(identity, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    'Membership #${widget.membership.membershipNo}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'The claimant is derived from the selected membership and cannot be changed.',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    ]);
  }

  Widget _buildClaimForm(ColorScheme colorScheme) {
    return _buildCard([
      SearchableDropdownFormField<String>(
        value: _selectedClaimTypeCode,
        decoration: _inputDecoration('Claim Type', Icons.category_outlined),
        items: _claimTypeOptions.map((opt) => DropdownMenuItem(
          value: opt.code,
          child: Text(opt.description, style: const TextStyle(fontSize: 14)),
        )).toList(),
        onChanged: (v) {
          setState(() {
            _selectedClaimTypeCode = v!;
            if (_selectedClaimTypeCode != 'CASH') {
              _selectedPayoutMethod = null;
            } else if (_selectedPayoutMethod == null && _payoutMethodOptions.isNotEmpty) {
              _selectedPayoutMethod = _payoutMethodOptions.first.code;
            }
          });
          _loadBenefitAmount();
        },
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 20),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dateOfDeath,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _dateOfDeath = picked;
              if (_burialDate.isBefore(_dateOfDeath)) {
                _burialDate = _dateOfDeath.add(const Duration(days: 1));
              }
            });
            _loadBenefitAmount();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date of Death', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text(DateFormat('EEEE, d MMMM yyyy').format(_dateOfDeath), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _burialDate,
            firstDate: _dateOfDeath,
            lastDate: _dateOfDeath.add(const Duration(days: 365)),
          );
          if (picked != null) setState(() => _burialDate = picked);
        },
        child: InputDecorator(
          decoration: _inputDecoration('Burial Date', Icons.event_available_outlined),
          child: Text(DateFormat('EEEE, d MMMM yyyy').format(_burialDate),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _amountController,
        readOnly: true,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: _inputDecoration('Claim Amount (from plan benefit)', Icons.payments_outlined).copyWith(
          prefixText: 'R ',
          suffixIcon: _isLoadingBenefit
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.lock_outline),
          helperText: 'This amount is determined from the membership plan benefit and cannot be changed.',
        ),
        validator: (_) => _claimAmountCents == null ? 'Configure a plan benefit for this claim type' : null,
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _deathCertificateController,
        decoration: _inputDecoration('Death Certificate No', Icons.badge_outlined),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        textCapitalization: TextCapitalization.characters,
      ),
      const SizedBox(height: 20),
      SearchableDropdownFormField<String>(
        value: _selectedCauseOfDeathCode,
        decoration: _inputDecoration('Cause of Death', Icons.description_outlined),
        items: _causeOfDeathOptions.map((opt) => DropdownMenuItem(
          value: opt.code,
          child: Text(opt.description, style: const TextStyle(fontSize: 14)),
        )).toList(),
        onChanged: (v) => setState(() => _selectedCauseOfDeathCode = v!),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _notesController,
        decoration: _inputDecoration('Additional Notes', Icons.notes_rounded),
        maxLines: 3,
      ),
    ]);
  }

  Widget _buildBankingForm(ColorScheme colorScheme) {
    final showBankFields = _selectedPayoutMethod != 'CASH';

    return _buildCard([
      SearchableDropdownFormField<String>(
        value: _selectedPayoutMethod,
        decoration: _inputDecoration('Payout Method', Icons.account_balance_wallet_outlined),
        items: _payoutMethodOptions.map((opt) => DropdownMenuItem(
          value: opt.code,
          child: Text(opt.description, style: const TextStyle(fontSize: 14)),
        )).toList(),
        onChanged: (v) => setState(() => _selectedPayoutMethod = v!),
      ),
      if (showBankFields) ...[
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        SearchableDropdownFormField<String>(
          value: _selectedBankCode,
          decoration: _inputDecoration('Bank Name', Icons.account_balance_outlined),
          items: _bankOptions.map((opt) => DropdownMenuItem(
            value: opt.code,
            child: Text(opt.description, style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: (v) => setState(() => _selectedBankCode = v!),
          validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _accHolderController,
          decoration: _inputDecoration('Account Holder', Icons.person_outline_rounded),
          validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _accNumberController,
          decoration: _inputDecoration('Account Number', Icons.numbers_rounded),
          keyboardType: TextInputType.number,
          validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        SearchableDropdownFormField<String>(
          value: _selectedAccType,
          decoration: _inputDecoration('Type', Icons.list_alt_rounded),
          items: _accTypeOptions.map((opt) => DropdownMenuItem(
            value: opt.code,
            child: Text(opt.description, style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (v) => setState(() => _selectedAccType = v!),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'The universal branch code is assigned automatically from the selected bank.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    ]);
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _deathCertificateController.dispose();
    _notesController.dispose();
    _accHolderController.dispose();
    _accNumberController.dispose();
    super.dispose();
  }
}
