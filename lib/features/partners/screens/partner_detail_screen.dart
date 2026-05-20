import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../membership/models/group_society.dart';
import '../../membership/screens/group_society_detail_screen.dart';
import '../../membership/services/membership_service.dart';
import '../models/partner.dart';
import '../models/partner_identity.dart';
import '../partner_service.dart';
import 'partner_create_screen.dart';
import 'add_identity_dialog.dart';
import 'add_address_dialog.dart';
import 'add_role_dialog.dart';

class PartnerDetailScreen extends StatefulWidget {
  final String partnerId;
  final String? title;
  final bool isMemberContext;

  const PartnerDetailScreen({
    super.key,
    required this.partnerId,
    this.title,
    this.isMemberContext = false,
  });

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  final MembershipService _membershipService = MembershipService();
  bool _isLoading = true;
  Partner? _partner;
  GroupSociety? _society;
  List<PartnerRole> _detailedRoles = [];
  List<PartnerIdentity> _detailedIdentities = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPartnerDetails();
  }

  Future<void> _fetchPartnerDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient().get('/v2/partner/${widget.partnerId}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final partner = Partner.fromJson(data);
        
        final results = await Future.wait([
          PartnerService().getPartnerRoles(widget.partnerId).catchError((_) => <PartnerRole>[]),
          PartnerService().getPartnerIdentities(widget.partnerId).catchError((_) => <PartnerIdentity>[]),
          _membershipService.getGroupSocietyByPartner(widget.partnerId).catchError((_) => null),
        ]);
        
        setState(() {
          _partner = partner;
          _detailedRoles = results[0] as List<PartnerRole>;
          _detailedIdentities = results[1] as List<PartnerIdentity>;
          _society = results[2] as GroupSociety?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load details: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddIdentityDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddIdentityDialog(partnerId: widget.partnerId),
    );
    if (result == true) _fetchPartnerDetails();
  }

  Future<void> _showAddAddressDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddAddressDialog(partnerId: widget.partnerId),
    );
    if (result == true) _fetchPartnerDetails();
  }

  Future<void> _showManageRolesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddRoleDialog(
        partnerId: widget.partnerId,
        currentRoles: _partner?.roles ?? [],
      ),
    );
    if (result == true) _fetchPartnerDetails();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entityName = widget.isMemberContext ? 'Member' : 'Partner';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(widget.title ?? '$entityName Details'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        actions: [
          if (_partner != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PartnerCreateScreen(
                      existingPartner: _partner,
                      isMemberContext: widget.isMemberContext,
                    ),
                  ),
                );
                if (result == true) _fetchPartnerDetails();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildBody(colorScheme, entityName),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchPartnerDetails, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, String entityName) {
    final partner = _partner!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(partner, colorScheme),
          if (_society != null) ...[
            const SizedBox(height: 20),
            _buildSocietyShortcut(colorScheme),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.admin_panel_settings_outlined, '$entityName ROLES'),
              if (!widget.isMemberContext)
                TextButton.icon(
                  onPressed: _showManageRolesDialog,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('MANAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRolesWrap(colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.info_outline, 'GENERAL INFORMATION'),
          const SizedBox(height: 12),
          _buildGeneralInfoCard(partner, colorScheme),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.badge_outlined, 'IDENTITIES'),
              TextButton.icon(
                onPressed: _showAddIdentityDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD IDENTITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._detailedIdentities.map((identity) => _buildIdentityCard(identity, colorScheme)),
          if (_detailedIdentities.isEmpty) _buildEmptyPrompt('No additional identities recorded.'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.location_on_outlined, 'ADDRESSES'),
              TextButton.icon(
                onPressed: _showAddAddressDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD ADDRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...partner.addresses.map((addr) => _buildAddressCard(addr, colorScheme)),
          if (partner.addresses.isEmpty) _buildEmptyPrompt('No addresses recorded.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(Partner partner, ColorScheme colorScheme) {
    IconData icon;
    switch (partner.type) {
      case 'ORGANISATION': icon = Icons.business; break;
      case 'GROUP': icon = Icons.groups; break;
      default: icon = Icons.person;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Icon(icon, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            partner.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(partner.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
          const SizedBox(height: 12),
          Text('Partner No: ${partner.number}', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard(Partner partner, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.badge_outlined, 'Primary Identity', partner.identityNumber.isEmpty ? 'N/A' : partner.identityNumber),
          const Divider(height: 24),
          _buildInfoRow(Icons.email_outlined, 'Email Address', partner.email.isEmpty ? 'N/A' : partner.email),
          const Divider(height: 24),
          _buildInfoRow(Icons.phone_outlined, 'Phone Number', partner.phone.isEmpty ? 'N/A' : partner.phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildRolesWrap(ColorScheme colorScheme) {
    if (_detailedRoles.isEmpty) {
      return const Text('No roles assigned.', style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _detailedRoles.map((role) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(role.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      )).toList(),
    );
  }

  Widget _buildIdentityCard(PartnerIdentity identity, ColorScheme colorScheme) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    String validity = 'No expiry';
    if (identity.validFrom != null || identity.validTo != null) {
      final from = identity.validFrom != null ? dateFormat.format(identity.validFrom!) : '...';
      final to = identity.validTo != null ? dateFormat.format(identity.validTo!) : '...';
      validity = '$from to $to';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: colorScheme.primary.withOpacity(0.1), child: Icon(Icons.badge_outlined, color: colorScheme.primary, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${identity.type}: ${identity.number}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Validity: $validity', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(PartnerAddress addr, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.home_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addr.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(addr.line1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (addr.line2.isNotEmpty) Text(addr.line2, style: const TextStyle(fontSize: 13)),
                Text('${addr.city}, ${addr.province.isNotEmpty ? addr.province : addr.state} ${addr.postalCode}', style: const TextStyle(fontSize: 13)),
                Text(addr.country, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocietyShortcut(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.1))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.groups_outlined, color: Colors.blue)),
        title: const Text('Society Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        subtitle: Text('Balance: R ${_society!.availableBalance.toStringAsFixed(2)}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => GroupSocietyDetailScreen(societyId: _society!.id))),
      ),
    );
  }

  Widget _buildEmptyPrompt(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }
}
