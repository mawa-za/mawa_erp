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
  XeroAccountingConfiguration? _accountingConfiguration;
  String? _invoiceAccountId;
  String? _paymentAccountId;
  String? _invoiceTaxType;
  String? _accountingError;
  bool _accountingBusy = false;
  bool _selectingOrganisation = false;
  int _accountingGeneration = 0;

  bool get _configurationControlsBusy => _accountingBusy || _saving ||
      _loadingConnections || _deactivating || _selectingOrganisation || _updatingInvoiceIntegration;

  bool get _canSaveAccounting => !_configurationControlsBusy &&
      !_invoiceIntegrationEnabled && _accountingConfiguration != null &&
      _invoiceAccountId != null && _paymentAccountId != null && _invoiceTaxType != null;


  bool _invoiceIntegrationEnabled = false;
  bool _saving = false;
  bool _loadingConnections = false;
  bool _deactivating = false;
  bool _updatingInvoiceIntegration = false;
  bool _obscureSecret = true;
  bool _loadingReconciliation = false;
  bool _canCheckReconciliation = false;
  String? _checkingReconciliationId;
  String? _reconciliationNotice;
  List<Map<String, dynamic>> _reconciliationItems = const [];
  List<XeroConnection> _connections = const [];
  String? _selectedTenantId;
  String? _statusMessage;
  String? _integrationStatus;
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
    _refreshConnectionStatus(showErrors: false);
    _loadReconciliation();
  }

  /// After returning from Xero's browser consent screen, the backend callback
  /// has already finished. Refresh both the persistent status and organisations.
  Future<void> _refreshConnectionStatus({bool showErrors = true}) async {
    final loaded = await _loadSecretNames();
    if (!mounted || !loaded) return;
    final status = (_integrationStatus ?? '').toUpperCase();
    if (status == 'AUTHORISED' || status == 'PENDING_ORGANISATION_SELECTION') {
      await _loadConnections(showErrors: showErrors);
      if (mounted) await _loadAccountingConfiguration();
    } else {
      setState(() {
        _connections = const [];
        _selectedTenantId = null;
        _clearAccounting();
        _statusMessage = switch (status) {
          'PENDING_AUTHORISATION' => 'Complete authorisation in Xero, then click Check connection.',
          'REAUTHORISATION_REQUIRED' => 'Xero access has expired. Reconnect to authorise again.',
          'DISABLED' => 'Xero synchronisation is disabled.',
          _ => 'Configure Xero credentials and authorise your organisation to connect.',
        };
      });
    }
  }

  Future<bool> _loadSecretNames() async {
    try {
      final result = await _service.secretNames();
      if (!mounted) return false;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _integrationStatus = result.integrationStatus;
        _selectedTenantId = result.selectedTenantId;
        _clientIdSecretName = result.clientIdSecret;
        _clientSecretSecretName = result.clientSecretSecret;
        _refreshTokenSecretName = result.refreshTokenSecret;
        _tenantIdSecretName = result.tenantIdSecret;
        _accessTokenSecretName = result.accessTokenSecret;
        if ((result.redirectUrl ?? '').trim().isNotEmpty) {
          _redirectUrlController.text = result.redirectUrl!;
        }

      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _statusMessage = 'Unable to load Xero configuration: ${friendlyErrorMessage(error)}');
      return false;
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
      _clearAccounting();
    });

    try {
      final result = await _service.activate(
        clientId: _clientIdController.text.trim(),
        clientSecret: _clientSecretController.text,
        redirectUrl: _redirectUrlController.text.trim(),
        invoiceIntegrationEnabled: false,
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = result.message;
        _integrationStatus = result.integrationStatus;
        _authenticationUrl = result.authenticationUrl;
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _selectedTenantId = null;
        _connections = const [];
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
        // Only highlight a persisted selection that is still authorised.
        // Never auto-select the sole available organisation: that would
        // falsely imply it was explicitly saved on the backend.
        if (_selectedTenantId != null &&
            !connections.any((c) => c.tenantId == _selectedTenantId)) {
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
        _clearAccounting();
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
    if (_configurationControlsBusy || _selectedTenantId == connection.tenantId) return;
    setState(() {
      _selectingOrganisation = true;
      _clearAccounting();
    });
    try {
      final result = await _service.selectTenant(connection.tenantId);
      if (!mounted) return;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _integrationStatus = result.integrationStatus;
        _selectedTenantId = result.selectedTenantId ?? connection.tenantId;
        _statusMessage = result.message ?? 'Xero organisation selected.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Xero organisation selected')),
      );
      await _loadAccountingConfiguration();
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectedTenantId = null);
      _showError('Unable to select Xero organisation', error);
      await _refreshConnectionStatus(showErrors: false);
    } finally {
      if (mounted) setState(() => _selectingOrganisation = false);
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
        _integrationStatus = result.integrationStatus;
        _selectedTenantId = null;
        _clearAccounting();
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

  Future<void> _updateInvoiceIntegration(bool enabled) async {
    final previous = _invoiceIntegrationEnabled;
    setState(() {
      _invoiceIntegrationEnabled = enabled;
      _updatingInvoiceIntegration = true;
    });
    try {
      final result = await _service.updateInvoiceIntegration(enabled);
      if (!mounted) return;
      setState(() {
        _invoiceIntegrationEnabled = result.invoiceIntegrationEnabled;
        _integrationStatus = result.integrationStatus ?? _integrationStatus;
        _statusMessage = result.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Xero configuration updated')),
      );
      await _loadAccountingConfiguration();
    } catch (error) {
      if (!mounted) return;
      setState(() => _invoiceIntegrationEnabled = previous);
      _showError('Unable to update Xero invoice integration', error);
    } finally {
      if (mounted) setState(() => _updatingInvoiceIntegration = false);
    }
  }

  void _clearAccounting() {
    _accountingGeneration++;
    _accountingBusy = false;
    _accountingConfiguration = null;
    _invoiceAccountId = null;
    _paymentAccountId = null;
    _invoiceTaxType = null;
    _accountingError = null;
  }

  void _applyAccounting(XeroAccountingConfiguration configuration) {
    _accountingConfiguration = configuration;
    _invoiceAccountId = configuration.invoiceAccountId;
    _paymentAccountId = configuration.paymentAccountId;
    _invoiceTaxType = configuration.invoiceTaxType;
    _invoiceIntegrationEnabled = configuration.invoiceIntegrationEnabled;
  }

  Future<void> _loadAccountingConfiguration() async {
    if (!mounted) return;
    final selected = _selectedTenantId;
    setState(_clearAccounting);
    if ((_integrationStatus ?? '').toUpperCase() != 'AUTHORISED' || selected == null) return;
    final generation = _accountingGeneration;
    setState(() => _accountingBusy = true);
    try {
      final result = await _service.accountingConfiguration();
      if (!mounted || generation != _accountingGeneration || selected != _selectedTenantId) return;
      if (result.organisationId != selected) {
        throw const XeroIntegrationException('The connected organisation changed. Check the connection again.');
      }
      setState(() => _applyAccounting(result));
    } catch (error) {
      if (mounted && generation == _accountingGeneration) {
        setState(() => _accountingError = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted && generation == _accountingGeneration) setState(() => _accountingBusy = false);
    }
  }

  Future<void> _saveAccountingConfiguration() async {
    if (!_canSaveAccounting) return;
    final organisation = _accountingConfiguration!.organisationId;
    final generation = _accountingGeneration;
    setState(() {
      _accountingBusy = true;
      _accountingError = null;
    });
    try {
      final result = await _service.saveAccountingConfiguration(
        organisationId: organisation,
        invoiceAccountId: _invoiceAccountId!,
        paymentAccountId: _paymentAccountId!,
        invoiceTaxType: _invoiceTaxType!,
      );
      if (!mounted || generation != _accountingGeneration) return;
      if (result.organisationId != organisation || !result.mappingValid) {
        throw const XeroIntegrationException('The saved configuration is not valid. Refresh accounts before enabling integration.');
      }
      setState(() => _applyAccounting(result));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Xero accounting configuration saved. You can now enable invoice integration.'),
      ));
    } catch (error) {
      if (mounted && generation == _accountingGeneration) {
        setState(() => _accountingError = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted && generation == _accountingGeneration) setState(() => _accountingBusy = false);
    }
  }

  Widget _accountingCard() {
    final theme = Theme.of(context);
    final configuration = _accountingConfiguration;
    final authorised = (_integrationStatus ?? '').toUpperCase() == 'AUTHORISED' && _selectedTenantId != null;
    final selectedOrganisation = _connections.where((c) => c.tenantId == _selectedTenantId);
    final dirty = configuration != null && (_invoiceAccountId != configuration.invoiceAccountId ||
        _paymentAccountId != configuration.paymentAccountId || _invoiceTaxType != configuration.invoiceTaxType);
    final canEnable = authorised && configuration != null && configuration.mappingValid && !dirty &&
        _accountingError == null;
    final canEdit = !_configurationControlsBusy && !_invoiceIntegrationEnabled && configuration != null;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Accounting configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          OutlinedButton.icon(
            onPressed: !authorised || _configurationControlsBusy ? null : _loadAccountingConfiguration,
            icon: const Icon(Icons.refresh), label: const Text('Refresh accounts'),
          ),
        ]),
        const SizedBox(height: 8),
        if (selectedOrganisation.isNotEmpty)
          Text('Connected organisation: ${selectedOrganisation.first.tenantName ?? selectedOrganisation.first.tenantId}'),
        if (!authorised) const Text('Authorise Xero and select an organisation to retrieve its accounts and tax rates.'),
        if (_accountingBusy) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
        if (_accountingError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_accountingError!, style: TextStyle(color: theme.colorScheme.error))),
        if (configuration != null) ...[
          if (!configuration.mappingValid) Text(
            'Accounting configuration is missing or no longer valid for this Xero organisation. Select and save valid accounts and tax rate before enabling synchronisation.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          if (_invoiceIntegrationEnabled) const Padding(padding: EdgeInsets.only(top: 8),
            child: Text('Disable invoice integration to edit accounting configuration. Pending queue items are retained.')),
          if (configuration.mapping == null && configuration.legacyInvoiceAccountCode != null && configuration.invoiceAccountId == null)
            Text('Previous invoice account ${configuration.legacyInvoiceAccountCode} is unavailable in Xero.'),
          if (configuration.mapping == null && configuration.legacyPaymentAccountCode != null && configuration.paymentAccountId == null)
            Text('Previous payment account ${configuration.legacyPaymentAccountCode} is unavailable in Xero.'),
          const SizedBox(height: 12),
          _XeroSearchableDropdown(label: 'Default invoice sales account',
            helper: 'Active revenue accounts from the selected Xero organisation.',
            options: configuration.invoiceAccounts, value: _invoiceAccountId, enabled: canEdit,
            onChanged: (value) => setState(() => _invoiceAccountId = value)),
          const SizedBox(height: 12),
          _XeroSearchableDropdown(label: 'Default payment account',
            helper: 'Active bank or payment-enabled accounts.',
            options: configuration.paymentAccounts, value: _paymentAccountId, enabled: canEdit,
            onChanged: (value) => setState(() => _paymentAccountId = value)),
          const SizedBox(height: 12),
          _XeroSearchableDropdown(label: 'Default invoice tax type',
            helper: 'Active Xero tax rates compatible with revenue accounts.',
            options: configuration.taxRates, value: _invoiceTaxType, enabled: canEdit,
            onChanged: (value) => setState(() => _invoiceTaxType = value)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _canSaveAccounting ? _saveAccountingConfiguration : null,
            icon: const Icon(Icons.save_outlined), label: const Text('Save accounting configuration')),
          if (configuration.mappingValid && !dirty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Saved account configuration validated against Xero.')),
        ],
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _invoiceIntegrationEnabled,
          onChanged: _configurationControlsBusy || (!_invoiceIntegrationEnabled && !canEnable)
              ? null : _updateInvoiceIntegration,
          title: const Text('Enable invoice integration'),
          subtitle: const Text('Synchronise customers, products and invoices to Xero. Existing or suspended transactions are not automatically replayed; use approved reconciliation or message queue retry.'),
        ),
      ],
    )));
  }

  void _showError(String title, Object error) {
    final message = friendlyErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $message')),
    );
  }

  Future<void> _loadReconciliation() async {
    if (_loadingReconciliation) return;
    setState(() {
      _loadingReconciliation = true;
      _reconciliationNotice = null;
      _reconciliationItems = const [];
      _canCheckReconciliation = false;
    });
    try {
      final allowed = await _service.canCheckReconciliation();
      if (!mounted) return;
      setState(() => _canCheckReconciliation = allowed);
      if (!allowed) {
        setState(() => _reconciliationNotice = 'Xero reconciliation permission is required. Ask your tenant administrator to assign it in Role Maintenance.');
        return;
      }
      final items = await _service.pendingReconciliation();
      if (!mounted) return;
      setState(() { _reconciliationItems = items; });
    } catch (error) {
      if (mounted) setState(() => _reconciliationNotice = error.toString());
    } finally {
      if (mounted) setState(() => _loadingReconciliation = false);
    }
  }

  Future<void> _checkReconciliation(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _checkingReconciliationId = id);
    try {
      final result = await _service.checkReconciliation(type, id);
      if (!mounted) return;
      setState(() => _reconciliationNotice = result['message']?.toString());
      await _loadReconciliation();
    } catch (error) {
      if (mounted) setState(() => _reconciliationNotice = error.toString());
    } finally {
      if (mounted) setState(() => _checkingReconciliationId = null);
    }
  }

  Future<void> _showReconciliationDetails(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';
    if (id.isEmpty || !mounted) return;
    try {
      final readiness = await _service.reconciliationReleaseReadiness(type, id);
      final history = await _service.reconciliationAuditHistory(type, id);
      if (!mounted) return;
      final blockers = (readiness['blockers'] as List? ?? const [])
          .map((entry) => entry.toString()).toList();
      // Invoice inspection is read-only and intentionally does not certify the ledger.
      Map<String, dynamic>? ledger;
      String? ledgerError;
      if (type == 'INVOICE') {
        try {
          ledger = await _service.invoiceLedgerSnapshot(id);
        } catch (error) {
          ledgerError = error.toString();
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$type reconciliation review'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                SelectableText('Transaction: $id'),
                const SizedBox(height: 12),
                const Text('Release is disabled until external ledger verification and audited recovery are implemented.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('Release blockers (${blockers.length})', style: Theme.of(dialogContext).textTheme.titleMedium),
                for (final blocker in blockers)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('• $blocker')),
                const SizedBox(height: 12),
                if (type == 'INVOICE') ...[
                  Text('Xero ledger evidence', style: Theme.of(dialogContext).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (ledgerError != null)
                    SelectableText('Unable to retrieve ledger evidence: $ledgerError')
                  else if (ledger != null) ...[
                    SelectableText('Invoice identity matches: ${ledger['invoiceIdentityMatches'] == true ? 'Yes' : 'No / unknown'}'),
                    SelectableText('MAWA total (cents): ${ledger['mawaTotalCents'] ?? 'Unknown'}'),
                    SelectableText('Xero total: ${ledger['xeroTotal'] ?? 'Unknown'}'),
                    SelectableText('Xero paid: ${ledger['xeroAmountPaid'] ?? 'Unknown'}'),
                    SelectableText('Xero credited: ${ledger['xeroAmountCredited'] ?? 'Unknown'}'),
                    SelectableText('Xero due: ${ledger['xeroAmountDue'] ?? 'Unknown'}'),
                    SelectableText('Xero status: ${ledger['xeroStatus'] ?? 'Unknown'}'),
                    const SizedBox(height: 8),
                    Text('Financial comparison', style: Theme.of(dialogContext).textTheme.titleSmall),
                    ..._ledgerEvidenceRows(ledger['financialComparison']),
                    const SizedBox(height: 8),
                    Text('Independent payment evidence', style: Theme.of(dialogContext).textTheme.titleSmall),
                    ..._ledgerEvidenceRows(ledger['independentPaymentEvidence']),
                    Text('Independent credit-note evidence', style: Theme.of(dialogContext).textTheme.titleSmall),
                    ..._ledgerEvidenceRows(ledger['independentCreditNoteEvidence']),
                    const SizedBox(height: 8),
                    const Text('Ledger NOT certified. Quarantine release is disabled.',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 12),
                ],
                Text('Audit history (${history.length})', style: Theme.of(dialogContext).textTheme.titleMedium),
                if (history.isEmpty) const Text('No reconciliation checks recorded.'),
                for (final event in history)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText('${event['created_at'] ?? event['createdAt'] ?? ''}  '
                      '${event['outcome'] ?? ''}  ${event['detail'] ?? ''}')),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _reconciliationNotice = error.toString());
    }
  }

  List<Widget> _ledgerEvidenceRows(dynamic value) {
    if (value == null) return [const Text('Evidence unavailable')];
    if (value is Map) {
      return value.entries.map((entry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SelectableText('${entry.key}: ${entry.value}'),
      )).toList();
    }
    if (value is List) {
      if (value.isEmpty) return [const Text('No records returned; completeness unverified')];
      return value.map((entry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SelectableText(entry.toString()),
      )).toList();
    }
    return [SelectableText(value.toString())];
  }

  Widget _reconciliationCard() {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Xero reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(tooltip: 'Refresh', onPressed: _loadingReconciliation ? null : _loadReconciliation,
              icon: const Icon(Icons.refresh)),
        ]),
        const Text('Read-only Xero matching. Transactions remain quarantined; no replay or automatic release.'),
        if (_loadingReconciliation) const LinearProgressIndicator(),
        if (_reconciliationNotice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(_reconciliationNotice!)),
        if (!_loadingReconciliation && _canCheckReconciliation && _reconciliationNotice == null && _reconciliationItems.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No quarantined transactions found.')),
        for (final item in _reconciliationItems)
          ListTile(
            title: Text('${item['type'] ?? ''} · ${item['reference'] ?? item['id'] ?? ''}'),
            subtitle: Text('Xero ID: ${item['external_id'] ?? 'Not linked'}\n${item['error'] ?? ''}'),
            isThreeLine: true,
            trailing: Wrap(spacing: 8, children: [
              TextButton(
                onPressed: () => _showReconciliationDetails(item),
                child: const Text('Review blockers'),
              ),
              TextButton(
                onPressed: _checkingReconciliationId != null ? null : () => _checkReconciliation(item),
                child: _checkingReconciliationId == item['id'] ? const Text('Checking...') : const Text('Check Xero'),
              ),
            ]),
          ),
      ]),
    ));
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
          _reconciliationCard(),
          const SizedBox(height: 12),
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
                        Text('Xero accounting integration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        if ((_integrationStatus ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Chip(
                            avatar: Icon(
                              _statusIcon(_integrationStatus!),
                              size: 18,
                              color: _statusColor(theme, _integrationStatus!),
                            ),
                            label: Text(_formatStatus(_integrationStatus!)),
                            side: BorderSide(color: _statusColor(theme, _integrationStatus!)),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _statusMessage ?? 'Save the Xero application credentials, authorise access, then select the organisation used to synchronise customers, products and invoices.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _configurationControlsBusy ? null : _refreshConnectionStatus,
                          icon: const Icon(Icons.sync),
                          label: const Text('Check connection'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _accountingCard(),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _configurationControlsBusy ? null : _activate,
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
                        onPressed: _configurationControlsBusy ? null : _refreshConnectionStatus,
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
                    RadioGroup<String>(
                      groupValue: _selectedTenantId,
                      onChanged: (tenantId) {
                        if (tenantId == null || _configurationControlsBusy) return;
                        for (final connection in _connections) {
                          if (connection.tenantId == tenantId) {
                            _selectConnection(connection);
                            break;
                          }
                        }
                      },
                      child: Column(
                        children: [
                          ..._connections.map(
                            (connection) => RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: connection.tenantId,
                              title: Text(connection.tenantName?.trim().isNotEmpty == true ? connection.tenantName! : connection.tenantId),
                              subtitle: Text([
                                if (connection.tenantType?.trim().isNotEmpty == true) connection.tenantType!,
                                connection.tenantId,
                              ].join(' • ')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  OutlinedButton.icon(
                    onPressed: _configurationControlsBusy ? null : _deactivate,
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

  String _formatStatus(String status) {
    return status
        .toLowerCase()
        .split('_')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'AUTHORISED':
        return Icons.check_circle_outline;
      case 'PENDING_AUTHORISATION':
      case 'PENDING_ORGANISATION_SELECTION':
        return Icons.schedule_outlined;
      case 'REAUTHORISATION_REQUIRED':
        return Icons.warning_amber_outlined;
      default:
        return Icons.link_off_outlined;
    }
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status) {
      case 'AUTHORISED':
        return Colors.green.shade700;
      case 'PENDING_AUTHORISATION':
      case 'PENDING_ORGANISATION_SELECTION':
        return Colors.orange.shade800;
      case 'REAUTHORISATION_REQUIRED':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

/// Dropdown-style selector with a searchable popup. Free text is never a selection.
class _XeroSearchableDropdown extends StatelessWidget {
  final String label;
  final String helper;
  final List<XeroAccountingOption> options;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _XeroSearchableDropdown({required this.label, required this.helper,
    required this.options, required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final matches = options.where((option) => option.id == value);
    final selected = matches.isEmpty ? null : matches.first;
    final selectable = enabled && options.isNotEmpty;
    return InkWell(
      onTap: selectable ? () async {
        var filter = '';
        final chosen = await showDialog<String>(context: context, builder: (context) {
          return StatefulBuilder(builder: (context, update) {
            final filtered = options.where((option) => option.label.toLowerCase().contains(filter)).toList();
            return AlertDialog(
              title: Text(label),
              content: SizedBox(width: 540, height: 360, child: Column(children: [
                TextField(autofocus: true, decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search by code or name', border: OutlineInputBorder(),
                ), onChanged: (text) => update(() => filter = text.trim().toLowerCase())),
                const SizedBox(height: 8),
                Expanded(child: filtered.isEmpty ? const Center(child: Text('No matching Xero values')) : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final option = filtered[index];
                    return ListTile(title: Text(option.label), selected: option.id == value,
                      trailing: option.id == value ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, option.id));
                  },
                )),
              ])),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
            );
          });
        });
        if (chosen != null && context.mounted) onChanged(chosen);
      } : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, helperText: helper,
          border: const OutlineInputBorder(), enabled: selectable,
          suffixIcon: const Icon(Icons.arrow_drop_down)),
        isEmpty: selected == null,
        child: Text(selected?.label ?? (options.isEmpty ? 'No eligible Xero values' : 'Select from Xero'),
          style: selected == null ? Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant) : null),
      ),
    );
  }
}
