import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/membership_claim.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';

class MembershipClaimDetailScreen extends StatefulWidget {
  final String claimId;
  const MembershipClaimDetailScreen({super.key, required this.claimId});

  @override
  State<MembershipClaimDetailScreen> createState() => _MembershipClaimDetailScreenState();
}

class _MembershipClaimDetailScreenState extends State<MembershipClaimDetailScreen> {
  final MembershipService _membershipService = MembershipService();
  final PartnerService _partnerService = PartnerService();
  
  MembershipClaim? _claim;
  Partner? _deceasedPartner;
  Partner? _claimantPartner;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch claim details using the specific ID endpoint
      final claim = await _membershipService.getMembershipClaimById(widget.claimId);

      // 2. Fetch associated partners
      final results = await Future.wait([
        _partnerService.getPartnerById(claim.deceasedPartnerId).catchError((_) => null),
        _partnerService.getPartnerById(claim.claimantPartnerId).catchError((_) => null),
      ]);

      if (mounted) {
        setState(() {
          _claim = claim;
          _deceasedPartner = results[0] as Partner?;
          _claimantPartner = results[1] as Partner?;
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
      setState(() => _isLoading = true);
      try {
        await _membershipService.submitMembershipClaim(widget.claimId);
        _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claim submitted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
        }
      }
    }
  }

