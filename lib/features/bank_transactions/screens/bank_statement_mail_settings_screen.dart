import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bank_transaction_service.dart';

class BankStatementMailSettingsScreen extends StatefulWidget {
  const BankStatementMailSettingsScreen({super.key});
  @override State<BankStatementMailSettingsScreen> createState() => _BankStatementMailSettingsScreenState();
}

class _BankStatementMailSettingsScreenState extends State<BankStatementMailSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _service = BankTransactionService();
  final _mailbox = TextEditingController();
  final _sender = TextEditingController();
  final _subject = TextEditingController();
  final _tenant = TextEditingController();
  final _client = TextEditingController();
  final _clientSecretRef = TextEditingController();
  final _refreshTokenRef = TextEditingController();
  final _lookback = TextEditingController(text: '14');
  final _accounts = TextEditingController();
  String _provider = 'MICROSOFT_365_SAAS';
  String _microsoftStatus = 'DISCONNECTED';
  String _connectedDirectory = '';
  String _centralAppId = '';
  String? _infoError;
  String? _lastSync;
  bool _enabled = false;
  bool _requireDmarc = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    for (final c in [_mailbox, _sender, _subject, _tenant, _client, _clientSecretRef, _refreshTokenRef, _lookback, _accounts]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _service.getConfiguration();
      if (!mounted) return;
      setState(() {
        _provider = c['provider'] == 'GMAIL' ? 'GMAIL' :
          c['provider'] == 'MICROSOFT_365' ? 'MICROSOFT_365' : 'MICROSOFT_365_SAAS';
        _microsoftStatus = c['connectionStatus']?.toString() ?? 'DISCONNECTED';
        _connectedDirectory = c['connectedDirectoryId']?.toString() ?? '';
        _mailbox.text = c['mailbox']?.toString() ?? '';
        _sender.text = c['sender']?.toString() ?? '';
        _subject.text = c['subjectFilter']?.toString() ?? '';
        _tenant.text = c['tenantId']?.toString() ?? '';
        _client.text = c['clientId']?.toString() ?? '';
        _clientSecretRef.text = c['clientSecretRef']?.toString() ?? '';
        _refreshTokenRef.text = c['refreshTokenRef']?.toString() ?? '';
        _lookback.text = c['lookbackDays']?.toString() ?? '14';
        _accounts.text = c['accountNumbers']?.toString() ?? '';
        _requireDmarc = c['requireDmarc'] != false;
        _lastSync = c['lastSuccessDate']?.toString();
        _enabled = c['enabled'] == true;
      });
      try {
        final info = await _service.getMicrosoftAppInfo();
        if (mounted) setState(() { _centralAppId = info['applicationId']?.toString() ?? ''; _infoError = null; });
      } catch (e) { if (mounted) setState(() => _infoError = e.toString()); }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Map<String, dynamic> get _configuration => {
    'enabled': _enabled, 'provider': _provider, 'mailbox': _mailbox.text.trim(),
    'sender': _sender.text.trim(), 'subjectFilter': _subject.text.trim(),
    'tenantId': _tenant.text.trim(), 'clientId': _client.text.trim(),
    'clientSecretRef': _clientSecretRef.text.trim(),
    'refreshTokenRef': _refreshTokenRef.text.trim(),
    'lookbackDays': int.tryParse(_lookback.text) ?? 14,
    'accountNumbers': _accounts.text.trim(), 'requireDmarc': _requireDmarc,
  };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; _notice = null; });
    try {
      await _service.saveConfiguration(_configuration);
      if (mounted) setState(() => _notice = 'Tenant mailbox settings saved.');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _connectMicrosoft() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; _notice = null; });
    try {
      // Never enable imports before mailbox-scoped Exchange authorization is verified.
      await _service.saveConfiguration({..._configuration, 'enabled': false});
      final link = await _service.connectMicrosoft();
      if (link.isEmpty || !link.startsWith('https://login.microsoftonline.com/')) {
        throw StateError('Invalid Microsoft authorization URL');
      }
      if (!await launchUrl(Uri.parse(link), webOnlyWindowName: '_self')) {
        throw StateError('Could not open Microsoft sign-in. Allow redirects for this site.');
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _verifyMicrosoft() async {
    setState(() { _saving = true; _error = null; _notice = null; });
    try {
      await _service.verifyMicrosoft();
      await _load();
      if (mounted) setState(() => _notice = 'Microsoft mailbox access verified. You can now enable daily imports.');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _disconnectMicrosoft() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Disconnect Microsoft 365?'),
      content: const Text('This stops new bank statement imports for this MAWA tenant. Previously imported transactions remain available.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect'))],
    ));
    if (confirmed != true) return;
    setState(() { _saving = true; _error = null; _notice = null; });
    try {
      await _service.disconnectMicrosoft();
      await _load();
      if (mounted) setState(() => _notice = 'Microsoft organization disconnected from this MAWA tenant.');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _sync() async {
    setState(() { _saving = true; _error = null; _notice = null; });
    try {
      final response = await _service.syncNow();
      if (mounted) setState(() => _notice =
        'Import completed: ${response['newTransactions']} new transactions in ${response['attachments']} attachments; ${response['failures']} failed.');
      await _load();
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _field(TextEditingController controller, String label, {bool required = false, String? helper}) =>
    TextFormField(controller: controller, decoration: InputDecoration(labelText: label, helperText: helper),
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null);

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bank Statement Mail Configuration')),
    body: _loading ? const Center(child: CircularProgressIndicator()) :
      SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child:
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Each MAWA tenant configures its own bank mailbox. For Microsoft 365, customers use the single MAWA-managed application. Imports run after 04:00 CAT.',
              style: TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Enable automatic bank statement imports'), value: _enabled,
              onChanged: _saving || (_provider == 'MICROSOFT_365_SAAS' && _microsoftStatus != 'VERIFIED')
                ? null : (v) => setState(() => _enabled = v)),
            DropdownButtonFormField<String>(initialValue: _provider, decoration: const InputDecoration(labelText: 'Provider'),
              items: const [
                DropdownMenuItem(value: 'MICROSOFT_365_SAAS', child: Text('Microsoft 365 (MAWA-managed)')),
                DropdownMenuItem(value: 'GMAIL', child: Text('Gmail')),
                DropdownMenuItem(value: 'MICROSOFT_365', child: Text('Microsoft 365 (legacy customer app)')),
              ],
              onChanged: _saving ? null : (v) => setState(() {
                _provider = v ?? 'MICROSOFT_365_SAAS';
                _enabled = false;
              })),
            _field(_mailbox, 'Mailbox email *', required: true),
            _field(_sender, 'Trusted bank statement sender email *', required: true),
            _field(_accounts, 'Allowed bank account numbers (comma-separated) *', required: true,
              helper: 'Enter the exact number(s) shown in the CSV, including leading zeros'),
            _field(_subject, 'Optional email subject contains'),
            SwitchListTile(title: const Text('Require DMARC-authenticated bank email'),
              subtitle: const Text('Recommended: reject messages that fail sender-domain authentication'),
              value: _requireDmarc, onChanged: _saving ? null : (v) => setState(() => _requireDmarc = v)),
            if (_provider == 'MICROSOFT_365') _field(_tenant, 'Microsoft Entra directory tenant ID *', required: true),
            if (_provider != 'MICROSOFT_365_SAAS') ...[
              _field(_client, 'OAuth client ID *', required: true),
              _field(_clientSecretRef, 'OAuth client secret reference *', required: true,
                helper: 'Google Secret Manager URI; secret values are never saved in MAWA settings'),
            ],
            if (_provider == 'MICROSOFT_365_SAAS') ...[
              const SizedBox(height: 16),
              Text('Microsoft organization: $_microsoftStatus', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_connectedDirectory.isNotEmpty) SelectableText('Microsoft Directory ID: $_connectedDirectory'),
              if (_centralAppId.isNotEmpty) Row(children: [
                Expanded(child: SelectableText('MAWA application ID: $_centralAppId')),
                IconButton(tooltip: 'Copy MAWA application ID', icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: _centralAppId))),
              ]),
              if (_infoError != null) Text(_infoError!, style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 8),
              const Text('1. Save the mailbox settings, then connect with an administrator account of the customer Microsoft 365 organization.\n'
                '2. The customer Exchange administrator grants Application Mail.Read through mailbox-scoped Exchange Online RBAC (not organization-wide Microsoft Graph Mail.Read).\n'
                '3. Verify mailbox access here, then enable automatic imports.'),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton.icon(onPressed: _saving ? null : _connectMicrosoft,
                  icon: const Icon(Icons.login), label: const Text('Connect Microsoft 365')),
                OutlinedButton.icon(onPressed: _saving || _connectedDirectory.isEmpty ? null : _verifyMicrosoft,
                  icon: const Icon(Icons.verified_outlined), label: const Text('Verify Mailbox Access')),
                TextButton.icon(onPressed: _saving || _connectedDirectory.isEmpty ? null : _disconnectMicrosoft,
                  icon: const Icon(Icons.link_off), label: const Text('Disconnect')),
              ]),
              const SizedBox(height: 8),
              const Text('Only work/school Microsoft 365 accounts are supported. Outlook.com personal mailboxes do not support app-only mailbox access.'),
            ],
            if (_provider == 'GMAIL') _field(_refreshTokenRef, 'Gmail refresh token secret reference *', required: true),
            TextFormField(controller: _lookback, decoration: const InputDecoration(labelText: 'Lookback window (1–365 days)'),
              keyboardType: TextInputType.number,
              validator: (v) { final d = int.tryParse(v ?? ''); return d == null || d < 1 || d > 365 ? 'Enter 1–365' : null; }),
            const SizedBox(height: 16),
            Text('Last successful import: ${_lastSync ?? 'Not yet'}'),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_notice != null) Text(_notice!, style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, children: [
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save Configuration')),
              OutlinedButton.icon(onPressed: _saving || !_enabled ? null : _sync,
                icon: const Icon(Icons.sync), label: const Text('Import Now')),
            ]),
            const SizedBox(height: 12),
            const Text('Supported attachments: FNB Account Transaction History CSV. '
              'Microsoft uses an organization-specific Exchange Online RBAC Application Mail.Read assignment. '
              'Gmail requires a consented Gmail read-only refresh token.'),
          ],
        ))))),
  );
}
