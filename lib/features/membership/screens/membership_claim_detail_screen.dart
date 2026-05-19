import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/membership_claim.dart';
import '../models/membership_detail.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import '../screens/membership_detail_screen.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';

class MembershipClaimDetailScreen extends StatefulWidget {
  final String claimId;
  const MembershipClaimDetailScreen({super.key, required this.claimId});

  @override
  State<MembershipClaimDetailScreen> createState() => _MembershipClaimDetailScreenState();
}

class _MembershipClaimDetailScreenState extends State<MembershipClaimDetailScreen> with SingleTickerProviderStateMixin {
  final MembershipService _membershipService = MembershipService();
  final PartnerService _partnerService = PartnerService();
  final ApprovalService _approvalService = ApprovalService();
  
  late TabController _tabController;
  MembershipClaim? _claim;
  Partner? _deceasedPartner;
  Partner? _claimantPartner;
  MembershipDetail? _membershipDetail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final claim = await _membershipService.getMembershipClaimById(widget.claimId);
      final results = await Future.wait([
        _partnerService.getPartnerById(claim.deceasedPartnerId).catchError((_) => null),
        _partnerService.getPartnerById(claim.claimantPartnerId).catchError((_) => null),
        if (claim.membershipId.isNotEmpty) 
          _membershipService.getMembershipDetail(claim.membershipId).catchError((_) => null)
        else Future.value(null)
      ]);

      if (mounted) {
        setState(() {
          _claim = claim;
          _deceasedPartner = results[0] as Partner?;
          _claimantPartner = results[1] as Partner?;
          if (results.length > 2) {
             _membershipDetail = results[2] as MembershipDetail?;
          }
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

  Future<void> _submitClaim() async {
    if (_claim == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Claim'),
        content: const Text('Are you sure you want to submit this claim for approval?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SUBMIT')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSubmitting = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? '';

        final submission = ApprovalSubmission(
          approvalType: 'CLAIM',
          referenceId: _claim!.id,
          referenceNo: _claim!.claimNo,
          title: 'Death Claim: ${_claim!.claimNo}',
          description: 'Claim for R ${_claim!.claimAmount.toStringAsFixed(2)} (Deceased: ${_deceasedPartner?.fullName ?? "Unknown"})',
          requesterId: userId,
          payloadJson: jsonEncode(_claim!.toJson()),
        );

        await _approvalService.submitApproval(submission);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claim submitted for approval successfully'), backgroundColor: Colors.green),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_claim != null ? 'Claim #${_claim!.claimNo}' : 'Claim Details'),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
          if (_claim != null && _claim!.status.toUpperCase() == 'DRAFT')
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditDialog()),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Details'), Tab(text: 'Attachments')],
          labelColor: colorScheme.primary, unselectedLabelColor: Colors.grey,
        ),
      ),
      body: (_isLoading || _isSubmitting) ? const Center(child: CircularProgressIndicator()) : _error != null ? _buildErrorWidget() : TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(colorScheme),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16), 
            child: AttachmentSection(
              objectId: widget.claimId,
              documentTypeField: 'DOCUMENT-TYPE-CLAIM',
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(colorScheme),
    );
  }

  Widget? _buildBottomActions(ColorScheme colorScheme) {
    if (_claim == null || _claim!.status.toUpperCase() != 'DRAFT') return null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: () => _cancelClaim(), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('CANCEL'))),
          const SizedBox(width: 16),
          Expanded(child: FilledButton(onPressed: _submitClaim, child: const Text('SUBMIT CLAIM'))),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(ColorScheme colorScheme) {
    final claim = _claim!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(claim),
          const SizedBox(height: 20),
          _buildAmountCard(claim, colorScheme),
          
          if (_membershipDetail != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.card_membership_outlined, 'Membership details'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => MembershipDetailScreen(membershipId: _membershipDetail!.id))),
                  child: const Text('View Membership', style: TextStyle(fontSize: 12)),
                )
              ]
            ),
            const SizedBox(height: 12),
            _buildMembershipCard(_membershipDetail!, colorScheme),
          ],
          
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.person_outline, 'People Involved'),
          const SizedBox(height: 12),
          if (_deceasedPartner != null) _buildPartnerCard('Deceased', _deceasedPartner!, colorScheme),
          const SizedBox(height: 12),
          if (_claimantPartner != null) _buildPartnerCard('Claimant', _claimantPartner!, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.info_outline, 'Technical Context'),
          const SizedBox(height: 12),
          _buildInfoCard(claim),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MembershipClaim claim) {
    Color color; switch (claim.status.toUpperCase()) {
      case 'APPROVED': color = Colors.green; break;
      case 'REJECTED': color = Colors.red; break;
      case 'SUBMITTED': 
      case 'AWAITING-APPROVAL': color = Colors.orange; break;
      default: color = Colors.blue;
    }
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Center(child: Text(claim.status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1))),
    );
  }

  Widget _buildAmountCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withBlue(200)]), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text('Claim Amount', style: TextStyle(color: Colors.white70, fontSize: 13)),
        Text('R ${claim.claimAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildMembershipCard(MembershipDetail detail, ColorScheme colorScheme) {
    return Card(
      elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(detail.planId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(detail.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Membership No', detail.membershipNo),
            _buildInfoRow('Start Date', detail.startDate ?? 'N/A'),
            _buildInfoRow('Join Date', detail.joinDate ?? 'N/A'),
            _buildInfoRow('Paid Up To', detail.paidUpToPeriod ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerCard(String role, Partner partner, ColorScheme colorScheme) {
    return Card(
      elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: partner.id))),
        leading: CircleAvatar(backgroundColor: colorScheme.secondaryContainer, child: const Icon(Icons.person, size: 20)),
        title: Text(partner.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$role • No: ${partner.number}'),
        trailing: const Icon(Icons.chevron_right, size: 16),
      ),
    );
  }

  Widget _buildInfoCard(MembershipClaim claim) {
    return Card(
      elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _buildInfoRow('Type', claim.claimType),
        _buildInfoRow('Death Date', claim.dateOfDeath),
        _buildInfoRow('Cert No', claim.deathCertificateNo ?? 'N/A'),
        _buildInfoRow('Cause', claim.causeOfDeath ?? 'N/A'),
      ])),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]));
  Widget _buildSectionHeader(IconData icon, String title) => Row(children: [Icon(icon, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5))]);
  Widget _buildErrorWidget() => Center(child: Text(_error ?? 'Unknown Error'));
  
  Future<void> _cancelClaim() async { 
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Claim'),
        content: const Text('Are you sure you want to cancel this draft claim?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BACK')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CANCEL CLAIM', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
       setState(() => _isSubmitting = true);
       try {
         await _membershipService.cancelMembershipClaim(widget.claimId);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim cancelled successfully')));
           _fetchDetails();
         }
       } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
       } finally {
         if (mounted) setState(() => _isSubmitting = false);
       }
    }
  }
  
  Future<void> _showEditDialog() async { /* Implementation */ }

  @override void dispose() { _tabController.dispose(); super.dispose(); }
}
