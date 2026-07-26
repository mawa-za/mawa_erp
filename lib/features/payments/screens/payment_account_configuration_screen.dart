import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';

class PaymentAccountConfigurationScreen extends StatefulWidget {
  const PaymentAccountConfigurationScreen({super.key});

  @override
  State<PaymentAccountConfigurationScreen> createState() => _PaymentAccountConfigurationScreenState();
}

class _PaymentAccountConfigurationScreenState extends State<PaymentAccountConfigurationScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _rows = [];
  List<FieldOption> _bankOptions = [];
  List<FieldOption> _accountTypeOptions = [];
  List<FieldOption> _requestTypeOptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/v2/payment-account-configuration'),
        FieldService().getOptionsByField('BANK-NAME'),
        FieldService().getOptionsByField('BANK-ACCOUNT-TYPE'),
        FieldService().getOptionsByField('PAYMENT-REQUEST-TYPE'),
      ]);
      final response = results[0] as dynamic;
      if (response.statusCode != 200) throw Exception(response.body);
      if (!mounted) return;
      setState(() {
        _rows = (jsonDecode(response.body) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _bankOptions = results[1] as List<FieldOption>;
        _accountTypeOptions = results[2] as List<FieldOption>;
        _requestTypeOptions = results[3] as List<FieldOption>;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment account configuration: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    String role = existing?['account_role']?.toString() ?? 'DEBTOR';
    String? requestType = existing?['request_type']?.toString();
    String? bankIntegration = existing?['bank_integration']?.toString();
    String? bankName = existing?['bank_name']?.toString();
    String? accountType = existing?['account_type']?.toString();
    bool active = existing?['active'] == null || existing?['active'] == true || existing?['active'] == 1;
    final holder = TextEditingController(text: existing?['account_holder']?.toString() ?? '');
    final number = TextEditingController(text: existing?['account_number']?.toString() ?? '');

    bankName ??= _bankOptions.isEmpty ? null : _bankOptions.first.code;
    if (role == 'PAYROLL_DEBTOR') {
      bankIntegration = 'FNB';
      bankName = 'FNB';
    }
    accountType ??= _accountTypeOptions.isEmpty ? null : _accountTypeOptions.first.code;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add payment account' : 'Edit payment account'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Debtor accounts fund payment requests. Creditor accounts identify internal receiving accounts such as petty cash.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Account role',
                        helperText: 'Choose how this account is used by payment processing.',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'DEBTOR', child: Text('Debtor account')),
                        DropdownMenuItem(
                          value: 'PAYROLL_DEBTOR',
                          child: Text('Payroll debtor account'),
                        ),
                        DropdownMenuItem(
                          value: 'PETTY_CASH_CREDITOR',
                          child: Text('Petty cash creditor account'),
                        ),
                        DropdownMenuItem(
                          value: 'CASH_CLAIM_CREDITOR',
                          child: Text('Cash claim creditor account'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        role = value ?? 'DEBTOR';
                        if (role != 'DEBTOR') requestType = null;
                        if (role == 'PAYROLL_DEBTOR') {
                          bankIntegration = 'FNB';
                          bankName = 'FNB';
                        } else if (role != 'DEBTOR') {
                          bankIntegration = null;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (role == 'DEBTOR') ...[
                      DropdownButtonFormField<String>(
                        value: _valueInOptions(requestType, _requestTypeOptions),
                        decoration: const InputDecoration(
                          labelText: 'Payment request type',
                          helperText: 'This account will fund the selected request type.',
                          border: OutlineInputBorder(),
                        ),
                        items: _requestTypeOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.code,
                                child: Text(option.description),
                              ),
                            )
                            .toList(),
                        validator: (value) => value == null ? 'Payment request type is required' : null,
                        onChanged: (value) => setDialogState(() => requestType = value),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (role == 'DEBTOR' || role == 'PAYROLL_DEBTOR') ...[
                      DropdownButtonFormField<String>(
                        value: role == 'PAYROLL_DEBTOR' ? 'FNB' : bankIntegration,
                        decoration: InputDecoration(
                          labelText: 'Bank integration',
                          helperText: role == 'PAYROLL_DEBTOR'
                              ? 'Payroll batches are submitted as one FNB batch-booking instruction.'
                              : 'Select FNB for automated FNB payments, or Manual for offline processing.',
                          border: const OutlineInputBorder(),
                        ),
                        items: role == 'PAYROLL_DEBTOR'
                            ? const [DropdownMenuItem(value: 'FNB', child: Text('FNB'))]
                            : const [
                                DropdownMenuItem(value: 'FNB', child: Text('FNB')),
                                DropdownMenuItem(value: 'MANUAL', child: Text('Manual / no bank API')),
                              ],
                        onChanged: role == 'PAYROLL_DEBTOR'
                            ? null
                            : (value) => setDialogState(() => bankIntegration = value),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: role == 'PAYROLL_DEBTOR'
                          ? _valueInOptions('FNB', _bankOptions)
                          : _valueInOptions(bankName, _bankOptions),
                      decoration: InputDecoration(
                        labelText: 'Bank name',
                        helperText: role == 'PAYROLL_DEBTOR'
                            ? 'Automated payroll batches require an FNB debtor account.'
                            : 'Values are maintained under BANK-NAME.',
                        border: const OutlineInputBorder(),
                      ),
                      items: (role == 'PAYROLL_DEBTOR'
                              ? _bankOptions.where((option) => option.code.toUpperCase() == 'FNB')
                              : _bankOptions)
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.code,
                              child: Text(option.description),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null ? 'Bank name is required' : null,
                      onChanged: role == 'PAYROLL_DEBTOR'
                          ? null
                          : (value) => setDialogState(() => bankName = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: holder,
                      decoration: const InputDecoration(
                        labelText: 'Account holder',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: number,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)],
                      decoration: const InputDecoration(
                        labelText: 'Account number',
                        helperText: 'Enter 5 to 20 numeric digits.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => RegExp(r'^\d{5,20}$').hasMatch(value ?? '')
                          ? null
                          : 'Enter 5 to 20 numeric digits',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The universal branch code is assigned automatically from the selected bank.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _valueInOptions(accountType, _accountTypeOptions),
                      decoration: const InputDecoration(
                        labelText: 'Bank account type',
                        helperText: 'Values are maintained under BANK-ACCOUNT-TYPE.',
                        border: OutlineInputBorder(),
                      ),
                      items: _accountTypeOptions
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.code,
                              child: Text(option.description),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null ? 'Bank account type is required' : null,
                      onChanged: (value) => setDialogState(() => accountType = value),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Active'),
                      subtitle: const Text('Only active accounts can be selected by payment processing.'),
                      onChanged: (value) => setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      final response = await _api.post(
        '/v2/payment-account-configuration',
        body: {
          if (existing?['id'] != null) 'id': existing!['id'],
          'accountRole': role,
          'requestType': role == 'DEBTOR' ? requestType : null,
          'bankIntegration': role == 'PAYROLL_DEBTOR' ? 'FNB' : (role == 'DEBTOR' ? bankIntegration : null),
          'bankName': bankName,
          'accountHolder': holder.text.trim(),
          'accountNumber': number.text.trim(),
          'accountType': accountType,
          'active': active,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) throw Exception(response.body);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment account: $error')),
        );
      }
    }
  }

  String? _valueInOptions(String? value, List<FieldOption> options) {
    if (value == null) return null;
    return options.any((option) => option.code == value) ? value : null;
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Account Configuration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('No payment accounts configured.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final active = row['active'] == true || row['active'] == 1;
                    final requestType = row['request_type']?.toString();
                    return Card(
                      child: ListTile(
                        leading: Icon(active ? Icons.account_balance : Icons.account_balance_outlined),
                        title: Text(
                          '${_roleLabel(row['account_role']?.toString())}${requestType == null ? '' : ' — $requestType'}',
                        ),
                        subtitle: Text(
                          '${row['bank_name'] ?? ''} • ${row['account_holder'] ?? ''} • ${_mask(row['account_number'])}\n'
                          '${row['account_type'] ?? ''} • Universal branch ${row['branch_code'] ?? '-'}${row['bank_integration'] == null ? '' : ' • ${row['bank_integration']}'}',
                        ),
                        isThreeLine: true,
                        trailing: Chip(label: Text(active ? 'Active' : 'Inactive')),
                        onTap: () => _edit(row),
                      ),
                    );
                  },
                ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'DEBTOR':
        return 'Debtor account';
      case 'PAYROLL_DEBTOR':
        return 'Payroll debtor account';
      case 'PETTY_CASH_CREDITOR':
        return 'Petty cash creditor';
      case 'CASH_CLAIM_CREDITOR':
        return 'Cash claim creditor';
      default:
        return role ?? 'Payment account';
    }
  }

  String _mask(Object? value) {
    final text = value?.toString() ?? '';
    if (text.length <= 4) return '****';
    return '****${text.substring(text.length - 4)}';
  }
}
