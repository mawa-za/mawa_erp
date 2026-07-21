import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../models/membership_plan.dart' hide DependentType;
import '../models/membership_claim.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../../../core/widgets/attachment_section.dart';
import 'add_dependent_screen.dart';
import 'edit_dependent_screen.dart';
import 'membership_claim_create_screen.dart';
import 'membership_claim_detail_screen.dart';
import 'capture_premium_payment_dialog.dart';
import 'capture_manual_premium_receipt_dialog.dart';
import '../widgets/membership_change_section.dart';

class MembershipDetailScreen extends StatefulWidget {
  final String membershipId;
  const MembershipDetailScreen({super.key, required this.membershipId});

  @override
  State<MembershipDetailScreen> createState() => _MembershipDetailScreenState();
}

class _MembershipDetailScreenState extends State<MembershipDetailScreen> {
  bool _isLoading = true;
  MembershipDetail? _detail;
  Partner? _member;
  MembershipPlan? _plan;
  List<Dependent> _dependents = [];
  Map<String, Partner> _dependentPartners = {};
  List<Premium> _premiums = [];
  List<MembershipClaim> _claims = [];
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

      final results = await Future.wait([
        PartnerService().getPartnerById(detail.memberId).catchError((e) {
          return Partner(id: detail.memberId, number: '', type: 'INDIVIDUAL', name1: 'Unknown', name2: '', name3: '', identityNumber: '', status: 'INACTIVE');
        }),
        MembershipService().getMembershipPlanById(detail.planId).catchError((e) {
          return MembershipPlan(id: detail.planId, planCode: 'UNKNOWN', name: 'Unknown Plan', description: '', premiumCents: 0, currency: 'ZAR', maxDependents: 0, active: false);
        }),
        MembershipService().getMembershipPremiums(widget.membershipId, oldId: detail.oldId).catchError((e) => <Premium>[]),
        MembershipService().getClaimsByMembership(widget.membershipId).catchError((e) => <MembershipClaim>[]),
      ]);

      final member = results[0] as Partner;
      final plan = results[1] as MembershipPlan;
      final premiums = results[2] as List<Premium>;
      final claims = results[3] as List<MembershipClaim>;
      
      final Map<String, Partner> dependentPartners = {};
      await Future.wait(dependents.map((d) async {
        if (d.dependentPartnerId.isNotEmpty) {
          try {
            final p = await PartnerService().getPartnerById(d.dependentPartnerId);
            dependentPartners[p.id] = p;
          } catch (_) {}
        }
      }));

      premiums.sort((a, b) => b.periodYYYYMM.compareTo(a.periodYYYYMM));

