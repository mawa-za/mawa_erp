import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/membership_detail.dart';
import '../services/membership_service.dart';

class MembershipDetailScreen extends StatefulWidget {
  final String membershipId;
  const MembershipDetailScreen({super.key, required this.membershipId});

  @override
  State<MembershipDetailScreen> createState() => _MembershipDetailScreenState();
}

class _MembershipDetailScreenState extends State<MembershipDetailScreen> {
  bool _isLoading = true;
  MembershipDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await MembershipService().getMembershipDetail(widget.membershipId);
      if (mounted) {
        setState(() {
          _detail = detail;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_detail != null ? 'Membership #${_detail!.number}' : 'Membership Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load membership details', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchDetail, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final detail = _detail!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(detail),
          const SizedBox(height: 16),
          _buildMemberCard(detail.member, colorScheme),
          const SizedBox(height: 16),
          _buildMembershipInfoCard(detail, colorScheme),
          const SizedBox(height: 16),
          _buildProductList(detail.products, colorScheme),
          const SizedBox(height: 16),
          _buildSalesRepCard(detail.salesRepresentative, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MembershipDetail detail) {
    Color color;
    switch (detail.status.code.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'WAITING-PERIOD':
        color = Colors.orange;
        break;
      case 'INACTIVE':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.status.description.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
              Text(
                'Joined: ${detail.dateJoined}',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'R ${detail.premium.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Member member, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(member.firstName[0], style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${member.title?.description ?? ''} ${member.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('No: ${member.number}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatusChip(member.status?.description ?? 'Unknown', isCompact: true),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.badge_outlined, 'Identity', '${member.identity?.type.description ?? 'ID'}: ${member.identity?.number ?? 'N/A'}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.cake_outlined, 'Birth Date', member.birthDate ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, 'Gender', member.gender?.description ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipInfoCard(MembershipDetail detail, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MEMBERSHIP INFO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.inventory_2_outlined, 'Main Product', '${detail.product.description} (${detail.product.code})'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_available, 'Effective Date', detail.dateEffective ?? 'Pending'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.category_outlined, 'Transaction Type', detail.type.description),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(List<MembershipProduct> products, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('COVERED PRODUCTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ),
        ...products.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
          child: ListTile(
            dense: true,
            title: Text('Product ID: ${p.product}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Valid: ${p.validFrom} to ${p.validTo}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R ${p.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(p.status, style: TextStyle(fontSize: 10, color: colorScheme.primary)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSalesRepCard(SalesRepresentative rep, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.support_agent),
        title: Text('${rep.title?.description ?? ''} ${rep.fullName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text('Sales Rep No: ${rep.number}', style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildStatusChip(String status, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(status, style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
