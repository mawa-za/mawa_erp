import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../models/membership_plan.dart';
import '../models/membership_claim.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../../../core/widgets/attachment_section.dart';
import 'edit_membership_screen.dart';
import 'add_dependent_screen.dart';
import 'edit_dependent_screen.dart';
import 'membership_claim_create_screen.dart';
import 'membership_claim_detail_screen.dart';

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

      // Step 1: Fetch core data
      final results = await Future.wait([
        PartnerService().getPartnerById(detail.memberId).catchError((e) {
          debugPrint('Failed to load member partner: $e');
          return Partner(id: detail.memberId, number: '', type: 'INDIVIDUAL', name1: 'Unknown', name2: '', name3: '', identityNumber: '', status: 'INACTIVE');
        }),
        MembershipService().getMembershipPlanById(detail.planId).catchError((e) {
          debugPrint('Failed to load plan: $e');
          return MembershipPlan(id: detail.planId, planCode: 'UNKNOWN', name: 'Unknown Plan', description: '', premiumCents: 0, currency: 'ZAR', maxDependents: 0, active: false);
        }),
        MembershipService().getMembershipPremiums(widget.membershipId, oldId: detail.oldId).catchError((e) {
          debugPrint('Failed to load premiums: $e');
          return <Premium>[];
        }),
        MembershipService().getClaimsByMembership(widget.membershipId).catchError((e) {
          debugPrint('Failed to load claims: $e');
          return <MembershipClaim>[];
        }),
      ]);

      final member = results[0] as Partner;
      final plan = results[1] as MembershipPlan;
      final premiums = results[2] as List<Premium>;
      final claims = results[3] as List<MembershipClaim>;
      
      // Step 2: Fetch dependent partners individually (resilient)
      final Map<String, Partner> dependentPartners = {};
      await Future.wait(dependents.map((d) async {
        if (d.dependentPartnerId.isNotEmpty) {
          try {
            final p = await PartnerService().getPartnerById(d.dependentPartnerId);
            dependentPartners[p.id] = p;
          } catch (e) {
            debugPrint('Failed to load dependent partner ${d.dependentPartnerId}: $e');
          }
        }
      }));

      // Sort premiums by period DESC
      premiums.sort((a, b) => b.membershipPeriod.compareTo(a.membershipPeriod));

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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMembership();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_detail != null ? 'Membership #${_detail!.membershipNo}' : 'Membership Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_detail != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditMembershipScreen(membership: _detail!),
                  ),
                );
                if (result == true) _fetchData();
              },
              tooltip: 'Edit Membership',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _showDeleteConfirmation();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete Membership', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
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
            MaterialPageRoute(
              builder: (context) => AddDependentScreen(membershipId: widget.membershipId),
            ),
          );
          if (result == true) _fetchData();
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
          if (_member != null) _buildMemberCard(_member!, colorScheme),
          const SizedBox(height: 16),
          _buildMembershipInfoCard(detail, colorScheme),
          const SizedBox(height: 16),
          _buildPremiumSection(colorScheme),
          const SizedBox(height: 16),
          _buildDependentsSection(colorScheme),
          const SizedBox(height: 16),
          _buildClaimsSection(colorScheme),
          const SizedBox(height: 16),
          _buildAttachmentSection(detail.id),
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MembershipDetail detail) {
    Color color;
    switch (detail.status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'WAITING-PERIOD':
      case 'UPGRADE-WAITING-PERIOD':
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
                detail.status.replaceAll('-', ' ').toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
              Text(
                'Joined: ${detail.joinDate ?? detail.startDate ?? '-'}',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (_plan != null)
            Text(
              'R ${_plan!.premium.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Partner member, ColorScheme colorScheme) {
    final isDeceased = member.status == 'DECEASED';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: isDeceased ? Colors.purple.withOpacity(0.3) : Colors.grey.shade200)
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PartnerDetailScreen(partnerId: member.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDeceased ? Colors.purple.withOpacity(0.1) : colorScheme.primaryContainer,
                    child: Text(member.name2.isNotEmpty ? member.name2[0].toUpperCase() : '?',
                      style: TextStyle(color: isDeceased ? Colors.purple : colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${member.title ?? ''} ${member.fullName}'.trim(), 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: isDeceased ? TextDecoration.lineThrough : null)),
                        Text('No: ${member.number}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusChip(member.status, isCompact: true),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(Icons.badge_outlined, 'Identity', '${member.idType ?? 'ID'}: ${member.identityNumber}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.cake_outlined, 'Birth Date', member.birthDate ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person_outline, 'Gender', member.gender ?? 'N/A'),
              if (member.email.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email_outlined, 'Email', member.email),
              ],
              if (member.phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_outlined, 'Phone', member.phone),
              ],
              if (!isDeceased) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MembershipClaimCreateScreen(
                              membership: _detail!,
                              member: _member!,
                              deceasedPartner: _member!,
                            ),
                          ),
                        );
                        if (result == true) _fetchData();
                      },
                      icon: const Icon(Icons.request_quote_outlined, size: 16, color: Colors.deepPurple),
                      label: const Text('Process Claim', style: TextStyle(color: Colors.deepPurple)),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
            _buildInfoRow(Icons.numbers_outlined, 'Membership No', detail.membershipNo),
            const SizedBox(height: 8),
            if (_plan != null)
              _buildInfoRow(Icons.inventory_2_outlined, 'Plan', _plan!.name),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_available, 'Start Date', detail.startDate ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_busy, 'End Date', detail.endDate ?? 'Active'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.payments_outlined, 'Paid Up To', detail.paidUpToPeriod ?? 'N/A'),
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
                child: Text(year.length >= 4 ? year.substring(2) : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
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
          ..._dependents.map((dependent) {
            final partner = _dependentPartners[dependent.dependentPartnerId];
            
            // Robust name display
            String displayName = 'Unnamed Dependent';
            if (partner != null && partner.fullName != 'Unnamed Partner') {
              displayName = partner.fullName;
            } else if (dependent.fullName != 'Unnamed Dependent') {
              displayName = dependent.fullName;
            }

            // Robust identity display
            String displayId = 'N/A';
            if (partner != null && partner.identityNumber.isNotEmpty) {
              displayId = partner.identityNumber;
            } else if (dependent.identity?.number.isNotEmpty == true) {
              displayId = dependent.identity!.number;
            }

            String displayIdType = partner?.idType ?? dependent.identity?.type.description ?? 'ID';
            final isDeceased = partner?.status == 'DECEASED';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isDeceased ? Colors.purple.withOpacity(0.1) : colorScheme.secondaryContainer,
                  child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', 
                    style: TextStyle(color: isDeceased ? Colors.purple : colorScheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                title: Text('${partner?.title ?? dependent.title?.description ?? ''} $displayName'.trim(), 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isDeceased ? TextDecoration.lineThrough : null)),
                subtitle: Text('No: ${partner?.number ?? dependent.number} • ${dependent.relationship.replaceAll('-', ' ')}', style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip(partner?.status ?? dependent.status?.description ?? (dependent.active ? 'Active' : 'Inactive'), isCompact: true),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        _buildInfoRow(Icons.badge_outlined, 'Identity', '$displayIdType: $displayId'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.cake_outlined, 'Birth Date', partner?.birthDate ?? dependent.birthDate ?? 'N/A'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.wc_outlined, 'Gender/Marital', '${partner?.gender ?? dependent.gender?.description ?? 'N/A'} / ${partner?.maritalStatus ?? dependent.maritalStatus?.description ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.calendar_today_outlined, 'Date Added', dependent.createdAt ?? 'N/A'),
                        if (partner != null) ...[
                          if (partner.email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.email_outlined, 'Email', partner.email),
                          ],
                          if (partner.phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.phone_outlined, 'Phone', partner.phone),
                          ],
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!isDeceased)
                              TextButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MembershipClaimCreateScreen(
                                        membership: _detail!,
                                        member: _member!,
                                        dependent: dependent,
                                        deceasedPartner: partner,
                                      ),
                                    ),
                                  );
                                  if (result == true) _fetchData();
                                },
                                icon: const Icon(Icons.request_quote_outlined, size: 16, color: Colors.deepPurple),
                                label: const Text('Process Claim', style: TextStyle(color: Colors.deepPurple)),
                              ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EditDependentScreen(
                                      membershipId: widget.membershipId,
                                      dependent: dependent,
                                    ),
                                  ),
                                );
                                if (result == true) _fetchData();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit Link'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PartnerDetailScreen(partnerId: dependent.dependentPartnerId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_outline, size: 16),
                              label: const Text('Full Profile'),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildClaimsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('EXISTING CLAIMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ),
        if (_claims.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No claims found for this membership', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          )
        else
          ..._claims.map((claim) {
            Color statusColor;
            switch (claim.status.toUpperCase()) {
              case 'APPROVED': statusColor = Colors.green; break;
              case 'REJECTED': statusColor = Colors.red; break;
              case 'SUBMITTED': statusColor = Colors.orange; break;
              default: statusColor = Colors.blue;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MembershipClaimDetailScreen(claimId: claim.id),
                    ),
                  );
                  if (result == true) _fetchData();
                },
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.assignment_outlined, color: statusColor, size: 20),
                ),
                title: Text('Claim #${claim.claimNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${claim.claimType} • ${claim.claimDate}', style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('R ${claim.claimAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(claim.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),
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
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.red;
        break;
      case 'DECEASED':
        color = Colors.purple;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.replaceAll('-', ' '), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
