import 'package:flutter/material.dart';

import '../../../partners/models/partner.dart';
import '../../../partners/partner_service.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_tenant_integration_configuration_dto.dart';
import '../../data/models/funeral_tenant_option_dto.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class FuneralTenantIntegrationSetupPage extends StatefulWidget {
  const FuneralTenantIntegrationSetupPage({super.key});

  @override
  State<FuneralTenantIntegrationSetupPage> createState() =>
      _FuneralTenantIntegrationSetupPageState();
}

class _FuneralTenantIntegrationSetupPageState
    extends State<FuneralTenantIntegrationSetupPage> {
  final FuneralApi _api = FuneralApi();
  final PartnerService _partnerService = PartnerService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _sourceMode = 'LOCAL_ONLY';
  String? _externalTenantId;
  String? _externalTenantName;
  Partner? _mappedPartner;
  bool _membershipLookupEnabled = true;
  bool _claimCreationEnabled = true;
  bool _claimStatusSyncEnabled = true;
  bool _active = true;
  List<FuneralTenantOptionDto> _tenants = const [];

  bool get _usesExternal =>
      _sourceMode == 'EXTERNAL_ONLY' ||
      _sourceMode == 'LOCAL_AND_EXTERNAL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getTenantIntegrationConfiguration(),
        _api.getAvailableTenantOptions(),
      ]);
      final configuration =
          results[0] as FuneralTenantIntegrationConfigurationDto;
      final tenants = results[1] as List<FuneralTenantOptionDto>;
      Partner? mappedPartner;
      if (configuration.externalTenantPartnerId?.isNotEmpty == true) {
        try {
          mappedPartner = await _partnerService
              .getPartnerById(configuration.externalTenantPartnerId!);
        } catch (_) {
          mappedPartner = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _sourceMode = configuration.membershipSourceMode;
        _externalTenantId = configuration.externalTenantId;
        _externalTenantName = configuration.externalTenantName;
        _mappedPartner = mappedPartner;
        _membershipLookupEnabled = configuration.membershipLookupEnabled;
        _claimCreationEnabled = configuration.claimCreationEnabled;
        _claimStatusSyncEnabled = configuration.claimStatusSyncEnabled;
        _active = configuration.active;
        _tenants = tenants;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_usesExternal && (_externalTenantId?.isEmpty ?? true)) {
      _showMessage('Select the membership and claims tenant.');
      return;
    }
    if (_usesExternal && _mappedPartner == null) {
      _showMessage(
        'Select the local partner that represents the external tenant for invoicing.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _api.updateTenantIntegrationConfiguration(
        FuneralTenantIntegrationConfigurationDto(
          membershipSourceMode: _sourceMode,
          externalTenantId: _usesExternal ? _externalTenantId : null,
          externalTenantName: _usesExternal ? _externalTenantName : null,
          externalTenantPartnerId:
              _usesExternal ? _mappedPartner?.id : null,
          membershipLookupEnabled: _membershipLookupEnabled,
          claimCreationEnabled: _claimCreationEnabled,
          claimStatusSyncEnabled: _claimStatusSyncEnabled,
          active: _active,
        ),
      );
      if (!mounted) return;
      setState(() {
        _sourceMode = saved.membershipSourceMode;
        _externalTenantId = saved.externalTenantId;
        _externalTenantName = saved.externalTenantName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant integration configuration saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectMappedPartner() async {
    final selected = await showDialog<Partner>(
      context: context,
      builder: (context) => const _PartnerSelectionDialog(),
    );
    if (selected != null && mounted) {
      setState(() => _mappedPartner = selected);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Tenant Integration'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  MaterialBanner(
                    content: Text(_error!),
                    leading: const Icon(Icons.error_outline),
                    actions: [
                      TextButton(onPressed: _load, child: const Text('RETRY')),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Membership and claim source',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose whether funeral arrangements use memberships and claims from this tenant, another tenant, or both.',
                        ),
                        const SizedBox(height: 16),
                        SearchableDropdownFormField<String>(
                          value: _sourceMode,
                          decoration: const InputDecoration(
                            labelText: 'Source mode',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'LOCAL_ONLY',
                              child: Text('Local tenant only'),
                            ),
                            DropdownMenuItem(
                              value: 'EXTERNAL_ONLY',
                              child: Text('External tenant only'),
                            ),
                            DropdownMenuItem(
                              value: 'LOCAL_AND_EXTERNAL',
                              child: Text('Local and external tenants'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sourceMode = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_usesExternal) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'External tenant mapping',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SearchableDropdownFormField<String>(
                            value: _tenants.any(
                              (tenant) => tenant.id == _externalTenantId,
                            )
                                ? _externalTenantId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Membership and claims tenant',
                              border: OutlineInputBorder(),
                            ),
                            items: _tenants
                                .map(
                                  (tenant) => DropdownMenuItem<String>(
                                    value: tenant.id,
                                    child: Text(
                                      tenant.host?.isNotEmpty == true
                                          ? '${tenant.name} (${tenant.host})'
                                          : tenant.name,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              FuneralTenantOptionDto? selected;
                              for (final tenant in _tenants) {
                                if (tenant.id == value) {
                                  selected = tenant;
                                  break;
                                }
                              }
                              setState(() {
                                if (_externalTenantId != value) {
                                  _mappedPartner = null;
                                }
                                _externalTenantId = value;
                                _externalTenantName = selected?.name;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.handshake_outlined),
                            title: Text(
                              _mappedPartner?.fullName ??
                                  'Select local invoicing partner',
                            ),
                            subtitle: Text(
                              _mappedPartner == null
                                  ? 'This local partner represents the external tenant or burial society on funeral invoices.'
                                  : 'Partner no: ${_mappedPartner!.number}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _selectMappedPartner,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Integration active'),
                        subtitle: const Text(
                          'Enable this tenant integration configuration.',
                        ),
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                      ),
                      SwitchListTile(
                        title: const Text('Membership lookup'),
                        subtitle: const Text(
                          'Allow funeral users to search eligible external memberships.',
                        ),
                        value: _membershipLookupEnabled,
                        onChanged: _usesExternal
                            ? (value) => setState(
                                  () => _membershipLookupEnabled = value,
                                )
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('External claim creation'),
                        subtitle: const Text(
                          'Create the claim in the tenant that owns the membership.',
                        ),
                        value: _claimCreationEnabled,
                        onChanged: _usesExternal
                            ? (value) => setState(() {
                                  _claimCreationEnabled = value;
                                  if (value) {
                                    _claimStatusSyncEnabled = true;
                                  }
                                })
                            : null,
                      ),
                      SwitchListTile(
                        title: const Text('Claim status synchronisation'),
                        subtitle: const Text(
                          'Read approval and payment status from the source tenant. Required while external claim creation is enabled.',
                        ),
                        value: _claimStatusSyncEnabled,
                        onChanged: _usesExternal
                            ? (_claimCreationEnabled
                                ? null
                                : (value) => setState(
                                      () => _claimStatusSyncEnabled = value,
                                    ))
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save configuration'),
                ),
              ],
            ),
    );
  }
}

class _PartnerSelectionDialog extends StatefulWidget {
  const _PartnerSelectionDialog();

  @override
  State<_PartnerSelectionDialog> createState() =>
      _PartnerSelectionDialogState();
}

class _PartnerSelectionDialogState extends State<_PartnerSelectionDialog> {
  final TextEditingController _query = TextEditingController();
  final PartnerService _service = PartnerService();
  bool _loading = false;
  List<Partner> _partners = const [];

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final partners = await _service.getPartners(query: _query.text.trim());
      if (mounted) setState(() => _partners = partners);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select local partner'),
      content: SizedBox(
        width: 560,
        height: 430,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Search partner',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _partners.isEmpty
                  ? const Center(
                      child: Text('Search for the external tenant partner.'),
                    )
                  : ListView.builder(
                      itemCount: _partners.length,
                      itemBuilder: (context, index) {
                        final partner = _partners[index];
                        return ListTile(
                          title: Text(partner.fullName),
                          subtitle: Text('Partner no: ${partner.number}'),
                          onTap: () => Navigator.pop(context, partner),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }
}