  Future<void> _cancelClaim() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Claim'),
        content: const Text('Are you sure you want to cancel this claim?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BACK')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('CANCEL CLAIM'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _membershipService.cancelMembershipClaim(widget.claimId);
        _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claim cancelled'), backgroundColor: Colors.grey),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancellation failed: $e')));
        }
      }
    }
  }

  Future<void> _showLinkClaimsDialog() async {
    if (_claim == null) return;

    setState(() => _isLoading = true);
    try {
      // Fetch all claims for the same membership to offer as candidates
      final allClaims = await _membershipService.getMembershipClaims(membershipId: _claim!.membershipId);
      
      // Filter out the current claim and claims that are already linked or are combination parents
      final candidates = allClaims.where((c) => 
        c.id != _claim!.id && 
        !c.linkedToCombinationClaim && 
        !c.parentCombinationClaim &&
        c.status.toUpperCase() == 'DRAFT'
      ).toList();

      if (mounted) {
        setState(() => _isLoading = false);
        if (candidates.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No eligible draft claims found to link.')),
          );
          return;
        }

        final List<String> selectedIds = [];
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Link Other Claims'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final c = candidates[index];
                    final isSelected = selectedIds.contains(c.id);
                    return CheckboxListTile(
                      title: Text('Claim #${c.claimNo}'),
                      subtitle: Text('${c.claimType} - R ${c.claimAmount.toStringAsFixed(2)}'),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedIds.add(c.id);
                          } else {
                            selectedIds.remove(c.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                FilledButton(
                  onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(context, true),
                  child: const Text('LINK SELECTED'),
                ),
              ],
            ),
          ),
        );

        if (result == true && selectedIds.isNotEmpty) {
          setState(() => _isLoading = true);
          await _membershipService.linkClaims(widget.claimId, selectedIds);
          _fetchDetails();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Claims linked successfully'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showEditDialog() async {
    if (_claim == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final dateOfDeathController = TextEditingController(text: _claim!.dateOfDeath);
    final claimDateController = TextEditingController(text: _claim!.claimDate);
    final causeOfDeathController = TextEditingController(text: _claim!.causeOfDeath ?? '');
    final deathCertController = TextEditingController(text: _claim!.deathCertificateNo ?? '');
    final amountController = TextEditingController(text: (_claim!.claimAmount).toStringAsFixed(2));
    final notesController = TextEditingController(text: _claim!.notes ?? '');
    
    DateTime selectedDateOfDeath = DateTime.tryParse(_claim!.dateOfDeath) ?? DateTime.now();
    DateTime selectedClaimDate = DateTime.tryParse(_claim!.claimDate) ?? DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Claim Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateOfDeath,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDateOfDeath = picked;
                        dateOfDeathController.text = DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: dateOfDeathController,
                      decoration: const InputDecoration(labelText: 'Date of Death', prefixIcon: Icon(Icons.calendar_today)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedClaimDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedClaimDate = picked;
                        claimDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: claimDateController,
                      decoration: const InputDecoration(labelText: 'Claim Date', prefixIcon: Icon(Icons.calendar_today)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: causeOfDeathController,
                  decoration: const InputDecoration(labelText: 'Cause of Death', prefixIcon: Icon(Icons.description_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: deathCertController,
                  decoration: const InputDecoration(labelText: 'Death Certificate No', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Claim Amount (R)', prefixIcon: Icon(Icons.payments_outlined)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final double amount = double.tryParse(amountController.text) ?? 0.0;
                final payload = {
                  "dateOfDeath": dateOfDeathController.text,
                  "claimDate": claimDateController.text,
                  "causeOfDeath": causeOfDeathController.text.trim(),
                  "deathCertificateNo": deathCertController.text.trim(),
                  "claimantPartnerId": _claim!.claimantPartnerId,
                  "claimAmountCents": (amount * 100).toInt(),
                  "notes": notesController.text.trim()
                };

                try {
                  await _membershipService.updateMembershipClaim(widget.claimId, payload);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _fetchDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_claim != null ? 'Claim #${_claim!.claimNo}' : 'Claim Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_claim != null && _claim!.status.toUpperCase() == 'DRAFT')
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _showEditDialog,
              tooltip: 'Edit Claim',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    Expanded(child: _buildContent(colorScheme)),
                    if (_claim != null && _claim!.status.toUpperCase() == 'DRAFT')
                      _buildActionButtons(colorScheme),
                  ],
                ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelClaim,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CANCEL CLAIM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _submitClaim,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SUBMIT CLAIM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY')),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final claim = _claim!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBanner(claim),
          const SizedBox(height: 24),
          _buildAmountCard(claim, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.person_outline, 'People Involved'),
          const SizedBox(height: 12),
          if (_deceasedPartner != null) _buildPartnerCard('Deceased', _deceasedPartner!, colorScheme),
          const SizedBox(height: 12),
          if (_claimantPartner != null) _buildPartnerCard('Claimant', _claimantPartner!, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.info_outline, 'Claim Details'),
          const SizedBox(height: 12),
          _buildInfoCard(claim),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.link, 'Linked Claims'),
              if (claim.status.toUpperCase() == 'DRAFT')
                TextButton.icon(
                  onPressed: _showLinkClaimsDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Link Claims'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (claim.linkedClaims.isEmpty)
             const Padding(
               padding: EdgeInsets.only(left: 8.0, bottom: 24.0),
               child: Text('No claims linked yet.', style: TextStyle(fontSize: 13, color: Colors.grey)),
             )
          else ...[
            ...claim.linkedClaims.map((lc) => _buildLinkedClaimCard(lc, colorScheme)),
            const SizedBox(height: 24),
          ],
          if (claim.notes != null && claim.notes!.isNotEmpty) ...[
            _buildSectionHeader(Icons.notes, 'Notes'),
            const SizedBox(height: 12),
            _buildNotesCard(claim.notes!),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner(MembershipClaim claim) {
    Color color;
    switch (claim.status.toUpperCase()) {
      case 'APPROVED': color = Colors.green; break;
      case 'REJECTED': color = Colors.red; break;
      case 'SUBMITTED': color = Colors.orange; break;
      case 'CANCELLED': color = Colors.grey; break;
      default: color = Colors.blue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(claim.status.toUpperCase(), 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          if (claim.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text('Reason: ${claim.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountCard(MembershipClaim claim, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Text('Total Claim Amount', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('R ${claim.claimAmount.toStringAsFixed(2)}', 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          if (claim.combinedClaimAmountCents > 0) ...[
            const SizedBox(height: 8),
            Text('Combined: R ${claim.combinedClaimAmount.toStringAsFixed(2)}', 
              style: const TextStyle(color: Colors.white60, fontSize: 14, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerCard(String role, Partner partner, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => PartnerDetailScreen(partnerId: partner.id)));
        },
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: const Icon(Icons.person, size: 20),
        ),
        title: Text(partner.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$role • No: ${partner.number}', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 16),
      ),
    );
  }

  Widget _buildInfoCard(MembershipClaim claim) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Claim Type', claim.claimType),
            const Divider(height: 24),
            _buildInfoRow('Deceased Type', claim.deceasedType),
            const Divider(height: 24),
            _buildInfoRow('Date of Death', claim.dateOfDeath),
            const Divider(height: 24),
            _buildInfoRow('Claim Date', claim.claimDate),
            if (claim.deathCertificateNo != null) ...[
              const Divider(height: 24),
              _buildInfoRow('Certificate No', claim.deathCertificateNo!),
            ],
            if (claim.causeOfDeath != null) ...[
              const Divider(height: 24),
              _buildInfoRow('Cause of Death', claim.causeOfDeath!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildLinkedClaimCard(LinkedClaim lc, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        title: Text('Claim #${lc.claimNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${lc.claimType} • ${lc.status}'),
        trailing: Text('R ${lc.claimAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Text(notes, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
      ],
    );
  }
}
