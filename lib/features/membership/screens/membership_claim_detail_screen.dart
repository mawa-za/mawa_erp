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
import '../../../core/api_client.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import '../../payments/screens/payment_request_detail_screen.dart';
import '../../tombstones/screens/tombstone_order_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
  final ApiClient _api = ApiClient();

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
          _error = friendlyErrorMessage(e);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          title: 'Death claim ${_claim!.claimNo} - ${_deceasedPartner?.fullName ?? "Deceased not identified"}',
          description: 'Claim for R ${_claim!.claimAmount.toStringAsFixed(2)} (Deceased: ${_deceasedPartner?.fullName ?? "Unknown"})',
          requesterId: userId,
          payloadJson: jsonEncode(_claim!.toJson()),
        );

        await _approvalService.submitApproval(submission);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Claim submitted for approval successfully'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _fetchDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                friendlyErrorMessage(
                  e,
                  fallback: 'The claim could not be submitted. Review the claim and try again.',
                ),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_claim == null || _claim!.claimNo.isEmpty ? 'Membership Claim' : 'Membership Claim ${_claim!.claimNo}'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchDetails),
          if (_claim != null && _claim!.status.toUpperCase() == 'DRAFT')
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditDialog()),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'OVERVIEW'), Tab(text: 'ATTACHMENTS')],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: (_isLoading || _isSubmitting)
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(colorScheme),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildAttachmentContainer(),
                    ),
                  ],
                ),
      bottomNavigationBar: _buildBottomActions(colorScheme),
    );
  }

  Widget? _buildBottomActions(ColorScheme colorScheme) {
    if (_claim == null || _claim!.status.toUpperCase() != 'DRAFT') return null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _cancelClaim(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('CANCEL DRAFT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _submitClaim,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('SUBMIT FOR APPROVAL', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(ColorScheme colorScheme) {
    final claim = _claim!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(claim, colorScheme),
          const SizedBox(height: 24),
          _buildAmountCard(claim, colorScheme),
          const SizedBox(height: 20),
          _buildSigniFlowCard(claim, colorScheme),
          if (claim.claimType.toUpperCase() == 'CASH' &&
              (claim.paymentRequestId?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 20),
            _buildDisbursementCard(claim, colorScheme),
          ],
          if ((claim.claimType.toUpperCase() == 'TOMBSTONE' || claim.claimType.toUpperCase() == 'COMBINATION') &&
              (claim.tombstoneOrderId?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 20),
            _buildTombstoneSettlementCard(claim, colorScheme),
          ],

          if (_membershipDetail != null) ...[
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.card_membership_outlined, 'LINKED MEMBERSHIP'),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => MembershipDetailScreen(membershipId: _membershipDetail!.id))),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('VIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ]
            ),
            const SizedBox(height: 12),
            _buildMembershipCard(_membershipDetail!, claim, colorScheme),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader(Icons.people_outline, 'PEOPLE INVOLVED'),
          const SizedBox(height: 12),
          _buildClaimPersonReferenceCard(
            role: 'Membership Holder',
            name: claim.memberName,
            partnerNumber: claim.memberNumber,
            identityNumber: claim.memberIdentityNumber,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          if (_deceasedPartner != null)
            _buildPartnerCard(
              'Deceased Person',
              _deceasedPartner!,
              colorScheme,
              isDeceased: true,
            )
          else
            _buildClaimPersonReferenceCard(
              role: 'Deceased Person',
              name: claim.deceasedName,
              partnerNumber: claim.deceasedNumber,
              identityNumber: claim.deceasedIdentityNumber,
              colorScheme: colorScheme,
              isDeceased: true,
            ),
          if (_claimantPartner != null) ...[
            const SizedBox(height: 12),
            _buildPartnerCard('Claimant (Beneficiary)', _claimantPartner!, colorScheme),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader(Icons.info_outline, 'CLAIM SPECIFICATIONS'),
          const SizedBox(height: 12),
          _buildInfoCard(claim, colorScheme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MembershipClaim claim, ColorScheme colorScheme) {
    Color color;
    switch (claim.status.toUpperCase()) {
      case 'APPROVED': color = Colors.green; break;
      case 'PAYMENT_PENDING': color = Colors.orange; break;
      case 'PAYMENT_PROCESSING': color = Colors.blue; break;
      case 'PAYMENT_FAILED':
      case 'REJECTED': color = Colors.red; break;
      case 'SUBMITTED':
      case 'AWAITING-APPROVAL': color = Colors.orange; break;
      case 'PAID': color = Colors.teal; break;
      default: color = colorScheme.primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.info_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                Text(
                  claim.status.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Text(
            '#${claim.claimNo}',
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDisbursementCard(MembershipClaim claim, ColorScheme colorScheme) {
    final status = claim.status.toUpperCase();
    final message = switch (status) {
      'PAYMENT_PENDING' => 'The claim is approved and the payment instruction is queued for processing.',
      'PAYMENT_PROCESSING' => 'FNB accepted the payment instruction. Bank confirmation is being monitored.',
      'PAYMENT_FAILED' => 'The bank could not complete the payment. Review the linked payment request before retrying.',
      'PAID' => 'The bank confirmed that the claim payment was completed.',
      _ => 'A payment request was created from the approved claim.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_outlined, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CLAIM DISBURSEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(message),
                const SizedBox(height: 8),
                Text(
                  'A linked payment request is available for review.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentRequestDetailScreen(paymentId: claim.paymentRequestId!),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('VIEW PAYMENT REQUEST'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTombstoneSettlementCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_outlined, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOMBSTONE BENEFIT SETTLEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                const Text('The approved funeral-cover benefit was settled internally against a tombstone order. No cash payment is sent to the family for this allocation.'),
                const SizedBox(height: 8),
                Text('A linked tombstone order is available for review.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                if (claim.settledAt?.isNotEmpty ?? false)
                  Text('Settled: ${claim.settledAt}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TombstoneOrderDetailScreen(orderId: claim.tombstoneOrderId!),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('VIEW TOMBSTONE ORDER'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withBlue(150)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.white54, size: 24),
          const SizedBox(height: 12),
          const Text('APPROVED PAYOUT AMOUNT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            'R ${claim.claimAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildSigniFlowCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Icon(Icons.draw_outlined, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SigniFlow electronic signature',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Generate the claim form, send it for signature and retrieve the signed copy.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openSigniFlow,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSigniFlow() async {
    setState(() => _isSubmitting = true);
    try {
      final responses = await Future.wait([
        _api.get('/v2/membership-claim/${widget.claimId}/signiflow/signer-options'),
        _api.get('/v2/membership-claim/${widget.claimId}/signiflow'),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw AppException(responses.firstWhere((response) => response.statusCode != 200).body);
      }
      final signers = (jsonDecode(responses[0].body) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final workflows = (jsonDecode(responses[1].body) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (!mounted) return;
      await _showSigniFlowDialog(signers, workflows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Unable to open SigniFlow: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSigniFlowDialog(
    List<Map<String, dynamic>> initialSigners,
    List<Map<String, dynamic>> initialWorkflows,
  ) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    String? selectedPartnerId;
    var workflows = List<Map<String, dynamic>>.from(initialWorkflows);
    bool busy = false;

    void applySigner(Map<String, dynamic>? signer) {
      selectedPartnerId = signer?['partnerId']?.toString();
      name.text = signer?['name']?.toString() ?? '';
      email.text = signer?['email']?.toString() ?? '';
    }

    if (initialSigners.isNotEmpty) {
      final preferred = initialSigners.firstWhere(
        (row) => (row['relationship'] ?? '').toString() == 'CLAIMANT',
        orElse: () => initialSigners.first,
      );
      applySigner(preferred);
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> reloadWorkflows() async {
            final response = await _api.get(
              '/v2/membership-claim/${widget.claimId}/signiflow',
            );
            if (response.statusCode != 200) throw AppException(response.body);
            setDialogState(() {
              workflows = (jsonDecode(response.body) as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList();
            });
          }

          Future<void> runWorkflowAction(String workflowId, String action) async {
            setDialogState(() => busy = true);
            try {
              final response = await _api.post(
                '/v2/signiflow/workflows/$workflowId/$action',
              );
              if (response.statusCode != 200) throw AppException(response.body);
              await reloadWorkflows();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(action == 'download-signed'
                        ? 'Signed claim form saved to attachments.'
                        : 'Signature status refreshed.'),
                  ),
                );
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage('SigniFlow action failed: $error'))),
                );
              }
            } finally {
              setDialogState(() => busy = false);
            }
          }

          Future<void> send() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() => busy = true);
            try {
              final response = await _api.post(
                '/v2/membership-claim/${widget.claimId}/signiflow/send',
                body: {
                  'signerPartnerId': selectedPartnerId,
                  'signerName': name.text.trim(),
                  'signerEmail': email.text.trim(),
                },
              );
              if (response.statusCode != 200) throw AppException(response.body);
              await reloadWorkflows();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Claim form sent to SigniFlow.')),
                );
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage('Unable to send claim form: $error'))),
                );
              }
            } finally {
              setDialogState(() => busy = false);
            }
          }

          return AlertDialog(
            title: const Text('SigniFlow claim form signature'),
            content: SizedBox(
              width: 720,
              height: 620,
              child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Select the person who must sign. Existing partner email details are used where available and can be corrected before sending.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPartnerId,
                      decoration: const InputDecoration(
                        labelText: 'Signer',
                        border: OutlineInputBorder(),
                      ),
                      items: initialSigners
                          .map((signer) => DropdownMenuItem(
                                value: signer['partnerId']?.toString(),
                                child: Text(
                                  '${signer['name'] ?? ''} (${signer['relationship'] ?? ''})',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        final signer = initialSigners.cast<Map<String, dynamic>?>().firstWhere(
                              (row) => row?['partnerId']?.toString() == value,
                              orElse: () => null,
                            );
                        setDialogState(() => applySigner(signer));
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Signer full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Signer name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Signer email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Signer email address is required';
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : send,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Generate and send claim form'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Signature workflows',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (workflows.isEmpty)
                      const Text('No claim form has been sent for signature yet.')
                    else
                      ...workflows.map(
                        (workflow) => Card(
                          child: ListTile(
                            title: Text(workflow['signer_name']?.toString() ?? ''),
                            subtitle: Text(
                              '${workflow['signer_email'] ?? ''}\nStatus: ${workflow['status'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              enabled: !busy,
                              onSelected: (action) => runWorkflowAction(
                                workflow['id'].toString(),
                                action,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'refresh',
                                  child: Text('Refresh status'),
                                ),
                                PopupMenuItem(
                                  value: 'download-signed',
                                  child: Text('Retrieve signed form'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    email.dispose();
  }

  Widget _buildMembershipCard(MembershipDetail detail, MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Coverage Plan',
            claim.coveragePlanName.isNotEmpty ? claim.coveragePlanName : 'Not available',
            icon: Icons.shield_outlined,
          ),
          const Divider(height: 32),
          _buildInfoRow('Membership No', detail.membershipNo, icon: Icons.numbers_rounded),
          const Divider(height: 32),
          _buildInfoRow('Policy Status', detail.status.toUpperCase(), icon: Icons.toggle_on_outlined, valueColor: detail.status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange),
        ],
      ),
    );
  }

  Widget _buildClaimPersonReferenceCard({
    required String role,
    required String name,
    required String partnerNumber,
    required String identityNumber,
    required ColorScheme colorScheme,
    bool isDeceased = false,
  }) {
    final themeColor = isDeceased ? Colors.purple : colorScheme.primary;
    final references = <String>[
      if (identityNumber.trim().isNotEmpty)
        'ID / Registration: ${identityNumber.trim()}',
      if (partnerNumber.trim().isNotEmpty)
        'Partner No: ${partnerNumber.trim()}',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(Icons.person_outline, color: themeColor, size: 20),
        ),
        title: Text(
          name.trim().isEmpty ? 'Not available' : name.trim(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          [role, ...references].join(' • '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(String role, Partner partner, ColorScheme colorScheme, {bool isDeceased = false}) {
    final themeColor = isDeceased ? Colors.purple : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: partner.id, isMemberContext: true)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(Icons.person_outline, color: themeColor, size: 20),
        ),
        title: Text(
          partner.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          [
            role,
            if (partner.number.isNotEmpty) 'Partner No: ${partner.number}',
            if (partner.identityNumber.isNotEmpty) '${partner.idType?.isNotEmpty == true ? partner.idType : 'ID / Registration'}: ${partner.identityNumber}',
          ].join(' • '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfoCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow('Claim Type', claim.claimType, icon: Icons.category_outlined),
          const Divider(height: 32),
          _buildInfoRow('Date of Death', claim.dateOfDeath, icon: Icons.calendar_today_rounded),
          if (claim.coveragePlanName.isNotEmpty) ...[
            const Divider(height: 32),
            _buildInfoRow('Coverage Plan', claim.coveragePlanName, icon: Icons.shield_outlined),
            const Divider(height: 32),
            _buildInfoRow('Coverage Effective Date', claim.coverageEventDate, icon: Icons.event_available_outlined),
          ],
          const Divider(height: 32),
          _buildInfoRow('Certificate No', claim.deathCertificateNo ?? 'N/A', icon: Icons.badge_outlined),
          const Divider(height: 32),
          _buildInfoRow('Cause of Death', claim.causeOfDeath ?? 'N/A', icon: Icons.description_outlined, isMultiLine: true),
          if (claim.notes != null && claim.notes!.isNotEmpty) ...[
            const Divider(height: 32),
            _buildInfoRow('Internal Notes', claim.notes!, icon: Icons.notes_rounded, isMultiLine: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? valueColor, bool isMultiLine = false}) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
        ],
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor ?? Colors.black87),
          ),
        ),
      ],
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

  Widget _buildAttachmentContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: AttachmentSection(
        objectId: widget.claimId,
        documentTypeField: 'DOCUMENT-TYPE-CLAIM',
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
            Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            const Text('Oops! Something went wrong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown Error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelClaim() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Claim'),
        content: const Text('Are you sure you want to cancel this draft claim? This action is permanent.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GO BACK')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CANCEL CLAIM'),
          ),
        ],
      ),
    );
    if (confirm == true) {
       setState(() => _isSubmitting = true);
       try {
         await _membershipService.cancelMembershipClaim(widget.claimId);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('Claim cancelled successfully'),
               backgroundColor: Colors.green[700],
               behavior: SnackBarBehavior.floating,
             )
           );
           _fetchDetails();
         }
       } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red));
       } finally {
         if (mounted) setState(() => _isSubmitting = false);
       }
    }
  }

  Future<void> _showEditDialog() async {
    // Navigate to create screen with existing data or implement a dialog
    // For now, let's just show a notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon...'), behavior: SnackBarBehavior.floating),
    );
  }

  @override void dispose() { _tabController.dispose(); super.dispose(); }
}
