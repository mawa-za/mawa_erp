import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';

class FnbIntegrationAdminScreen extends StatefulWidget {
  const FnbIntegrationAdminScreen({super.key});

  @override
  State<FnbIntegrationAdminScreen> createState() => _FnbIntegrationAdminScreenState();
}

class _FnbIntegrationAdminScreenState extends State<FnbIntegrationAdminScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;

  final _baseUrl = TextEditingController();
  final _clientIdSecret = TextEditingController();
  final _clientSecretSecret = TextEditingController();
  final _popRecipient = TextEditingController();
  final _accountNumberSecret = TextEditingController();
  final _accountHolder = TextEditingController();
  final _branchCode = TextEditingController();
  final _accountType = TextEditingController();
  final _bankName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _clientIdSecret.dispose();
    _clientSecretSecret.dispose();
    _popRecipient.dispose();
    _accountNumberSecret.dispose();
    _accountHolder.dispose();
    _branchCode.dispose();
    _accountType.dispose();
    _bankName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/integrations/fnb/settings');
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        _enabled = data['enabled'] == true;
        _baseUrl.text = data['baseUrl']?.toString() ?? '';
        _clientIdSecret.text = data['clientIdSecret']?.toString() ?? '';
        _clientSecretSecret.text = data['clientSecretSecret']?.toString() ?? '';
        _popRecipient.text = data['popRecipient']?.toString() ?? '';
        _accountNumberSecret.text = data['debtorAccountNumberSecret']?.toString() ?? '';
        _accountHolder.text = data['debtorAccountHolder']?.toString() ?? '';
        _branchCode.text = data['debtorBranchCode']?.toString() ?? '';
        _accountType.text = data['debtorAccountType']?.toString() ?? '';
        _bankName.text = data['debtorBankName']?.toString() ?? '';
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load FNB settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'enabled': _enabled,
        'baseUrl': _baseUrl.text.trim(),
        'clientIdSecret': _clientIdSecret.text.trim(),
        'clientSecretSecret': _clientSecretSecret.text.trim(),
        'popRecipient': _popRecipient.text.trim(),
        'debtorAccountNumberSecret': _accountNumberSecret.text.trim(),
        'debtorAccountHolder': _accountHolder.text.trim(),
        'debtorBranchCode': _branchCode.text.trim(),
        'debtorAccountType': _accountType.text.trim(),
        'debtorBankName': _bankName.text.trim(),
      };
      final response = await _api.put('/v2/integrations/fnb/settings', body: body);
      if (response.statusCode != 200) throw Exception(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FNB integration settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save FNB settings: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FNB Integration Administration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: SwitchListTile(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('Enable FNB payment integration'),
                      subtitle: const Text('When enabled, approved EFT payment requests can be queued for FNB.'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section('API Credentials'),
                  _field(_baseUrl, 'FNB Base URL', required: true),
                  _field(_clientIdSecret, 'Client ID Secret Name', required: true),
                  _field(_clientSecretSecret, 'Client Secret Secret Name', required: true),
                  _field(_popRecipient, 'Proof of Payment Recipient'),
                  const SizedBox(height: 12),
                  _section('Debtor Account'),
                  _field(_accountNumberSecret, 'Account Number Secret Name'),
                  _field(_accountHolder, 'Account Holder'),
                  _field(_branchCode, 'Branch Code'),
                  _field(_accountType, 'Account Type'),
                  _field(_bankName, 'Bank Name'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save FNB Settings'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _field(TextEditingController controller, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null : null,
      ),
    );
  }
}
