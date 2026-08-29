import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../models/receipt_response.dart';
import '../models/membership_plan.dart' hide DependentType;
import '../models/membership_claim.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../../settings/services/pos_printing_service.dart';
import '../../../core/services/setting_service.dart';
import '../../../core/widgets/attachment_section.dart';
import 'add_dependent_screen.dart';
import 'edit_dependent_screen.dart';
import 'membership_claim_create_screen.dart';
import 'membership_claim_detail_screen.dart';
import 'capture_premium_payment_dialog.dart';
import 'capture_manual_premium_receipt_dialog.dart';
import 'transfer_premium_payment_dialog.dart';
import '../widgets/membership_change_section.dart';
import '../utils/membership_claim_eligibility.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
  bool _allowPremiumPaymentTransfer = false;
  bool _allowDeleteWithoutCashupValidation = false;
  bool _hasPendingMembershipStatusChange = false;
  String? _pendingMembershipStatusAction;
  String? _error;

  String get _normalizedMembershipStatus =>
      (_detail?.status ?? '').trim().toUpperCase().replaceAll('-', '_');

  bool get _isLapsedMembership => _normalizedMembershipStatus == 'LAPSED';
  bool get _isMergedMembership => _normalizedMembershipStatus == 'MERGED';

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
        MembershipService().getPendingMembershipStatusChange(widget.membershipId).catchError(
          (e) => <String, dynamic>{'pending': false},
        ),
      ]);

      final member = results[0] as Partner;
      final plan = results[1] as MembershipPlan;
      final premiums = results[2] as List<Premium>;
      final claims = results[3] as List<MembershipClaim>;
      final pendingStatusChange = results[4] as Map<String, dynamic>;

      var allowPremiumPaymentTransfer = false;
      var allowDeleteWithoutCashupValidation = false;
      try {
        final settings = await SettingService().getSettings();
        for (final setting in settings) {
          if (setting.type.trim().toUpperCase() != 'MEMBERSHIP') continue;
          final value = setting.value.trim().toLowerCase();
          final enabled = value == '1' ||
              value == 'true' ||
              value == 'yes' ||
              value == 'on';
          switch (setting.attribute.trim().toUpperCase()) {
            case 'ALLOW_PREMIUM_PAYMENT_TRANSFER':
              allowPremiumPaymentTransfer = enabled;
              break;
            case 'ALLOW_PREMIUM_PAYMENT_DELETE_WITHOUT_CASHUP_VALIDATION':
              allowDeleteWithoutCashupValidation = enabled;
              break;
          }
        }
      } catch (_) {
        // Restricted correction actions remain disabled when settings cannot load.
      }

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
          _allowPremiumPaymentTransfer = allowPremiumPaymentTransfer;
          _allowDeleteWithoutCashupValidation = allowDeleteWithoutCashupValidation;
          _hasPendingMembershipStatusChange = pendingStatusChange['pending'] == true;
          _pendingMembershipStatusAction = pendingStatusChange['action']?.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _replaceDependent(Dependent dependent) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditDependentScreen(
        membershipId: widget.membershipId,
        dependent: dependent,
      ),
    );
    if (result == true) _fetchData();
  }

  Future<void> _removeDependent(Dependent dependent) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Remove Dependent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove ${dependent.fullName} from active membership cover? The history will be retained.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  helperText: 'Approval is required when the membership is at least one month old.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            FilledButton(
              onPressed: reasonController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('REMOVE'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }
    try {
      final change = await MembershipService().removeDependent(
        widget.membershipId,
        dependent.id,
        reasonController.text.trim(),
      );
      if (!mounted) return;
      final pending = change.status == 'PENDING_APPROVAL';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pending
              ? 'Dependent removal submitted for approval'
              : 'Dependent removed successfully'),
          backgroundColor: pending ? Colors.orange[800] : Colors.green[700],
        ),
      );
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Membership Details'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
      floatingActionButton: _detail != null && !_isLapsedMembership && !_isMergedMembership
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AddDependentScreen(membershipId: widget.membershipId),
                );
                if (result == true) _fetchData();
              },
              label: const Text('ADD DEPENDENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              icon: const Icon(Icons.person_add_outlined),
            )
          : null,
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
          if (_isMergedMembership) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.blue.shade50,
              child: ListTile(
                leading: const Icon(Icons.merge_outlined, color: Colors.blue),
                title: const Text('This membership has been merged and is read-only.'),
                subtitle: Text('Its surviving membership contains the consolidated operational history.${detail.mergedAt == null ? '' : ' Merged ${detail.mergedAt}.'}'),
                trailing: detail.mergedIntoMembershipId == null ? null : FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => MembershipDetailScreen(membershipId: detail.mergedIntoMembershipId!),
                  )),
                  child: const Text('OPEN PRIMARY'),
                ),
              ),
            ),
          ],
          if (_isLapsedMembership) ...[
            const SizedBox(height: 12),
            _buildLapsedRestrictionNotice(),
          ] else if (!_isMergedMembership) ...[
            const SizedBox(height: 16),
            _buildCapturePaymentButton(colorScheme),
            const SizedBox(height: 10),
            _buildCaptureManualReceiptButton(colorScheme),
          ],
          const SizedBox(height: 24),
          if (_member != null) _buildMemberCard(_member!, colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.info_outline, 'MEMBERSHIP INFORMATION'),
          const SizedBox(height: 12),
          _buildMembershipInfoCard(detail, colorScheme),
          const SizedBox(height: 32),
          _buildSectionHeader(Icons.swap_horiz, 'MEMBERSHIP CHANGES'),
          const SizedBox(height: 12),
          MembershipChangeSection(membership: detail, onChanged: _fetchData, readOnly: _isLapsedMembership || _isMergedMembership),
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

  Widget _buildLapsedRestrictionNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This membership is lapsed and is read-only. Reactivate it and wait for the reactivation approval to be completed before any other membership action becomes available.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
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
    final normalizedStatus = detail.status.trim().toUpperCase().replaceAll('-', '_');
    Color color;
    switch (normalizedStatus) {
      case 'ACTIVE': color = Colors.green; break;
      case 'WAITING_PERIOD':
      case 'UPGRADE_WAITING_PERIOD':
      case 'SUSPENDED': color = Colors.orange; break;
      case 'INACTIVE': color = Colors.grey.shade700; break;
      case 'CANCELLED':
      case 'CANCELED': color = Colors.red; break;
      case 'LAPSED': color = Colors.red.shade800; break;
      default: color = colorScheme.primary;
    }

    final actions = <MapEntry<String, String>>[];
    switch (normalizedStatus) {
      case 'ACTIVE':
        actions.addAll(const [
          MapEntry('SUSPEND', 'Suspend'),
          MapEntry('DEACTIVATE', 'Deactivate'),
          MapEntry('CANCEL', 'Cancel'),
        ]);
        break;
      case 'SUSPENDED':
        actions.addAll(const [
          MapEntry('REACTIVATE', 'Reactivate'),
          MapEntry('DEACTIVATE', 'Deactivate'),
          MapEntry('CANCEL', 'Cancel'),
        ]);
        break;
      case 'INACTIVE':
        actions.addAll(const [
          MapEntry('REACTIVATE', 'Reactivate'),
          MapEntry('SUSPEND', 'Suspend'),
          MapEntry('CANCEL', 'Cancel'),
        ]);
        break;
      case 'CANCELLED':
      case 'CANCELED':
        actions.add(const MapEntry('REACTIVATE', 'Reactivate'));
        break;
      case 'LAPSED':
        actions.add(const MapEntry('REACTIVATE', 'Reactivate'));
        break;
    }
    if (_hasPendingMembershipStatusChange) {
      actions.clear();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          if (_hasPendingMembershipStatusChange) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Text(
                '${(_pendingMembershipStatusAction ?? 'Status change').replaceAll('_', ' ')} request is awaiting approval. Membership access remains restricted until approval is completed.',
                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((entry) {
                final destructive = entry.key == 'CANCEL';
                return OutlinedButton.icon(
                  onPressed: () => _requestMembershipStatusChange(entry.key, entry.value),
                  icon: Icon(
                    entry.key == 'REACTIVATE' ? Icons.play_circle_outline :
                    entry.key == 'SUSPEND' ? Icons.pause_circle_outline :
                    entry.key == 'DEACTIVATE' ? Icons.block_outlined : Icons.cancel_outlined,
                    size: 18,
                  ),
                  label: Text(entry.value.toUpperCase()),
                  style: destructive ? OutlinedButton.styleFrom(foregroundColor: Colors.red) : null,
                );
              }).toList(),
            ),
          ],
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
        label: const Text('PROCESS PREMIUM PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Partner member, ColorScheme colorScheme) {
    final isDeceased = member.status == 'DECEASED';
    final canProcessClaim = canProcessMembershipClaim(
      currentMembershipId: widget.membershipId,
      deceasedPartnerId: member.id,
      claims: _claims,
    );
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
              if (canProcessClaim && !_isLapsedMembership) ...[
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

  Future<void> _reprintPremiumReceipt(Premium premium) async {
    try {
      final receipts = await MembershipService().getPremiumReceipts(
        widget.membershipId,
        premium.id,
      );
      if (!mounted) return;
      if (receipts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No receipt is available for this premium.')),
        );
        return;
      }

      ReceiptResponse? selectedReceipt;
      if (receipts.length == 1) {
        selectedReceipt = receipts.first;
      } else {
        selectedReceipt = await showDialog<ReceiptResponse>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Reprint ${_formatPeriod(premium.periodYYYYMM)} receipt'),
            content: SizedBox(
              width: 480,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: receipts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final receipt = receipts[index];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(receipt.receiptNo),
                    subtitle: Text(
                      '${receipt.paymentMethod} • R ${receipt.totalAmount.toStringAsFixed(2)}',
                    ),
                    trailing: const Icon(Icons.print_outlined),
                    onTap: () => Navigator.pop(context, receipt),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        );
      }

      if (selectedReceipt == null) return;
      await PosPrintingService().queueReceipt(selectedReceipt.id, reprint: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt ${selectedReceipt.receiptNo} queued for reprint.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Unable to reprint receipt: $error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestPremiumPaymentDeletion(Premium premium) async {
    try {
      final receipts = await MembershipService().getPremiumReceipts(
        widget.membershipId,
        premium.id,
      );
      if (!mounted) return;
      if (receipts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No posted receipt is available for this premium payment.')),
        );
        return;
      }

      ReceiptResponse? selectedReceipt;
      if (receipts.length == 1) {
        selectedReceipt = receipts.first;
      } else {
        selectedReceipt = await showDialog<ReceiptResponse>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select payment to delete'),
            content: SizedBox(
              width: 480,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: receipts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final receipt = receipts[index];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(receipt.receiptNo),
                    subtitle: Text('${receipt.paymentMethod} • R ${receipt.totalAmount.toStringAsFixed(2)}'),
                    onTap: () => Navigator.pop(context, receipt),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ],
          ),
        );
      }
      if (selectedReceipt == null) return;
      if (selectedReceipt.paymentBatchId.trim().isEmpty) {
        throw StateError('This receipt does not have a payment batch reference.');
      }

      final reasonController = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request premium payment deletion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _allowDeleteWithoutCashupValidation
                    ? 'The full payment batch will be reversed only after approval. Cash-up OPEN-status validation is disabled by configuration.'
                    : 'The full payment batch will be reversed only after approval. This is allowed only while its linked cash-up remains OPEN.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (reason == null || reason.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final requesterId = prefs.getString('userId') ?? '';
      await MembershipService().requestPremiumPaymentDeletion(
        paymentBatchId: selectedReceipt.paymentBatchId,
        requesterId: requesterId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium payment deletion submitted for approval.')),
      );
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Unable to request premium payment deletion: $error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestMembershipStatusChange(String action, String label) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$label membership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label will take effect only after the approval request is approved.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      );
      if (reason == null || reason.trim().isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final requestedBy = (prefs.getString('userId') ?? '').trim();
      if (requestedBy.isEmpty) throw StateError('Unable to identify the logged-in user. Please log in again.');
      await MembershipService().requestMembershipStatusChange(
        membershipId: widget.membershipId,
        action: action,
        requestedBy: requestedBy,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label membership request submitted for approval.')),
      );
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Unable to submit membership status change: $error')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _requestPremiumPaymentEdit(Premium premium) async {
    try {
      final receipts = (await MembershipService().getPremiumReceipts(widget.membershipId, premium.id))
          .where((receipt) => receipt.status.trim().toUpperCase() == 'POSTED')
          .toList();
      if (!mounted) return;
      if (receipts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No posted receipt is available for this premium payment.')),
        );
        return;
      }

      ReceiptResponse? selectedReceipt;
      if (receipts.length == 1) {
        selectedReceipt = receipts.first;
      } else {
        selectedReceipt = await showDialog<ReceiptResponse>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select payment to edit'),
            content: SizedBox(
              width: 500,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: receipts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final receipt = receipts[index];
                  return ListTile(
                    leading: const Icon(Icons.edit_note_outlined),
                    title: Text(receipt.receiptNo),
                    subtitle: Text('${receipt.paymentMethod} • R ${receipt.totalAmount.toStringAsFixed(2)}'),
                    onTap: () => Navigator.pop(context, receipt),
                  );
                },
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL'))],
          ),
        );
      }
      if (selectedReceipt == null) return;
      if (selectedReceipt.paymentBatchId.trim().isEmpty) {
        throw StateError('This receipt does not have a payment batch reference.');
      }

      final premiumAllocations = selectedReceipt.allocations.where((a) =>
          a.status.trim().toUpperCase() == 'POSTED' &&
          a.allocationType.trim().toUpperCase() == 'MEMBERSHIP_PREMIUM').toList();
      final currentPeriod = premiumAllocations.length == 1 && premiumAllocations.first.periodYYYYMM.trim().length == 6
          ? premiumAllocations.first.periodYYYYMM.trim()
          : premium.periodYYYYMM.trim();
      final now = DateTime.now();
      final currentYear = int.tryParse(currentPeriod.length >= 4 ? currentPeriod.substring(0, 4) : '') ?? now.year;
      final currentMonth = int.tryParse(currentPeriod.length == 6 ? currentPeriod.substring(4, 6) : '') ?? now.month;
      final years = <int>{currentYear, for (var y = now.year - 10; y <= now.year + 2; y++) y}.toList()..sort();
      var selectedYear = currentYear;
      var selectedMonth = currentMonth.clamp(1, 12).toInt();
      final amountController = TextEditingController(text: selectedReceipt.totalAmount.toStringAsFixed(2));
      final reasonController = TextEditingController();

      final edit = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit premium payment'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Receipt ${selectedReceipt!.receiptNo}. Changes take effect only after approval.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Payment amount *', prefixText: 'R ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: const InputDecoration(labelText: 'Payment year *', border: OutlineInputBorder()),
                            items: years.map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
                            onChanged: (value) => setDialogState(() => selectedYear = value ?? selectedYear),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: const InputDecoration(labelText: 'Payment month *', border: OutlineInputBorder()),
                            items: List.generate(12, (i) => i + 1).map((month) => DropdownMenuItem(
                              value: month,
                              child: Text(DateFormat('MMMM').format(DateTime(2000, month))),
                            )).toList(),
                            onChanged: (value) => setDialogState(() => selectedMonth = value ?? selectedMonth),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Reason for correction *', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                  final reason = reasonController.text.trim();
                  if (amount == null || amount <= 0 || reason.isEmpty) return;
                  Navigator.pop(context, {
                    'amountCents': (amount * 100).round(),
                    'periodYYYYMM': '${selectedYear.toString().padLeft(4, '0')}${selectedMonth.toString().padLeft(2, '0')}',
                    'reason': reason,
                  });
                },
                child: const Text('SUBMIT FOR APPROVAL'),
              ),
            ],
          ),
        ),
      );
      amountController.dispose();
      reasonController.dispose();
      if (edit == null) return;

      final prefs = await SharedPreferences.getInstance();
      final requestedBy = (prefs.getString('userId') ?? '').trim();
      if (requestedBy.isEmpty) throw StateError('Unable to identify the logged-in user. Please log in again.');
      await MembershipService().requestPremiumPaymentEdit(
        paymentBatchId: selectedReceipt.paymentBatchId,
        receiptId: selectedReceipt.id,
        amountCents: edit['amountCents'] as int,
        periodYYYYMM: edit['periodYYYYMM'] as String,
        requestedBy: requestedBy,
        reason: edit['reason'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium payment edit submitted for approval.')),
      );
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Unable to edit premium payment: $error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestGeneratedPremiumEdit(Premium premium) async {
    final amountController = TextEditingController(text: premium.amount.toStringAsFixed(2));
    final reasonController = TextEditingController();
    final edit = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit generated premium ${_formatPeriod(premium.periodYYYYMM)}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current amount: R ${premium.amount.toStringAsFixed(2)}'),
                if (premium.paidAmount > 0)
                  Text('Already paid: R ${premium.paidAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Correct premium amount *',
                    prefixText: 'R ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Reason for correction *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Only this generated premium period will change after final approval.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                final cents = value == null ? 0 : (value * 100).round();
                if (cents <= 0 || cents == premium.amountCents ||
                    cents < premium.paidAmountCents || reasonController.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'amountCents': cents,
                  'reason': reasonController.text.trim(),
                });
              },
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    reasonController.dispose();
    if (edit == null || !mounted) return;
    try {
      await MembershipService().requestGeneratedPremiumEdit(
        membershipId: widget.membershipId,
        premiumId: premium.id,
        amountCents: edit['amountCents'] as int,
        reason: edit['reason'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Premium ${_formatPeriod(premium.periodYYYYMM)} edit submitted for approval.')),
      );
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage('Unable to edit generated premium: $error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _transferPremiumPayment(Premium premium) async {
    try {
      final receipts = await MembershipService().getPremiumReceipts(
        widget.membershipId,
        premium.id,
      );
      if (!mounted) return;
      final manualReceipts = receipts
          .where((receipt) =>
              receipt.status.toUpperCase() == 'POSTED' &&
              receipt.isManualPremiumReceipt)
          .toList();
      if (manualReceipts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only manually captured premium payments can be transferred.'),
          ),
        );
        return;
      }

      ReceiptResponse? selectedReceipt;
      if (manualReceipts.length == 1) {
        selectedReceipt = manualReceipts.first;
      } else {
        selectedReceipt = await showDialog<ReceiptResponse>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select manual payment to transfer'),
            content: SizedBox(
              width: 500,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: manualReceipts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final receipt = manualReceipts[index];
                  final manualNo = receipt.manualReceiptNo.trim();
                  final legacyManualNo = receipt.externalReceiptNo.trim();
                  final displayManualNo = manualNo.isNotEmpty
                      ? manualNo
                      : legacyManualNo;
                  return ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(receipt.receiptNo),
                    subtitle: Text(
                      '${displayManualNo.isEmpty ? 'Manual receipt' : 'Manual receipt $displayManualNo'} • R ${receipt.totalAmount.toStringAsFixed(2)}',
                    ),
                    onTap: () => Navigator.pop(context, receipt),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        );
      }
      if (selectedReceipt == null) return;
      final receiptToTransfer = selectedReceipt;
      if (receiptToTransfer.paymentBatchId.trim().isEmpty) {
        throw StateError('This receipt does not have a payment batch reference.');
      }

      final transfer = await showDialog<PremiumPaymentTransferInput>(
        context: context,
        builder: (context) => TransferPremiumPaymentDialog(
          currentMembershipId: widget.membershipId,
          sourcePeriodYYYYMM: premium.periodYYYYMM,
          amountCents: receiptToTransfer.totalAmountCents,
        ),
      );
      if (transfer == null) return;

      final prefs = await SharedPreferences.getInstance();
      final requesterId = (prefs.getString('userId') ?? '').trim();
      if (requesterId.isEmpty) {
        throw StateError('The current user could not be identified.');
      }

      await MembershipService().transferManualPremiumPayment(
        paymentBatchId: receiptToTransfer.paymentBatchId,
        targetMembershipId: transfer.targetMembershipId,
        targetPeriodYYYYMM: transfer.targetPeriodYYYYMM,
        requestedBy: requesterId,
        reason: transfer.reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium payment transferred successfully.')),
      );
      await _fetchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage('Unable to transfer premium payment: $error'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPremiumSection(ColorScheme colorScheme) {
    if (_premiums.isEmpty) {
      return _buildEmptyStateCard(
        Icons.payments_outlined,
        'No membership premiums found',
      );
    }

    final Map<String, List<Premium>> groupedPremiums = {};
    for (final premium in _premiums) {
      final year = premium.periodYYYYMM.length >= 4
          ? premium.periodYYYYMM.substring(0, 4)
          : 'Other';
      groupedPremiums.putIfAbsent(year, () => []).add(premium);
    }

    final sortedYears = groupedPremiums.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedYears.map((year) {
        final yearPremiums = List<Premium>.from(groupedPremiums[year]!)
          ..sort((a, b) => b.periodYYYYMM.compareTo(a.periodYYYYMM));
        final paidPeriods = yearPremiums
            .where((premium) => premium.status.toUpperCase() == 'PAID')
            .length;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: year == sortedYears.first,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: colorScheme.primaryContainer.withOpacity(0.6),
                child: Text(
                  year.length >= 4 ? year.substring(2) : '?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              title: Text(
                '$year Premiums',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '$paidPeriods paid • ${yearPremiums.length} periods',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                const Divider(height: 1),
                ...yearPremiums.map(
                  (premium) => _buildPremiumHistoryRow(
                    premium,
                    colorScheme,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPremiumHistoryRow(
    Premium premium,
    ColorScheme colorScheme,
  ) {
    final statusColor = _getPremiumStatusColor(premium.status);
    final hasPaymentDate = premium.paymentDate?.trim().isNotEmpty == true;
    final hasCashier = premium.cashier?.trim().isNotEmpty == true;
    final hasReceipt = premium.receiptNo?.trim().isNotEmpty == true;
    final hasMethod = premium.paymentMethod?.trim().isNotEmpty == true;
    final hasLocation = premium.paymentLocation?.trim().isNotEmpty == true;
    final hasDevice = premium.deviceId?.trim().isNotEmpty == true;

    final facts = <MapEntry<String, String>>[
      MapEntry(
        'Paid',
        'R ${premium.paidAmount.toStringAsFixed(2)}',
      ),
      MapEntry(
        'Balance',
        'R ${premium.balance.toStringAsFixed(2)}',
      ),
      if (hasPaymentDate)
        MapEntry(
          'Payment date',
          _formatPremiumPaymentDate(premium.paymentDate),
        ),
      if (hasCashier)
        MapEntry(
          'Cashier / collector',
          _displayPremiumValue(premium.cashier),
        ),
      if (hasReceipt)
        MapEntry(
          'Receipt',
          _displayPremiumValue(premium.receiptNo),
        ),
      if (hasMethod)
        MapEntry(
          'Method',
          _displayPremiumValue(premium.paymentMethod),
        ),
      if (hasLocation)
        MapEntry(
          'Location',
          _displayPremiumValue(premium.paymentLocation),
        ),
      if (hasDevice)
        MapEntry(
          'Terminal / device',
          _displayPremiumValue(premium.deviceId),
        ),
      if (premium.paymentCount > 1)
        MapEntry(
          'Payments',
          '${premium.paymentCount} receipts',
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 640 ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.7),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final gap = compact ? 10.0 : 18.0;
          final factWidth = compact
              ? ((constraints.maxWidth - gap) / 2)
                  .clamp(105.0, 220.0)
                  .toDouble()
              : 170.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _premiumPeriodSummary(
                        premium,
                        colorScheme,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'R ${premium.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _premiumStatusChip(
                    premium.status,
                    statusColor,
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _premiumPeriodSummary(
                        premium,
                        colorScheme,
                      ),
                    ),
                    _premiumStatusChip(
                      premium.status,
                      statusColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R ${premium.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: compact ? 7 : 10,
                children: facts
                    .map(
                      (fact) => _premiumFact(
                        fact.key,
                        fact.value,
                        width: factWidth,
                      ),
                    )
                    .toList(),
              ),
              if (!_isMergedMembership &&
                  premium.status.toUpperCase() != 'CANCELLED' &&
                  premium.status.toUpperCase() != 'REVERSED') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _requestGeneratedPremiumEdit(premium),
                    icon: const Icon(Icons.price_change_outlined, size: 18),
                    label: const Text('EDIT PREMIUM'),
                  ),
                ),
              ],
              if (!_isLapsedMembership &&
                  (premium.paymentCount > 0 || premium.receiptId?.trim().isNotEmpty == true)) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _reprintPremiumReceipt(premium),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('REPRINT RECEIPT'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _requestPremiumPaymentEdit(premium),
                        icon: const Icon(Icons.edit_note_outlined, size: 18),
                        label: const Text('EDIT PAYMENT'),
                      ),
                      if (_allowPremiumPaymentTransfer)
                        OutlinedButton.icon(
                          onPressed: () => _transferPremiumPayment(premium),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('TRANSFER PAYMENT'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _requestPremiumPaymentDeletion(premium),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('DELETE PAYMENT'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _premiumPeriodSummary(
    Premium premium,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatPeriod(premium.periodYYYYMM),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Due ${premium.dueDate ?? 'N/A'}',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _premiumStatusChip(
    String status,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _premiumFact(
    String label,
    String value, {
    double width = 170,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _displayPremiumValue(String? value) {
    final display = value?.trim() ?? '';
    return display.isEmpty ? 'N/A' : display;
  }

  String _formatPremiumPaymentDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;
    return DateFormat('dd MMM yyyy • HH:mm').format(parsed.toLocal());
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

  String _formatDependentDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    return parsed == null ? value : DateFormat('dd MMM yyyy').format(parsed);
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
        final deceasedOnCurrentMembership = dependent.membershipStatus == 'DECEASED';
        final isDeceased = deceasedOnCurrentMembership || partner?.status == 'DECEASED';
        final canProcessClaim = canProcessMembershipClaim(
          currentMembershipId: widget.membershipId,
          deceasedPartnerId: dependent.dependentPartnerId,
          claims: _claims,
          deceasedOnCurrentMembership: deceasedOnCurrentMembership,
        );

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
              trailing: _buildStatusChip(isDeceased ? 'DECEASED' : dependent.membershipStatus, isCompact: true),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildProfileRow(Icons.badge_outlined, 'Identity', '$displayIdType: $displayId'),
                      _buildProfileRow(Icons.cake_outlined, 'Birth Date', partner?.birthDate ?? dependent.birthDate ?? 'N/A'),
                      _buildProfileRow(Icons.person_add_alt_1_outlined, 'Date Added', _formatDependentDate(dependent.createdAt)),
                      _buildProfileRow(Icons.event_available_outlined, 'Effective Date', _formatDependentDate(dependent.effectiveFrom)),
                      if (isDeceased)
                        _buildProfileRow(Icons.event_busy_outlined, 'Deceased Date', dependent.deceasedDate ?? 'Recorded from claim'),
                      if (dependent.statusReason != null && dependent.statusReason!.isNotEmpty)
                        _buildProfileRow(Icons.info_outline, 'Status Reason', dependent.statusReason!),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!isDeceased && !_isLapsedMembership) ...[
                            TextButton.icon(
                              onPressed: () => _replaceDependent(dependent),
                              icon: const Icon(Icons.find_replace_outlined, size: 16),
                              label: const Text('REPLACE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            TextButton.icon(
                              onPressed: () => _removeDependent(dependent),
                              icon: const Icon(Icons.person_remove_outlined, size: 16),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              label: const Text('REMOVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                          if (canProcessClaim && !_isLapsedMembership)
                            TextButton(
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => MembershipClaimCreateScreen(membership: _detail!, member: _member!, dependent: dependent, deceasedPartner: partner)),
                                );
                                if (result == true) _fetchData();
                              },
                              child: const Text('PROCESS CLAIM', style: TextStyle(color: Color(0xFFF20D1A), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
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
            onTap: _isLapsedMembership ? null : () async {
              final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => MembershipClaimDetailScreen(claimId: claim.id)));
              if (result == true) _fetchData();
            },
            leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(Icons.description_outlined, color: statusColor, size: 20)),
            title: Text('Claim #${claim.claimNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${claim.claimType} • ${AppDateUtils.displayDate(claim.claimDate)}', style: const TextStyle(fontSize: 12)),
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
      child: AttachmentSection(objectId: membershipId, readOnly: _isLapsedMembership),
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
