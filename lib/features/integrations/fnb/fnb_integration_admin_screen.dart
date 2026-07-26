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
  final _baseUrl = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _popRecipient = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _clientIdConfigured = false;
  bool _clientSecretConfigured = false;
  bool _debtorConfigured = false;
  bool _obscureClientSecret = true;
  String _clientIdSecretName = '';
  String _clientSecretSecretName = '';
  String _debtorSummary = 'No active FNB debtor account is configured.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _clientId.dispose();
    _clientSecret.dispose();
    _popRecipient.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/integrations/fnb/settings');
      if (response.statusCode != 200) throw Exception(response.body);
      _applySettings(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load FNB settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    _enabled = data['enabled'] == true;
    _baseUrl.text = data['baseUrl']?.toString() ?? '';
    _clientIdSecretName = data['clientIdSecret']?.toString() ?? '';
    _clientSecretSecretName = data['clientSecretSecret']?.toString() ?? '';
    _clientIdConfigured = data['clientIdConfigured'] == true;
    _clientSecretConfigured = data['clientSecretConfigured'] == true;
    _popRecipient.text = data['popRecipient']?.toString() ?? '';
    _debtorConfigured = data['debtorAccountNumberConfigured'] == true;
    if (_debtorConfigured) {
      final bank = data['debtorBankName']?.toString() ?? '';
      final holder = data['debtorAccountHolder']?.toString() ?? '';
      final account = data['debtorAccountNumber']?.toString() ?? '';
      final type = data['debtorAccountType']?.toString() ?? '';
      _debtorSummary = [bank, holder, account, type].where((value) => value.isNotEmpty).join(' • ');
    } else {
      _debtorSummary = 'No active FNB debtor account is configured.';
    }
    _clientId.clear();
    _clientSecret.clear();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await _api.put(
        '/v2/integrations/fnb/settings',
        body: {
          'enabled': _enabled,
          'baseUrl': _baseUrl.text.trim(),
          'clientId': _clientId.text.trim(),
          'clientSecret': _clientSecret.text,
          'popRecipient': _popRecipient.text.trim(),
        },
      );
      if (response.statusCode != 200) throw Exception(response.body);
      if (!mounted) return;
      setState(() => _applySettings(Map<String, dynamic>.from(jsonDecode(response.body) as Map)));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FNB integration settings saved')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save FNB settings: $error')),
        );
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
                      subtitle: const Text(
                        'Approved EFT requests are queued for FNB only when an active FNB debtor account exists.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section('API Credentials'),
                  _field(_baseUrl, 'FNB Base URL', required: true),
                  _secretValueField(
                    controller: _clientId,
                    label: 'FNB Client ID',
                    secretName: _clientIdSecretName,
                    configured: _clientIdConfigured,
                    requiredWhenEnabled: true,
                  ),
                  _secretValueField(
                    controller: _clientSecret,
                    label: 'FNB Client Secret',
                    secretName: _clientSecretSecretName,
                    configured: _clientSecretConfigured,
                    requiredWhenEnabled: true,
                    obscureText: _obscureClientSecret,
                    onToggleVisibility: () => setState(
                      () => _obscureClientSecret = !_obscureClientSecret,
                    ),
                  ),
                  _field(_popRecipient, 'Proof of Payment Recipient'),
                  const SizedBox(height: 12),
                  _section('Payment Account'),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _debtorConfigured ? Icons.verified_outlined : Icons.warning_amber_outlined,
                      ),
                      title: Text(_debtorConfigured ? 'FNB debtor account configured' : 'FNB debtor account required'),
                      subtitle: Text(
                        '$_debtorSummary\nManage debtor account details in Payment Account Configuration.',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save FNB Settings'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _field(TextEditingController controller, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _secretValueField({
    required TextEditingController controller,
    required String label,
    required String secretName,
    required bool configured,
    bool requiredWhenEnabled = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: configured ? '$label (leave blank to keep existing value)' : label,
              border: const OutlineInputBorder(),
              suffixIcon: onToggleVisibility == null
                  ? null
                  : IconButton(
                      tooltip: obscureText ? 'Show value' : 'Hide value',
                      onPressed: onToggleVisibility,
                      icon: Icon(
                        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
            ),
            validator: (value) {
              if (requiredWhenEnabled &&
                  _enabled &&
                  !configured &&
                  (value == null || value.trim().isEmpty)) {
                return '$label is required before enabling FNB integration';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Generated GCP Secret Name',
              helperText: configured
                  ? 'Configured in Google Secret Manager. The name cannot be changed.'
                  : 'The name is fixed and will be created when a value is saved.',
              border: const OutlineInputBorder(),
            ),
            child: SelectableText(secretName.isEmpty ? 'Unavailable' : secretName),
          ),
        ],
      ),
    );
  }
}
