import 'package:flutter/material.dart';
import '../../../core/models/setting.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/setting_service.dart';
import '../services/xero_integration_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _isLoading = true;
  List<Setting> _settings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final settings = await SettingService().getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, List<Setting>> _groupSettings() {
    final Map<String, List<Setting>> groups = {};
    for (var setting in _settings) {
      if (!groups.containsKey(setting.type)) {
        groups[setting.type] = [];
      }
      groups[setting.type]!.add(setting);
    }
    return groups;
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'TENANT':
        return Icons.business_outlined;
      case 'CASH-BANK-ACCOUNT':
      case 'EFT-BANK-ACCOUNT':
        return Icons.account_balance_outlined;
      case 'WAREHOUSE-LAYOUT':
        return Icons.warehouse_outlined;
      case 'FNB-API':
        return Icons.api_outlined;
      case 'GROCERY-CLAIM':
      case 'FUNERAL-CLAIM':
      case 'TOMBSTONE-CLAIM':
        return Icons.request_quote_outlined;
      case 'XERO':
      case 'INVOICE':
        return Icons.receipt_long_outlined;
      case 'BANK-PAYMENT-FILE':
        return Icons.file_present_outlined;
      default:
        return Icons.settings_outlined;
    }
  }


  Future<void> _activateXeroIntegration() async {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();
    final redirectUrlController = TextEditingController(text: 'https://dev.api.app.mawa.co.za');
    bool invoiceIntegrationEnabled = true;
    bool submitting = false;
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(child: Text('Activate Xero Integration', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the Xero Client ID and Client Secret once. MAWA will push them to Google Secret Manager and save only secret references in settings.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientIdController,
                  decoration: InputDecoration(
                    labelText: 'Xero Client ID',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clientSecretController,
                  decoration: InputDecoration(
                    labelText: 'Xero Client Secret',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: redirectUrlController,
                  decoration: InputDecoration(
                    labelText: 'Backend Base URL',
                    helperText: 'Example: https://dev.api.app.mawa.co.za',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable invoice push to Xero'),
                  value: invoiceIntegrationEnabled,
                  onChanged: submitting ? null : (value) => setDialogState(() => invoiceIntegrationEnabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
              child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      if (clientIdController.text.trim().isEmpty || clientSecretController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Xero Client ID and Client Secret are required'), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final activation = await XeroIntegrationService().activate(
                          clientId: clientIdController.text.trim(),
                          clientSecret: clientSecretController.text.trim(),
                          redirectUrl: redirectUrlController.text.trim(),
                          invoiceIntegrationEnabled: invoiceIntegrationEnabled,
                        );
                        if (activation.authenticationUrl != null && activation.authenticationUrl!.isNotEmpty) {
                          final uri = Uri.parse(activation.authenticationUrl!);
                          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                          if (!launched) {
                            await launchUrl(uri, mode: LaunchMode.platformDefault);
                          }
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
              icon: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('SAVE & AUTHORISE XERO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _fetchSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xero secrets saved to GCP. Complete authorisation in the browser window. If Xero shows multiple organisations, return here and click Select Organisation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  Future<void> _selectXeroOrganisation() async {
    bool loading = true;
    bool submitting = false;
    List<XeroConnection> connections = [];
    XeroConnection? selected;

    final colorScheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> loadConnections() async {
            try {
              final result = await XeroIntegrationService().connections();
              setDialogState(() {
                connections = result;
                selected = result.length == 1 ? result.first : null;
                loading = false;
              });
            } catch (e) {
              setDialogState(() => loading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                );
              }
            }
          }

          if (loading && connections.isEmpty) {
            Future.microtask(loadConnections);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.business_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(child: Text('Select Xero Organisation', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : connections.isEmpty
                      ? const Text('No Xero organisations were returned. Complete Xero authorisation first, then try again.')
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Choose the Xero organisation to link to this MAWA tenant.'),
                            const SizedBox(height: 12),
                            ...connections.map(
                              (connection) => RadioListTile<XeroConnection>(
                                contentPadding: EdgeInsets.zero,
                                value: connection,
                                groupValue: selected,
                                onChanged: submitting ? null : (value) => setDialogState(() => selected = value),
                                title: Text(connection.tenantName?.isNotEmpty == true ? connection.tenantName! : connection.tenantId),
                                subtitle: Text('${connection.tenantType ?? 'Organisation'}\n${connection.tenantId}'),
                              ),
                            ),
                          ],
                        ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ),
              FilledButton.icon(
                onPressed: submitting || selected == null
                    ? null
                    : () async {
                        setDialogState(() => submitting = true);
                        try {
                          final response = await XeroIntegrationService().selectTenant(selected!.tenantId);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          await _fetchSettings();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(response.message ?? 'Xero organisation selected'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => submitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                icon: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: const Text('SAVE SELECTION', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deactivateXeroIntegration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Xero Integration'),
        content: const Text('This disables invoice push to Xero for this tenant. Secret references are retained for future reactivation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('DEACTIVATE')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await XeroIntegrationService().deactivate();
        await _fetchSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xero invoice integration disabled'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _editSetting(Setting setting) async {
    final controller = TextEditingController(text: setting.value);
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_getIconForType(setting.type), color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Edit ${setting.attribute}', style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${setting.type}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
              maxLines: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result != setting.value) {
      try {
        await SettingService().updateSetting(setting.type, setting.attribute, result);
        _fetchSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setting updated successfully'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _addNewSetting(String type) async {
    final attributeController = TextEditingController();
    final valueController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Add $type Setting', style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: attributeController,
              decoration: InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g. TIMEOUT',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              if (attributeController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('ADD SETTING', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await SettingService().updateSetting(
          type,
          attributeController.text.trim().toUpperCase(),
          valueController.text.trim(),
        );
        _fetchSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New setting added'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchSettings,
                tooltip: 'Refresh settings',
              ),
              const SizedBox(width: 8),
            ],
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            centerTitle: false,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('Failed to load settings', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _fetchSettings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_settings.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No settings found.')),
            )
          else
            _buildSettingsList(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSettingsList(ColorScheme colorScheme) {
    final grouped = _groupSettings();
    grouped.putIfAbsent('XERO', () => <Setting>[]);
    final sortedTypes = grouped.keys.toList()..sort();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final type = sortedTypes[index];
            final typeSettings = grouped[type]!;
            return _buildCategoryCard(type, typeSettings, colorScheme);
          },
          childCount: sortedTypes.length,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String type, List<Setting> settings, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getIconForType(type), color: colorScheme.primary, size: 20),
          ),
          title: Text(
            type.replaceAll('-', ' '),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text('${settings.length} parameters', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: colorScheme.primary,
            onPressed: () => _addNewSetting(type),
            tooltip: 'Add parameter to this group',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(height: 1),
            if (type.toUpperCase() == 'XERO') _buildXeroActivationPanel(colorScheme),
            ...settings.map((s) => _buildSettingTile(s, colorScheme)),
          ],
        ),
      ),
    );
  }


  Widget _buildXeroActivationPanel(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Self-service Xero activation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Save the Xero Client ID and Client Secret directly to Google Secret Manager, then authorise the Xero organisation. Secret values are not stored in MAWA settings.',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _activateXeroIntegration,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('ACTIVATE / RECONNECT'),
              ),
              OutlinedButton.icon(
                onPressed: _selectXeroOrganisation,
                icon: const Icon(Icons.business_outlined),
                label: const Text('SELECT ORGANISATION'),
              ),
              OutlinedButton.icon(
                onPressed: _deactivateXeroIntegration,
                icon: const Icon(Icons.link_off_outlined),
                label: const Text('DEACTIVATE INVOICE PUSH'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(Setting s, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _editSetting(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.attribute.replaceAll('-', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.value.isEmpty ? 'Not set' : s.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: s.value.isEmpty ? Colors.grey[400] : Colors.black87,
                      fontStyle: s.value.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: colorScheme.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
