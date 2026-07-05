import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/membership_plan.dart' hide DependentType;
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../../../core/api_client.dart';
import '../../../core/services/field_service.dart';
import '../../../core/models/field_option.dart';
import 'membership_claim_detail_screen.dart';

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
  MembershipPlan? _plan;

  // Form fields
  final _amountController = TextEditingController();
  final _deathCertificateController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Banking details
  final _accHolderController = TextEditingController();
  final _accNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  
  DateTime _dateOfDeath = DateTime.now();
  String? _selectedClaimTypeCode;
  String? _selectedPayoutMethod;
  String? _selectedAccType;
  String? _selectedBankCode;
  String? _selectedCauseOfDeathCode;
  
  Partner? _selectedClaimant;
  List<FieldOption> _claimTypeOptions = [];
  List<FieldOption> _payoutMethodOptions = [];
  List<FieldOption> _accTypeOptions = [];
  List<FieldOption> _bankOptions = [];
  List<FieldOption> _causeOfDeathOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    
    if (widget.dependent != null) {
      _selectedClaimant = widget.member;
    }
    
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
        MembershipService().getMembershipPlanById(widget.membership.planId).then<dynamic>((value) => value).catchError((_) => null),
      ]);

      setState(() {
        _claimTypeOptions = results[0];
        _payoutMethodOptions = results[1];
        _accTypeOptions = results[2];
        _bankOptions = results[3];
        _causeOfDeathOptions = results[4];
        _plan = results[5] is MembershipPlan ? results[5] as MembershipPlan : null;
        
        if (_claimTypeOptions.isNotEmpty) _selectedClaimTypeCode = _claimTypeOptions.first.code;
        if (_payoutMethodOptions.isNotEmpty) _selectedPayoutMethod = _payoutMethodOptions.first.code;
        if (_accTypeOptions.isNotEmpty) _selectedAccType = _accTypeOptions.first.code;
        if (_bankOptions.isNotEmpty) _selectedBankCode = _bankOptions.first.code;
        if (_causeOfDeathOptions.isNotEmpty) _selectedCauseOfDeathCode = _causeOfDeathOptions.first.code;
        
        _applyPlanClaimAmount();
        _isLoadingOptions = false;
      });
    } catch (e) {
      debugPrint('Error loading field options: $e');
      setState(() => _isLoadingOptions = false);
    }
  }


  void _applyPlanClaimAmount() {
    final plan = _plan;
    if (plan == null) return;
    final claimType = _selectedClaimTypeCode;
    if (claimType == null || claimType.isEmpty) return;
    final relationship = widget.dependent != null ? widget.dependent!.dependentType : 'MAIN_MEMBER';

    final activePayouts = (plan.claimPayouts ?? []).where((p) => p.active && p.claimType.name == claimType).toList();
    MembershipPlanClaimPayout? payout;
    for (final item in activePayouts) {
      if (item.dependentType.name == relationship) {
        payout = item;
        break;
      }
    }
    payout ??= activePayouts.cast<MembershipPlanClaimPayout?>().firstWhere(
          (item) => item?.dependentType.name == 'ANY',
          orElse: () => null,
        );
    payout ??= activePayouts.isNotEmpty ? activePayouts.first : null;

    final amountCents = payout?.payoutAmountCents ?? 0;
    if (amountCents > 0) {
      _amountController.text = (amountCents / 100).toStringAsFixed(2);
    }
  }

  Future<List<Partner>> _searchClaimants(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching partners: $e');
    }
    return [];
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClaimant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a claimant'), behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final double amount = double.tryParse(_amountController.text) ?? 0.0;
      final int amountCents = (amount * 100).toInt();
      
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
        "causeOfDeath": selectedCause.description,
        "deathCertificateNo": _deathCertificateController.text.trim(),
        "claimantPartnerId": _selectedClaimant!.id,
        "claimAmountCents": amountCents,
        "notes": _notesController.text.trim(),
        "submit": false,
        "payoutMethod": isCashClaim ? _selectedPayoutMethod : null,
        "bankName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? selectedBank.description : null,
        "accountHolderName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accHolderController.text.trim() : null,
        "accountNumber": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accNumberController.text.trim() : null,
        "branchCode": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _branchCodeController.text.trim() : null,
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
            content: Text('Error: $e'),
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
      backgroundColor: const Color(0xFFF8F9FD),
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
                  _buildSectionHeader(Icons.person_search_outlined, '1. CLAIMANT (BENEFICIARY)'),
                  const SizedBox(height: 12),
                  _buildClaimantSelector(colorScheme),
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

  Widget _buildClaimantSelector(ColorScheme colorScheme) {
    return _buildCard([
      SearchAnchor(
        builder: (context, controller) => SearchBar(
          controller: controller,
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          hintText: 'Search for Beneficiary...',
          leading: const Icon(Icons.search_rounded),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(Colors.grey[100]),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        ),
        suggestionsBuilder: (context, controller) async {
          final partners = await _searchClaimants(controller.text);
          return partners.map((p) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
            title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Policy No: ${p.number}'),
            onTap: () {
              setState(() => _selectedClaimant = p);
              controller.closeView(p.fullName);
            },
          )).toList();
        },
      ),
      if (_selectedClaimant != null) ...[
        const SizedBox(height: 20),
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
                child: Text(_selectedClaimant!.fullName.isNotEmpty ? _selectedClaimant!.fullName[0].toUpperCase() : '?', 
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedClaimant!.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('ID: ${_selectedClaimant!.identityNumber}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedClaimant = null),
              ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _buildClaimForm(ColorScheme colorScheme) {
    return _buildCard([
      DropdownButtonFormField<String>(
        value: _selectedClaimTypeCode,
        decoration: _inputDecoration('Claim Type', Icons.category_outlined),
        items: _claimTypeOptions.map((opt) => DropdownMenuItem(
          value: opt.code,
          child: Text(opt.description, style: const TextStyle(fontSize: 14)),
        )).toList(),
        onChanged: (v) => setState(() {
          _selectedClaimTypeCode = v!;
          if (_selectedClaimTypeCode != 'CASH') {
            _selectedPayoutMethod = null;
          } else if (_selectedPayoutMethod == null && _payoutMethodOptions.isNotEmpty) {
            _selectedPayoutMethod = _payoutMethodOptions.first.code;
          }
          _applyPlanClaimAmount();
        }),
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
          if (picked != null) setState(() => _dateOfDeath = picked);
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
      TextFormField(
        controller: _amountController,
        readOnly: true,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: _inputDecoration('Claim Amount', Icons.payments_outlined).copyWith(
          prefixText: 'R ',
          hintText: '0.00',
          helperText: 'Calculated from the selected membership plan payout rule',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid amount';
          return null;
        },
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _deathCertificateController,
        decoration: _inputDecoration('Death Certificate No', Icons.badge_outlined),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        textCapitalization: TextCapitalization.characters,
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
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
      DropdownButtonFormField<String>(
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
        DropdownButtonFormField<String>(
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _branchCodeController,
                decoration: _inputDecoration('Branch', Icons.code_rounded),
                keyboardType: TextInputType.number,
                validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedAccType,
                decoration: _inputDecoration('Type', Icons.list_alt_rounded),
                items: _accTypeOptions.map((opt) => DropdownMenuItem(
                  value: opt.code,
                  child: Text(opt.description, style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedAccType = v!),
              ),
            ),
          ],
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
    _branchCodeController.dispose();
    super.dispose();
  }
}
