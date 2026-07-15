import 'package:flutter/material.dart';

import '../../data/funeral_api.dart';
import '../../data/models/funeral_tenant_option_dto.dart';
import '../../data/models/tenant_trust_relationship_dto.dart';

class TrustedTenantsPage extends StatefulWidget {
  const TrustedTenantsPage({super.key});

  @override
  State<TrustedTenantsPage> createState() => _TrustedTenantsPageState();
}

class _TrustedTenantsPageState extends State<TrustedTenantsPage> {
  final FuneralApi _api = FuneralApi();

  bool _loading = true;
  String? _error;
  List<TenantTrustRelationshipDto> _relationships = [];
  List<FuneralTenantOptionDto> _tenants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final relationships = await _api.getTrustedTenants();
      final tenants = await _api.getAvailableTenantOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _relationships = relationships;
        _tenants = tenants;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestTrust() async {
    String? selectedTenantId;
    bool allowMembershipLookup = true;
    bool allowClaimCreation = true;
    bool allowClaimStatusRead = true;
    bool allowSettlement = false;

    final requested = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Request trusted tenant'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Membership and claims tenant',
                        border: OutlineInputBorder(),
                      ),
                      items: _tenants
                          .map(
                            (tenant) => DropdownMenuItem<String>(
                              value: tenant.id,
                              child: Text(tenant.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedTenantId = value);
                      },
                    ),
                    CheckboxListTile(
                      value: allowMembershipLookup,
                      onChanged: (value) {
                        setDialogState(
                          () => allowMembershipLookup = value ?? true,
                        );
                      },
                      title: const Text('Allow membership lookup'),
                    ),
                    CheckboxListTile(
                      value: allowClaimCreation,
                      onChanged: (value) {
                        setDialogState(
                          () => allowClaimCreation = value ?? true,
                        );
                      },
                      title: const Text('Allow claim creation'),
                    ),
                    CheckboxListTile(
                      value: allowClaimStatusRead,
                      onChanged: (value) {
                        setDialogState(
                          () => allowClaimStatusRead = value ?? true,
                        );
                      },
                      title: const Text('Allow claim status read'),
                    ),
                    CheckboxListTile(
                      value: allowSettlement,
                      onChanged: (value) {
                        setDialogState(
                          () => allowSettlement = value ?? false,
                        );
                      },
                      title: const Text('Allow settlement communication'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: selectedTenantId == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('REQUEST'),
                ),
              ],
            );
          },
        );
      },
    );

    if (requested != true || selectedTenantId == null) {
      return;
    }

    try {
      await _api.requestTrustedTenant(
        TenantTrustRelationshipDto(
          providerTenantId: selectedTenantId,
          membershipLookupAllowed: allowMembershipLookup,
          claimCreationAllowed: allowClaimCreation,
          claimStatusReadAllowed: allowClaimStatusRead,
          settlementAllowed: allowSettlement,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _updateStatus(
    TenantTrustRelationshipDto relationship,
    String status,
  ) async {
    final id = relationship.id;
    if (id == null || id.isEmpty) {
      return;
    }

    try {
      await _api.updateTrustedTenantStatus(id, status);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Tenants'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestTrust,
        icon: const Icon(Icons.add_link),
        label: const Text('Request trust'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_relationships.isEmpty) {
      return const Center(
        child: Text('No trusted tenant relationships have been configured.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _relationships.length,
      itemBuilder: (context, index) {
        final relationship = _relationships[index];
        return _buildRelationshipCard(relationship);
      },
    );
  }

  Widget _buildRelationshipCard(TenantTrustRelationshipDto relationship) {
    final requester = relationship.requesterTenantName ??
        relationship.requesterTenantId ??
        'Unknown requester';
    final provider = relationship.providerTenantName ??
        relationship.providerTenantId ??
        'Unknown provider';

    return Card(
      child: ListTile(
        leading: Icon(
          relationship.status == 'APPROVED'
              ? Icons.verified_user
              : Icons.pending_actions,
        ),
        title: Text('$requester → $provider'),
        subtitle: Text(
          'Status: ${relationship.status}'
          ' • Membership lookup: '
          '${relationship.membershipLookupAllowed ? 'Yes' : 'No'}'
          ' • Claim creation: '
          '${relationship.claimCreationAllowed ? 'Yes' : 'No'}'
          ' • Status read: '
          '${relationship.claimStatusReadAllowed ? 'Yes' : 'No'}'
          ' • Settlement: '
          '${relationship.settlementAllowed ? 'Yes' : 'No'}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (relationship.status == 'PENDING')
              IconButton(
                tooltip: 'Approve',
                onPressed: () => _updateStatus(relationship, 'APPROVED'),
                icon: const Icon(Icons.check_circle),
              ),
            if (relationship.status == 'PENDING')
              IconButton(
                tooltip: 'Reject',
                onPressed: () => _updateStatus(relationship, 'REJECTED'),
                icon: const Icon(Icons.cancel),
              ),
            if (relationship.status == 'APPROVED')
              IconButton(
                tooltip: 'Suspend',
                onPressed: () => _updateStatus(relationship, 'SUSPENDED'),
                icon: const Icon(Icons.pause_circle),
              ),
            if (relationship.status != 'REVOKED')
              IconButton(
                tooltip: 'Revoke',
                onPressed: () => _updateStatus(relationship, 'REVOKED'),
                icon: const Icon(Icons.link_off),
              ),
          ],
        ),
      ),
    );
  }
}
