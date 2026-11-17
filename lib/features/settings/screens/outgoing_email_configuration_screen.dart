import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

/// Tenant-admin configuration of MAWA's outgoing Microsoft 365 transport.
/// Passwords/application secrets are write-only and never prefilled by the API.
class OutgoingEmailConfigurationScreen extends StatefulWidget {
  const OutgoingEmailConfigurationScreen({super.key});

  @override
  State<OutgoingEmailConfigurationScreen> createState() =>
      _OutgoingEmailConfigurationScreenState();
}

class _OutgoingEmailConfigurationScreenState
    extends State<OutgoingEmailConfigurationScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _senderName = TextEditingController();
  final _replyTo = TextEditingController();
  final _mailbox = TextEditingController();
  final _directoryId = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _testRecipient = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _enabled = true;
  bool _hasSecret = false;
  bool _showSecret = false;
  String _provider = 'MAWA_SHARED';

  bool get _tenantMicrosoft => _provider == 'TENANT_MICROSOFT_365';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _senderName, _replyTo, _mailbox, _directoryId,
      _clientId, _clientSecret, _testRecipient,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _emailValidator(String? raw, {bool required = false}) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return required ? 'Email address is required' : null;
    if (value.contains(RegExp(r'[\s,;<>]')) ||
        !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Enter one valid email address';
    }
    return null;
  }

  String? _uuidValidator(String? raw) {
    if (!RegExp(r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$')
        .hasMatch((raw ?? '').trim())) {
      return 'Enter a valid Microsoft Entra GUID';
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/outgoing-email/configuration');
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _provider = data['provider']?.toString() == 'TENANT_MICROSOFT_365'
            ? 'TENANT_MICROSOFT_365' : 'MAWA_SHARED';
        _senderName.text = data['senderName']?.toString() ?? '';
        _replyTo.text = data['replyTo']?.toString() ?? '';
        _mailbox.text = data['mailbox']?.toString() ?? '';
        _directoryId.text = data['directoryId']?.toString() ?? '';
        _clientId.text = data['clientId']?.toString() ?? '';
        _hasSecret = data['clientSecretConfigured'] == true;
        _clientSecret.clear();
      });
    } catch (error) {
      _notify(friendlyErrorMessage('Failed to load outgoing email configuration: $error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await _api.put('/v2/outgoing-email/configuration', body: {
        'enabled': _enabled,
        'provider': _provider,
        'senderName': _senderName.text.trim(),
        'replyTo': _replyTo.text.trim(),
        'mailbox': _mailbox.text.trim(),
        'directoryId': _directoryId.text.trim(),
        'clientId': _clientId.text.trim(),
        // Empty means keep the previously stored Google Secret Manager value.
        'clientSecret': _clientSecret.text,
      });
      if (response.statusCode != 200) throw AppException(response.body);
      _notify('Outgoing email configuration saved.');
      await _load();
    } catch (error) {
      _notify(friendlyErrorMessage('Unable to save outgoing email configuration: $error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTest() async {
    final validation = _emailValidator(_testRecipient.text, required: true);
    if (validation != null) {
      _notify(validation);
      return;
    }
    if (!_enabled) {
      _notify('Enable outgoing email and save before sending a test.');
      return;
    }
    setState(() => _testing = true);
    try {
      final response = await _api.post('/v2/outgoing-email/test',
          body: {'recipient': _testRecipient.text.trim()});
      if (response.statusCode != 200) throw AppException(response.body);
      _notify('Test submitted to Microsoft 365. Check the recipient inbox and junk folder.');
    } catch (error) {
      _notify(friendlyErrorMessage('Unable to send test email: $error'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: suffix,
      ),
      obscureText: obscure,
      validator: validator,
      autocorrect: false,
      enableSuggestions: !obscure,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outgoing Email Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('Outgoing email',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Configure the sender identity and Microsoft 365 account used by this tenant. '
                          'Supplier Invoice Email controls document-specific recipients and templates separately.'),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow outgoing emails'),
                                subtitle: const Text('Disabling stops new email submissions for this tenant.'),
                                value: _enabled,
                                onChanged: (value) => setState(() => _enabled = value),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _provider,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Sending account',
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'MAWA_SHARED',
                                      child: Text('MAWA-managed Microsoft 365 mailbox')),
                                  DropdownMenuItem(value: 'TENANT_MICROSOFT_365',
                                      child: Text('Tenant Microsoft 365 mailbox (Graph)')),
                                ],
                                onChanged: (value) => setState(() => _provider = value ?? 'MAWA_SHARED'),
                              ),
                              const SizedBox(height: 18),
                              _field(_senderName, 'Sender display name',
                                  hint: 'Default: company name',
                                  validator: (text) => (text ?? '').length > 120
                                      ? 'Maximum 120 characters' : null),
                              const SizedBox(height: 16),
                              _field(_replyTo, 'Reply-To email',
                                  hint: 'Default: company profile email',
                                  validator: (text) => _emailValidator(text)),
                              const SizedBox(height: 8),
                              if (!_tenantMicrosoft)
                                const Text('The From address is the central MAWA mailbox. '
                                    'Only the sender name and Reply-To can be customized.'),
                              if (_tenantMicrosoft) ...[
                                const Divider(height: 32),
                                const Text('Use a Microsoft Entra application with Graph Mail.Send '
                                    'permission restricted to this tenant mailbox in Exchange Online. '
                                    'Credentials are stored in Google Secret Manager, never in the ERP database.'),
                                const SizedBox(height: 18),
                                _field(_mailbox, 'Microsoft 365 sender mailbox *',
                                    validator: (text) => _emailValidator(text, required: true)),
                                const SizedBox(height: 16),
                                _field(_directoryId, 'Microsoft Entra directory (tenant) ID *',
                                    validator: _uuidValidator),
                                const SizedBox(height: 16),
                                _field(_clientId, 'Application (client) ID *',
                                    validator: _uuidValidator),
                                const SizedBox(height: 16),
                                _field(
                                  _clientSecret,
                                  _hasSecret ? 'New client secret (leave blank to keep existing)' : 'Client secret *',
                                  obscure: !_showSecret,
                                  validator: (value) => !_hasSecret && (value == null || value.isEmpty)
                                      ? 'Enter the Microsoft application secret' : null,
                                  suffix: IconButton(
                                    tooltip: _showSecret ? 'Hide secret' : 'Show secret',
                                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _showSecret = !_showSecret),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save configuration'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Send a test email',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Save configuration before testing. Microsoft 365 acceptance '
                          'does not guarantee inbox delivery.'),
                      const SizedBox(height: 12),
                      _field(_testRecipient, 'Test recipient email'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _sendTest,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(_testing ? 'Submitting...' : 'Send test email'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
