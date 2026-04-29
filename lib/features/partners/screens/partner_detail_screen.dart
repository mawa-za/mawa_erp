import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../models/partner.dart';
import 'partner_create_screen.dart';

class PartnerDetailScreen extends StatefulWidget {
  final String partnerId;

  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  bool _isLoading = true;
  Partner? _partner;
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
        setState(() {
          _partner = Partner.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load partner details: ${response.statusCode}';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Partner Details'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        actions: [
          if (_partner != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PartnerCreateScreen(existingPartner: _partner),
                  ),
                );
                if (result == true) {
                  _fetchPartnerDetails();
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPartnerDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_partner == null) {
      return const Center(child: Text('No details found.'));
    }

    final partner = _partner!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(partner, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.info_outline, 'General Information'),
          const SizedBox(height: 8),
          _buildGeneralInfoCard(partner, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.location_on_outlined, 'Addresses'),
          const SizedBox(height: 8),
          if (partner.addresses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text('No addresses recorded.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            )
          else
            ...partner.addresses.map((addr) => _buildAddressCard(addr, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
            child: Icon(icon, size: 36, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            partner.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              partner.type,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Partner No: ${partner.number}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard(Partner partner, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.badge_outlined, 'Identity/Reg Number', partner.identityNumber.isEmpty ? 'N/A' : partner.identityNumber),
            const Divider(height: 24),
            _buildInfoRow(Icons.email_outlined, 'Email Address', partner.email.isEmpty ? 'N/A' : partner.email),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone_outlined, 'Phone Number', partner.phone.isEmpty ? 'N/A' : partner.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(PartnerAddress addr, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.home_outlined, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(addr.line1, style: const TextStyle(fontSize: 13)),
                  if (addr.line2.isNotEmpty) Text(addr.line2, style: const TextStyle(fontSize: 13)),
                  Text('${addr.city}, ${addr.state} ${addr.postalCode}', style: const TextStyle(fontSize: 13)),
                  Text(addr.country, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