      if (mounted) {
        setState(() {
          _detail = detail;
          _member = member;
          _plan = plan;
          _dependents = dependents;
          _dependentPartners = dependentPartners;
          _premiums = premiums;
          _claims = claims;
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

  Future<void> _deleteMembership() async {
    setState(() => _isLoading = true);
    try {
      await MembershipService().deleteMembership(widget.membershipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership deleted successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Membership'),
        content: const Text('Are you sure you want to delete this membership? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMembership();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Membership Details'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          if (_detail != null) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _showDeleteConfirmation();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete Membership', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddDependentScreen(membershipId: widget.membershipId)),
          );
          if (result == true) _fetchData();
        },
        label: const Text('ADD DEPENDENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        icon: const Icon(Icons.person_add_outlined),
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            FilledButton(onPressed: _fetchData, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final detail = _detail!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(detail, colorScheme),
          const SizedBox(height: 16),
          _buildCapturePaymentButton(colorScheme),
          const SizedBox(height: 10),
          _buildCaptureManualReceiptButton(colorScheme),
          const SizedBox(height: 24),
          if (_member != null) _buildMemberCard(_member!, colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.info_outline, 'MEMBERSHIP INFORMATION'),
          const SizedBox(height: 12),
          _buildMembershipInfoCard(detail, colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.swap_horiz, 'MEMBERSHIP CHANGES'),
          const SizedBox(height: 12),
          MembershipChangeSection(membership: detail, onChanged: _fetchData),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.payments_outlined, 'PAYMENT HISTORY'),
          const SizedBox(height: 12),
          _buildPremiumSection(colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.people_outline, 'DEPENDENTS'),
          const SizedBox(height: 12),
          _buildDependentsSection(colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.assignment_outlined, 'EXISTING CLAIMS'),
          const SizedBox(height: 12),
          _buildClaimsSection(colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.attach_file, 'DOCUMENTS'),
          const SizedBox(height: 12),
          _buildAttachmentSection(detail.id),
          const SizedBox(height: 80),
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

  Widget _buildStatusBanner(MembershipDetail detail, ColorScheme colorScheme) {
    Color color;
    switch (detail.status.toUpperCase()) {
      case 'ACTIVE': color = Colors.green; break;
      case 'WAITING-PERIOD':
      case 'UPGRADE-WAITING-PERIOD': color = Colors.orange; break;
      case 'INACTIVE': color = Colors.red; break;
      default: color = colorScheme.primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.shield_outlined, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.status.replaceAll('-', ' ').toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined: ${detail.joinDate ?? detail.startDate ?? '-'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PREMIUM', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
              Text(
                'R ${detail.premium.toStringAsFixed(2)}',
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureManualReceiptButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _detail == null || _member == null ? null : () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => CaptureManualPremiumReceiptDialog(membership: _detail!, member: _member!),
          );
          if (result == true) _fetchData();
        },
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('CAPTURE OUTSTANDING MANUAL RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4)),
      ),
    );
  }

  Widget _buildCapturePaymentButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => CapturePremiumPaymentDialog(
              membership: _detail!,
              member: _member!,
            ),
          );
          if (result == true) {
            _fetchData();
          }
        },
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('CAPTURE PREMIUM PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Partner member, ColorScheme colorScheme) {
    final isDeceased = member.status == 'DECEASED';
    final themeColor = isDeceased ? Colors.purple : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: isDeceased ? Colors.purple.withOpacity(0.2) : Colors.white),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: member.id, title: 'Member Details', isMemberContext: true)),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: themeColor.withOpacity(0.1),
                    child: Text(member.name2.isNotEmpty ? member.name2[0].toUpperCase() : '?',
                      style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 24)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${member.title ?? ''} ${member.fullName}'.trim(), 
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, 
                            decoration: isDeceased ? TextDecoration.lineThrough : null, color: isDeceased ? Colors.purple[900] : null)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('MEMBER NO: ${member.number}', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(member.status, isCompact: false),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildProfileRow(Icons.badge_outlined, 'Identity', '${member.idType ?? 'ID'}: ${member.identityNumber}'),
              _buildProfileRow(Icons.cake_outlined, 'Birth Date', member.birthDate ?? 'N/A'),
              _buildProfileRow(Icons.wc_outlined, 'Gender', member.gender ?? 'N/A'),
              if (member.email.isNotEmpty) _buildProfileRow(Icons.email_outlined, 'Email', member.email),
              if (member.phone.isNotEmpty) _buildProfileRow(Icons.phone_outlined, 'Phone', member.phone),
              if (!isDeceased) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => MembershipClaimCreateScreen(membership: _detail!, member: _member!, deceasedPartner: _member!)),
                      );
                      if (result == true) _fetchData();
                    },
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('PROCESS CLAIM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF20D1A)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildMembershipInfoCard(MembershipDetail detail, ColorScheme colorScheme) {
    String displayEndDate = (detail.endDate == null || detail.endDate!.isEmpty) ? 'N/A' : detail.endDate!;
    final upperEnd = displayEndDate.toUpperCase();
    if (upperEnd == 'ACTIVE' || upperEnd == 'INACTIVE' || upperEnd == 'DECEASED' || upperEnd == 'WAITING-PERIOD') {
      displayEndDate = 'N/A';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.numbers_outlined, 'Membership No', detail.membershipNo),
          if (_plan != null) ...[
            const Divider(height: 24),
            _buildInfoRow(Icons.inventory_2_outlined, 'Insurance Plan', _plan!.name),
            const Divider(height: 24),
            _buildInfoRow(Icons.payments_outlined, 'Plan Base Premium', 'R ${_plan!.premium.toStringAsFixed(2)}'),
          ],
          const Divider(height: 24),
          _buildInfoRow(Icons.account_balance_wallet_outlined, 'Membership Premium', 'R ${detail.premium.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildInfoRow(Icons.event_available, 'Start Date', detail.startDate ?? 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(Icons.event_busy, 'End Date', displayEndDate),
          const Divider(height: 24),
          _buildInfoRow(Icons.payments_outlined, 'Paid Up To', detail.paidUpToPeriod ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildPremiumSection(ColorScheme colorScheme) {
    if (_premiums.isEmpty) {
      return _buildEmptyStateCard(Icons.payments_outlined, 'No paid premiums found');
    }

    final Map<String, List<Premium>> groupedPremiums = {};
    for (var premium in _premiums) {
      final year = premium.periodYYYYMM.length >= 4 ? premium.periodYYYYMM.substring(0, 4) : 'Other';
      groupedPremiums.putIfAbsent(year, () => []).add(premium);
    }

    final sortedYears = groupedPremiums.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedYears.map((year) {
        final yearPremiums = groupedPremiums[year]!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: year == sortedYears.first,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.withOpacity(0.1),
                child: Text(year.length >= 4 ? year.substring(2) : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              title: Text('$year Premiums', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${yearPremiums.length} periods recorded', style: const TextStyle(fontSize: 12)),
              children: [
                const Divider(height: 1),
                ...yearPremiums.map((premium) {
                  final statusColor = _getPremiumStatusColor(premium.status);
                  return ListTile(
                    dense: true,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatPeriod(premium.periodYYYYMM), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('R ${premium.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 14)),
                      ],
                    ),
                    subtitle: Text('Status: ${premium.status} • Paid: R ${premium.paidAmount.toStringAsFixed(2)}\nDue Date: ${premium.dueDate ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                    trailing: Icon(premium.status == 'PAID' ? Icons.check_circle : Icons.info_outline, size: 14, color: statusColor),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getPremiumStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID': return Colors.green;
      case 'PARTIALLY_PAID': return Colors.orange;
      case 'UNPAID': return Colors.red;
      case 'CANCELLED': return Colors.grey;
      case 'REVERSED': return Colors.purple;
      default: return Colors.blue;
    }
  }

  Widget _buildDependentsSection(ColorScheme colorScheme) {
    if (_dependents.isEmpty) {
      return _buildEmptyStateCard(Icons.people_outline, 'No dependents linked to this policy');
    }

    return Column(
      children: _dependents.map((dependent) {
        final partner = _dependentPartners[dependent.dependentPartnerId];
        String displayName = partner?.fullName ?? dependent.fullName;
        String displayId = partner?.identityNumber ?? dependent.identity?.number ?? 'N/A';
        String displayIdType = partner?.idType ?? dependent.identity?.type.description ?? 'ID';
        final isDeceased = partner?.status == 'DECEASED';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isDeceased ? Colors.purple.withOpacity(0.1) : colorScheme.secondaryContainer,
                child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', 
                  style: TextStyle(color: isDeceased ? Colors.purple : colorScheme.onSecondaryContainer, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              title: Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isDeceased ? TextDecoration.lineThrough : null)),
              subtitle: Text(DependentType.fromString(dependent.dependentType).label, style: const TextStyle(fontSize: 12)),
              trailing: _buildStatusChip(partner?.status ?? 'ACTIVE', isCompact: true),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildProfileRow(Icons.badge_outlined, 'Identity', '$displayIdType: $displayId'),
                      _buildProfileRow(Icons.cake_outlined, 'Birth Date', partner?.birthDate ?? dependent.birthDate ?? 'N/A'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isDeceased)
                            TextButton(
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => MembershipClaimCreateScreen(membership: _detail!, member: _member!, dependent: dependent, deceasedPartner: partner)),
                                );
                                if (result == true) _fetchData();
                              },
                              child: const Text('PROCESS CLAIM', style: TextStyle(color: const Color(0xFFF20D1A), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: dependent.dependentPartnerId, title: 'Dependent Details', isMemberContext: true)),
                            ),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), visualDensity: VisualDensity.compact),
                            child: const Text('FULL PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClaimsSection(ColorScheme colorScheme) {
    if (_claims.isEmpty) {
      return _buildEmptyStateCard(Icons.assignment_outlined, 'No claims recorded for this membership');
    }

    return Column(
      children: _claims.map((claim) {
        Color statusColor;
        switch (claim.status.toUpperCase()) {
          case 'APPROVED': statusColor = Colors.green; break;
          case 'REJECTED': statusColor = Colors.red; break;
          case 'SUBMITTED': statusColor = Colors.orange; break;
          default: statusColor = Colors.blue;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
          child: ListTile(
            onTap: () async {
              final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => MembershipClaimDetailScreen(claimId: claim.id)));
              if (result == true) _fetchData();
            },
            leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(Icons.description_outlined, color: statusColor, size: 20)),
            title: Text('Claim #${claim.claimNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${claim.claimType} • ${claim.claimDate}', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R ${claim.claimAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
                Text(claim.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentSection(String membershipId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: AttachmentSection(objectId: membershipId),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildEmptyStateCard(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool isCompact = false}) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE': color = Colors.green; break;
      case 'INACTIVE': color = Colors.red; break;
      case 'DECEASED': color = Colors.purple; break;
      default: color = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(status.replaceAll('-', ' '), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  String _formatPeriod(String period) {
    if (period.length != 6) return period;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final year = period.substring(0, 4);
    final month = int.tryParse(period.substring(4, 6)) ?? 0;
    return (month >= 1 && month <= 12) ? '${months[month - 1]} $year' : period;
  }
}
