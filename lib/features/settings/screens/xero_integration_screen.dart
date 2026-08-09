import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';
import '../services/xero_integration_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class XeroIntegrationScreen extends StatefulWidget {
  const XeroIntegrationScreen({super.key});

  @override
  State<XeroIntegrationScreen> createState() => _XeroIntegrationScreenState();
}

class _XeroIntegrationScreenState extends State<XeroIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _redirectUrlController = TextEditingController();
  final _service = XeroIntegrationService();

  bool _invoiceIntegrationEnabled = true;
  bool _saving = false;
  bool _loadingConnections = false;
  bool _deactivating = false;
  bool _obscureSecret = true;
  List<XeroConnection> _connections = const [];
  String? _selectedTenantId;
  String? _statusMessage;
  String? _authenticationUrl;
  String? _clientIdSecretName;
  String? _clientSecretSecretName;
  String? _refreshTokenSecretName;
  String? _tenantIdSecretName;
  String? _accessTokenSecretName;

  @override
  void initState() {
    super.initState();
    final host = Config.apiHost.trim();
    if (host.isNotEmpty) {
      _redirectUrlController.text = 'https://$host/xero/callback';
    }
    _loadSecretNames();
    _loadConnections(showErrors: false);
  }

  Future<void> _loadSecretNames() async {
    try {
      final result = await _service.secretNames();
      if (!mounted) return;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _clientIdSecretName = result.clientIdSecret;
        _clientSecretSecretName = result.clientSecretSecret;
        _refreshTokenSecretName = result.refreshTokenSecret;
        _tenantIdSecretName = result.tenantIdSecret;
        _accessTokenSecretName = result.accessTokenSecret;
        if ((result.redirectUrl ?? '').trim().isNotEmpty) {
          _redirectUrlController.text = result.redirectUrl!;
        }
      });
    } catch (_) {
      // The activation call still generates and returns the same fixed names.
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUrlController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      final result = await _service.activate(
        clientId: _clientIdController.text.trim(),
        clientSecret: _clientSecretController.text,
        redirectUrl: _redirectUrlController.text.trim(),
        invoiceIntegrationEnabled: _invoiceIntegrationEnabled,
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = result.message;
        _authenticationUrl = result.authenticationUrl;
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _clientIdSecretName = result.clientIdSecret;
        _clientSecretSecretName = result.clientSecretSecret;
        _refreshTokenSecretName = result.refreshTokenSecret;
        _tenantIdSecretName = result.tenantIdSecret;
        _accessTokenSecretName = result.accessTokenSecret;
      });

      final authUrl = result.authenticationUrl;
      if (authUrl != null && authUrl.trim().isNotEmpty) {
        await _openAuthenticationUrl(authUrl);
      }
    } catch (error) {
      if (mounted) _showError('Xero activation failed', error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAuthenticationUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) {
      _showError('Unable to open Xero', 'The authentication URL is invalid.');
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched && mounted) {
      _showError('Unable to open Xero', 'Open the authentication link manually and return to this screen.');
    }
  }

  Future<void> _loadConnections({bool showErrors = true}) async {
    setState(() => _loadingConnections = true);
    try {
      final connections = await _service.connections();
      if (!mounted) return;
      setState(() {
        _connections = connections;
        if (connections.isEmpty) {
          _invoiceIntegrationEnabled = false;
          _selectedTenantId = null;
        }
        _statusMessage = connections.isEmpty
            ? 'No authorised Xero organisations were found. Activate or reconnect Xero first.'
            : '${connections.length} Xero organisation${connections.length == 1 ? '' : 's'} available.';
      });
    } catch (error) {
      if (!mounted) return;
      final reconnectRequired = error is XeroIntegrationException &&
          error.reauthorisationRequired;
      final message = friendlyErrorMessage(error);
      setState(() {
        _connections = const [];
        _selectedTenantId = null;
        if (reconnectRequired) {
          _invoiceIntegrationEnabled = false;
        }
        _statusMessage = message.isEmpty
            ? 'Unable to load Xero organisations. Activate or reconnect Xero.'
            : message;
      });
      if (showErrors && !reconnectRequired) {
        _showError('Unable to load Xero organisations', error);
      }
    } finally {
      if (mounted) setState(() => _loadingConnections = false);
    }
  }

  Future<void> _selectConnection(XeroConnection connection) async {
    setState(() => _selectedTenantId = connection.tenantId);
    try {
      final result = await _service.selectTenant(connection.tenantId);
      if (!mounted) return;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _selectedTenantId = result.selectedTenantId ?? connection.tenantId;
        _statusMessage = result.message ?? 'Xero organisation selected.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Xero organisation selected')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectedTenantId = null);
      _showError('Unable to select Xero organisation', error);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Xero integration?'),
        content: const Text(
          'Invoice synchronisation will be disabled. Stored secret references are retained so that the integration can be reconnected later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deactivating = true);
    try {
      final result = await _service.deactivate();
      if (!mounted) return;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _selectedTenantId = null;
        _statusMessage = result.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Xero integration deactivated')),
      );
    } catch (error) {
      if (mounted) _showError('Unable to deactivate Xero', error);
    } finally {
      if (mounted) setState(() => _deactivating = false);
    }
  }

  void _showError(String title, Object error) {
    final message = friendlyErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Xero Integration'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xero invoice integration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _statusMessage ?? 'Save the Xero application credentials, authorise access, then select the organisation to use for invoice synchronisation.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generated GCP Secret Names', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('These tenant-specific names are generated automatically and cannot be changed.'),
                  const SizedBox(height: 12),
                  _secretNameRow('Client ID', _clientIdSecretName),
                  _secretNameRow('Client Secret', _clientSecretSecretName),
                  _secretNameRow('Refresh Token', _refreshTokenSecretName),
                  _secretNameRow('Access Token', _accessTokenSecretName),
                  _secretNameRow('Xero Tenant ID', _tenantIdSecretName),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Activate or reconnect', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Xero Client ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Xero Client ID is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientSecretController,
                      obscureText: _obscureSecret,
                      decoration: InputDecoration(
                        labelText: 'Xero Client Secret',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscureSecret ? 'Show secret' : 'Hide secret',
                          onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                          icon: Icon(_obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Xero Client Secret is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _redirectUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Redirect URL',
                        helperText: 'This must match the redirect URL configured in the Xero application.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        return uri == null || !uri.hasScheme || uri.host.isEmpty ? 'Enter a valid redirect URL' : null;
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _invoiceIntegrationEnabled,
                      onChanged: (value) => setState(() => _invoiceIntegrationEnabled = value),
                      title: const Text('Enable invoice integration'),
                      subtitle: const Text('Allow approved MAWA invoices to be synchronised to the selected Xero organisation.'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _activate,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.link_outlined),
                          label: Text(_saving ? 'Saving…' : 'Activate / Reconnect'),
                        ),
                        if (_authenticationUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => _openAuthenticationUrl(_authenticationUrl!),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open Xero Authorisation'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Authorised organisations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: 'Refresh organisations',
                        onPressed: _loadingConnections ? null : () => _loadConnections(),
                        icon: _loadingConnections
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_connections.isEmpty && !_loadingConnections)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No Xero organisations available yet.'),
                    )
                  else
                    ..._connections.map(
                      (connection) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: connection.tenantId,
                        groupValue: _selectedTenantId,
                        onChanged: (_) => _selectConnection(connection),
                        title: Text(connection.tenantName?.trim().isNotEmpty == true ? connection.tenantName! : connection.tenantId),
                        subtitle: Text([
                          if (connection.tenantType?.trim().isNotEmpty == true) connection.tenantType!,
                          connection.tenantId,
                        ].join(' • ')),
                      ),
                    ),
                  const Divider(height: 28),
                  OutlinedButton.icon(
                    onPressed: _deactivating ? null : _deactivate,
                    icon: _deactivating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_off_outlined),
                    label: Text(_deactivating ? 'Deactivating…' : 'Deactivate Xero'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secretNameRow(String label, String? name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: SelectableText((name ?? '').isEmpty ? 'Loading…' : name!)),
        ],
      ),
    );
  }
}
