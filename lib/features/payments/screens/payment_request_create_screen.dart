import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/models/field_option.dart';
import '../../../core/models/user.dart';
import '../../../core/services/field_service.dart';
import '../../../core/services/user_service.dart';
import '../../partners/models/partner.dart';
import '../services/payment_request_service.dart';

class PaymentRequestCreateScreen extends StatefulWidget {
  const PaymentRequestCreateScreen({super.key});

  @override
  State<PaymentRequestCreateScreen> createState() => _PaymentRequestCreateScreenState();
}

class _PaymentRequestCreateScreenState extends State<PaymentRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Form Fields
  Partner? _selectedRecipient;
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  String? _selectedPaymentReason;
  String? _selectedPaymentMethod;
  String? _selectedType;

  // Bank Account Fields
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  String? _selectedBankCode;
  String? _selectedAccountType;

  // Options
  List<FieldOption> _reasonOptions = [];
  List<FieldOption> _methodOptions = [];
  List<FieldOption> _typeOptions = [];
  List<FieldOption> _accountTypeOptions = [];
  List<FieldOption> _bankOptions = [];
  bool _isLoadingOptions = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        FieldService().getOptionsByField('PAYMENT-REASON'),
        FieldService().getOptionsByField('PAYMENT-METHOD'),
        FieldService().getOptionsByField('PAYMENT-REQUEST-TYPE'),
        FieldService().getOptionsByField('BANK-ACCOUNT-TYPE'),
        FieldService().getOptionsByField('BANK-NAME'),
      ]);

      setState(() {
        _reasonOptions = results[0];
        _methodOptions = results[1];
        _typeOptions = results[2];
        _accountTypeOptions = results[3];
        _bankOptions = results[4];
        _isLoadingOptions = false;

        if (_reasonOptions.isNotEmpty) _selectedPaymentReason = _reasonOptions.first.code;
        _selectedPaymentMethod = null;
        _selectedType = null;
        if (_bankOptions.isNotEmpty) _selectedBankCode = _bankOptions.first.code;
      });
    } catch (e) {
      setState(() => _isLoadingOptions = false);
      debugPrint('Error loading options: $e');
    }
  }

  Future<List<Partner>> _searchPartners(String query) async {
    if (_selectedType == null) return [];
    try {
      final response = await ApiClient().get('/v2/payment-request/recipient-options?type=$_selectedType&query=${Uri.encodeQueryComponent(query)}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((row) => Partner.fromJson({'id': row['id'], 'number': '', 'type': 'INDIVIDUAL', 'name1': '', 'name2': row['name'] ?? '', 'name3': '', 'identityNumber': '', 'status': 'ACTIVE'})).toList();
      }
    } catch (e) {
      debugPrint('Error searching partners: $e');
    }
    return [];
  }

  Future<void> _submit() async {
    if (_selectedType == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select payment request type before proceeding'))); return; }
    if (!_formKey.currentState!.validate() || _selectedRecipient == null) {
      if (_selectedRecipient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a recipient'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bool isEFT = _selectedPaymentMethod == 'EFT';
      
      String? bankName;
      if (isEFT && _selectedBankCode != null) {
        final selectedBank = _bankOptions.firstWhere((opt) => opt.code == _selectedBankCode);
        bankName = selectedBank.description;
      }

      final payload = {
        "requestType": _selectedType,
        "sourceType": "MANUAL",
        "payeePartnerId": _selectedRecipient!.id,
        "payeeName": _selectedRecipient!.fullName,
        "amount": double.tryParse(_amountController.text) ?? 0.0,
        "currency": "ZAR",
        "paymentMethod": _selectedPaymentMethod,
        "bankName": isEFT ? bankName : null,
        "accountHolder": isEFT ? _accountHolderController.text : null,
        "accountNumber": isEFT ? _accountNumberController.text : null,
        "branchCode": isEFT ? _branchCodeController.text : null,
        "accountType": isEFT ? _selectedAccountType : null,
        "externalReference": _referenceController.text,
        "paymentReason": _selectedPaymentReason,
        "notes": _notesController.text,
        "requestedPaymentDate": DateFormat('yyyy-MM-dd').format(_dueDate)
      };

      await PaymentRequestService().createPaymentRequest(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment request created successfully'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('New Payment Request'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.category_outlined, 'Payment Request Type'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(value: _selectedType, decoration: const InputDecoration(labelText: 'Select type first', border: OutlineInputBorder()), items: _typeOptions.map((o)=>DropdownMenuItem(value:o.code,child:Text(o.description))).toList(), onChanged:(v)=>setState((){_selectedType=v;_selectedRecipient=null;}), validator:(v)=>v==null?'Payment request type is required':null),
                    const SizedBox(height: 24),
                    if (_selectedType != null) ...[
                    _buildSectionHeader(Icons.person_outline, 'Recipient'),
                    const SizedBox(height: 8),
                    _buildRecipientSearch(),
                    if (_selectedRecipient != null) _buildSelectedRecipientCard(colorScheme),
                    const SizedBox(height: 24),],

                    _buildSectionHeader(Icons.payment_outlined, 'Payment Details'),
                    const SizedBox(height: 8),
                    _buildPaymentDetailsCard(colorScheme),
                    const SizedBox(height: 24),

                    if (_selectedPaymentMethod == 'EFT') ...[
                      _buildSectionHeader(Icons.account_balance_outlined, 'Bank Account Details'),
                      const SizedBox(height: 8),
                      _buildBankDetailsCard(colorScheme),
                      const SizedBox(height: 32),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('CREATE PAYMENT REQUEST', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildRecipientSearch() {
    return SearchAnchor(
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          onTap: () => controller.openView(),
          onChanged: (_) => controller.openView(),
          leading: const Icon(Icons.search, size: 20),
          hintText: 'Search for a recipient (Partner)...',
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final partners = await _searchPartners(controller.text);
        if (partners.isEmpty) return [const ListTile(title: Text('No partners found'))];
        return partners.map((partner) {
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
            title: Text(partner.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('No: ${partner.number}'),
            onTap: () {
              setState(() {
                _selectedRecipient = partner;
                _accountHolderController.text = partner.fullName; 
                controller.closeView(partner.fullName);
              });
            },
          );
        }).toList();
      },
    );
  }

  Widget _buildSelectedRecipientCard(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
        ),
        color: colorScheme.primary.withOpacity(0.05),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.person),
          ),
          title: Text(_selectedRecipient!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('ID: ${_selectedRecipient!.identityNumber} • No: ${_selectedRecipient!.number}'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedRecipient = null),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDropdown('Request Type', _selectedType, _typeOptions, (val) => setState(() => _selectedType = val)),
            const SizedBox(height: 16),
            _buildDropdown('Payment Reason', _selectedPaymentReason, _reasonOptions, (val) => setState(() => _selectedPaymentReason = val)),
            const SizedBox(height: 16),
            _buildTextField(_referenceController, 'External Reference', Icons.tag),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(_amountController, 'Amount', Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 16),
                Expanded(child: _buildDatePicker('Requested Payment Date')),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown('Payment Method', _selectedPaymentMethod, _methodOptions, (val) => setState(() => _selectedPaymentMethod = val)),
            const SizedBox(height: 16),
            _buildTextField(_notesController, 'Notes', Icons.notes, isRequired: false),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsCard(ColorScheme colorScheme) {
    final bool isEFT = _selectedPaymentMethod == 'EFT';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(_accountHolderController, 'Account Holder', Icons.account_circle_outlined, isRequired: isEFT),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDropdown('Bank Name', _selectedBankCode, _bankOptions, (val) => setState(() => _selectedBankCode = val), isRequired: isEFT)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_branchCodeController, 'Branch Code', Icons.numbers, isRequired: isEFT)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(_accountNumberController, 'Account Number', Icons.numbers, isRequired: isEFT),
            const SizedBox(height: 16),
            _buildDropdown('Account Type', _selectedAccountType, _accountTypeOptions, (val) => setState(() => _selectedAccountType = val), isRequired: isEFT),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      keyboardType: keyboardType,
      validator: (val) {
        if (isRequired && (val == null || val.isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, String? value, List<FieldOption> options, Function(String?) onChanged, {bool isRequired = true}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: options.map((opt) => DropdownMenuItem(
        value: opt.code,
        child: Text(opt.description, style: const TextStyle(fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
      validator: (val) {
        if (isRequired && val == null) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(String label) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dueDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _dueDate = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('yyyy-MM-dd').format(_dueDate), style: const TextStyle(fontSize: 14)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }
}
