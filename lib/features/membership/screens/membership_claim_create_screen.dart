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
    _notesController.text = 'Claim for $deceasedName (${widget.dependent?.relationship ?? "Main Member"})';
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

      setState(() {
        _claimTypeOptions = results[0];
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
    } catch (e) {
      debugPrint('Error loading field options: $e');
      setState(() => _isLoadingOptions = false);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a claimant')));
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
        "submit": true,
        // Only include banking details if it's a CASH claim and not payout method CASH
        "payoutMethod": isCashClaim ? _selectedPayoutMethod : null,
        "bankName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? selectedBank.description : null,
        "accountHolderName": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accHolderController.text.trim() : null,
        "accountNumber": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _accNumberController.text.trim() : null,
        "branchCode": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _branchCodeController.text.trim() : null,
        "accountType": (isCashClaim && _selectedPayoutMethod != 'CASH') ? _selectedAccType : null,
        "linkedClaimIds": []
      };

      await MembershipService().createMembershipClaim(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim submitted successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDependentClaim = widget.dependent != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isDependentClaim ? 'Dependent Claim' : 'Main Member Claim'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoadingOptions 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(colorScheme),
                  const SizedBox(height: 24),
                  _buildSectionHeader(Icons.person_search_outlined, 'Claimant (Beneficiary)'),
                  const SizedBox(height: 12),
                  _buildClaimantSelector(colorScheme),
                  const SizedBox(height: 24),
                  _buildSectionHeader(Icons.assignment_outlined, 'Claim Details'),
                  const SizedBox(height: 12),
                  _buildClaimForm(colorScheme),
                  
                  // Payout & Banking section only applies to CASH claim type
                  if (_selectedClaimTypeCode == 'CASH') ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(Icons.account_balance_outlined, 'Payout & Banking'),
                    const SizedBox(height: 12),
                    _buildBankingForm(colorScheme),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitClaim,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SUBMIT MEMBERSHIP CLAIM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildClaimantSelector(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SearchAnchor(
              builder: (context, controller) => SearchBar(
                controller: controller,
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                hintText: 'Search for Claimant...',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              suggestionsBuilder: (context, controller) async {
                final partners = await _searchClaimants(controller.text);
                return partners.map((p) => ListTile(
                  title: Text(p.fullName),
                  subtitle: Text('No: ${p.number}'),
                  onTap: () {
                    setState(() => _selectedClaimant = p);
                    controller.closeView(p.fullName);
                  },
                )).toList();
              },
            ),
            if (_selectedClaimant != null) ...[
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_selectedClaimant!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${_selectedClaimant!.identityNumber}'),
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedClaimant = null),
                ),
              ),
            ],
          ],
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

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    final deceasedName = widget.deceasedPartner?.fullName ?? widget.member.fullName;
    final relationship = widget.dependent?.relationship.replaceAll('-', ' ') ?? "Main Member";

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Deceased Person', deceasedName),
            const Divider(height: 16),
            _buildSummaryRow('Relationship', relationship),
            const Divider(height: 16),
            _buildSummaryRow('Membership No', widget.membership.membershipNo),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildClaimForm(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedClaimTypeCode,
              decoration: const InputDecoration(
                labelText: 'Claim Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _claimTypeOptions.map((opt) => DropdownMenuItem(
                value: opt.code,
                child: Text(opt.description),
              )).toList(),
              onChanged: (v) => setState(() {
                _selectedClaimTypeCode = v!;
                if (_selectedClaimTypeCode != 'CASH') {
                  _selectedPayoutMethod = null;
                } else if (_selectedPayoutMethod == null && _payoutMethodOptions.isNotEmpty) {
                  _selectedPayoutMethod = _payoutMethodOptions.first.code;
                }
              }),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
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
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Death',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(_dateOfDeath)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Claim Amount',
                hintText: '0.00',
                prefixText: 'R ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deathCertificateController,
              decoration: const InputDecoration(
                labelText: 'Death Certificate No',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCauseOfDeathCode,
              decoration: const InputDecoration(
                labelText: 'Cause of Death',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              items: _causeOfDeathOptions.map((opt) => DropdownMenuItem(
                value: opt.code,
                child: Text(opt.description),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCauseOfDeathCode = v!),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankingForm(ColorScheme colorScheme) {
    final showBankFields = _selectedPayoutMethod != 'CASH';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPayoutMethod,
              decoration: const InputDecoration(
                labelText: 'Payout Method',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: _payoutMethodOptions.map((opt) => DropdownMenuItem(
                value: opt.code,
                child: Text(opt.description),
              )).toList(),
              onChanged: (v) => setState(() => _selectedPayoutMethod = v!),
            ),
            if (showBankFields) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBankCode,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                ),
                items: _bankOptions.map((opt) => DropdownMenuItem(
                  value: opt.code,
                  child: Text(opt.description),
                )).toList(),
                onChanged: (v) => setState(() => _selectedBankCode = v!),
                validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accHolderController,
                decoration: const InputDecoration(labelText: 'Account Holder', border: OutlineInputBorder()),
                validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accNumberController,
                decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _branchCodeController,
                      decoration: const InputDecoration(labelText: 'Branch Code', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => showBankFields && (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAccType,
                      decoration: const InputDecoration(labelText: 'Account Type', border: OutlineInputBorder()),
                      items: _accTypeOptions.map((opt) => DropdownMenuItem(
                        value: opt.code,
                        child: Text(opt.description),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedAccType = v!),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
