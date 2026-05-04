import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../services/membership_service.dart';
import '../../../core/widgets/attachment_section.dart';

class MembershipDetailScreen extends StatefulWidget {
  final String membershipId;
  const MembershipDetailScreen({super.key, required this.membershipId});

  @override
  State<MembershipDetailScreen> createState() => _MembershipDetailScreenState();
}

class _MembershipDetailScreenState extends State<MembershipDetailScreen> {
  bool _isLoading = true;
  MembershipDetail? _detail;
  List<Dependent> _dependents = [];
  List<Premium> _premiums = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await MembershipService().getMembershipDetail(widget.membershipId);
      final dependents = await MembershipService().getMembershipDependents(widget.membershipId);
      final premiums = await MembershipService().getMembershipPremiums(widget.membershipId);
      
      // Sort premiums by period DESC
      premiums.sort((a, b) => b.membershipPeriod.compareTo(a.membershipPeriod));

      if (mounted) {
        setState(() {
          _detail = detail;
          _dependents = dependents;
          _premiums = premiums;
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
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement add dependent
        },
        label: const Text('Add Dependent'),
        icon: const Icon(Icons.person_add_outlined),
      ),
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
            ElevatedButton(onPressed: _fetchData, child: const Text('RETRY')),
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
          const SizedBox(height: 16),
          _buildPremiumSection(colorScheme),
          const SizedBox(height: 16),
          _buildDependentsSection(colorScheme),
          const SizedBox(height: 16),
          _buildAttachmentSection(detail.id),
          const SizedBox(height: 80), // Space for FAB
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
                  child: Text(member.firstName.isNotEmpty ? member.firstName[0] : '?', 
                    style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
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

  Widget _buildPremiumSection(ColorScheme colorScheme) {
    if (_premiums.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('PAID PREMIUMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No paid premiums found', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          ),
        ],
      );
    }

    // Group premiums by year
    final Map<String, List<Premium>> groupedPremiums = {};
    for (var premium in _premiums) {
      final year = premium.membershipPeriod.length >= 4 
          ? premium.membershipPeriod.substring(0, 4) 
          : 'Other';
      if (!groupedPremiums.containsKey(year)) {
        groupedPremiums[year] = [];
      }
      groupedPremiums[year]!.add(premium);
    }

    final sortedYears = groupedPremiums.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('PAID PREMIUMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Text('${_premiums.length} Total', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
        ...sortedYears.map((year) {
          final yearPremiums = groupedPremiums[year]!;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ExpansionTile(
              initiallyExpanded: year == sortedYears.first,
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.withOpacity(0.1),
                child: Text(year.substring(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              title: Text('$year Premiums', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${yearPremiums.length} payments', style: const TextStyle(fontSize: 12)),
              children: [
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: yearPremiums.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final premium = yearPremiums[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatPeriod(premium.membershipPeriod), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('R ${premium.amount.toStringAsFixed(2)}', 
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 14)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receipt: ${premium.receiptNumber} • ${premium.tenderType.description}', style: const TextStyle(fontSize: 11)),
                          Text('${premium.creationDate} ${premium.creationTime}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatPeriod(String period) {
    if (period.length != 6) return period;
    final year = period.substring(0, 4);
    final month = period.substring(4, 6);
    final monthName = _getMonthName(int.tryParse(month) ?? 0);
    return '$monthName $year';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month < 1 || month > 12) return 'Month $month';
    return months[month - 1];
  }

  Widget _buildDependentsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('DEPENDENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ),
        if (_dependents.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No dependents found', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          )
        else
          ..._dependents.map((dependent) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.secondaryContainer,
                child: Text(dependent.firstName.isNotEmpty ? dependent.firstName[0] : '?', 
                  style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Text('${dependent.title?.description ?? ''} ${dependent.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('No: ${dependent.number}', style: const TextStyle(fontSize: 12)),
              trailing: _buildStatusChip(dependent.status?.description ?? 'Active', isCompact: true),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(),
                      _buildInfoRow(Icons.badge_outlined, 'Identity', '${dependent.identity?.type.description ?? 'ID'}: ${dependent.identity?.number ?? 'N/A'}'),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.cake_outlined, 'Birth Date', dependent.birthDate ?? 'N/A'),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.wc_outlined, 'Gender/Marital', '${dependent.gender?.description ?? 'N/A'} / ${dependent.maritalStatus?.description ?? 'N/A'}'),
                    ],
                  ),
                )
              ],
            ),
          )),
      ],
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

  Widget _buildAttachmentSection(String membershipId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AttachmentSection(objectId: membershipId),
      ),
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
