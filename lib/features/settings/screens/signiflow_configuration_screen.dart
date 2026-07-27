import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class SigniFlowConfigurationScreen extends StatefulWidget {
  const SigniFlowConfigurationScreen({super.key});

  @override
  State<SigniFlowConfigurationScreen> createState() =>
      _SigniFlowConfigurationScreenState();
}

class _SigniFlowConfigurationScreenState extends State<SigniFlowConfigurationScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _baseUrl = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _dueDays = TextEditingController(text: '7');
  bool _enabled = false;
  bool _sendWorkflowEmails = true;
  bool _sendFirstEmail = true;
  bool _passwordConfigured = false;
  bool _obscure = true;
  bool _loading = true;
  bool _saving = false;
  String _secretName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _username.dispose();
    _password.dispose();
    _dueDays.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/signiflow/configuration');
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true || data['enabled'] == 1;
        _baseUrl.text = data['base_url']?.toString() ?? '';
        _username.text = data['username']?.toString() ?? '';
        _dueDays.text = data['default_due_days']?.toString() ?? '7';
        _sendWorkflowEmails = data['send_workflow_emails'] == true ||
            data['send_workflow_emails'] == 1;
        _sendFirstEmail = data['send_first_email'] == true ||
            data['send_first_email'] == 1;
        _passwordConfigured = data['password_configured'] == true;
        _secretName = data['password_secret_name']?.toString() ?? '';
        _password.clear();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to load SigniFlow configuration: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final response = await _api.put('/v2/signiflow/configuration', body: {
        'enabled': _enabled,
        'baseUrl': _baseUrl.text.trim(),
        'username': _username.text.trim(),
        'password': _password.text,
        'defaultDueDays': int.parse(_dueDays.text),
        'sendWorkflowEmails': _sendWorkflowEmails,
        'sendFirstEmail': _sendFirstEmail,
      });
      if (response.statusCode != 200) throw AppException(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SigniFlow configuration saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Unable to save SigniFlow configuration: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    try {
      final response = await _api.post('/v2/signiflow/configuration/test');
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Connection succeeded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('SigniFlow connection failed: $error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SigniFlow Electronic Signatures')),
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
                      title: const Text('Enable SigniFlow claim form signatures'),
                      subtitle: const Text(
                        'Generated claim forms can be sent to a member, claimant or dependent for electronic signature.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      labelText: 'SigniFlow API service URL',
                      helperText: 'Example: https://your-server/API/SignFlowAPIServiceRest.svc',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _enabled && (value == null || value.trim().isEmpty)
                        ? 'Service URL is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _enabled && (value == null || value.trim().isEmpty)
                        ? 'Username is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: _passwordConfigured
                          ? 'Password (leave blank to retain existing secret)'
                          : 'Password',
                      helperText: _secretName.isEmpty
                          ? 'Stored in Google Secret Manager.'
                          : 'Secret: $_secretName',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) => _enabled && !_passwordConfigured &&
                            (value == null || value.isEmpty)
                        ? 'Password is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dueDays,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Default signature due days',
                      helperText: 'Between 1 and 90 days',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      return number == null || number < 1 || number > 90
                          ? 'Enter a value between 1 and 90'
                          : null;
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sendFirstEmail,
                    title: const Text('Send initial signing email'),
                    onChanged: (value) => setState(() => _sendFirstEmail = value ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sendWorkflowEmails,
                    title: const Text('Send workflow status emails'),
                    onChanged: (value) =>
                        setState(() => _sendWorkflowEmails = value ?? true),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save configuration'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _test,
                        icon: const Icon(Icons.network_check_outlined),
                        label: const Text('Test connection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
