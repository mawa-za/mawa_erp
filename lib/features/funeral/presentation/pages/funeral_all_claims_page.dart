import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../data/funeral_api.dart';
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../widgets/funeral_claim_card.dart';

class FuneralAllClaimsPage extends StatefulWidget {
  const FuneralAllClaimsPage({super.key});

  @override
  State<FuneralAllClaimsPage> createState() => _FuneralAllClaimsPageState();
}

class _FuneralAllClaimsPageState extends State<FuneralAllClaimsPage> {
  final FuneralApi _api = FuneralApi();
  final TextEditingController _searchController = TextEditingController();
  List<_FuneralClaimEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _api.getServiceRequests();
      final entries = <_FuneralClaimEntry>[];
      for (final request in requests) {
        final id = request.id;
        if (id == null || id.isEmpty) continue;
        try {
          final claims = await _api.getClaims(id);
          entries.addAll(claims.map((claim) => _FuneralClaimEntry(request, claim)));
        } catch (_) {
          // Keep the rest of the list usable when one arrangement is incomplete.
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<_FuneralClaimEntry> get _filtered {
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return _entries;
    return _entries.where((entry) {
      final claim = entry.claim;
      final request = entry.request;
      return (claim.claimNumber ?? '').toLowerCase().contains(term) ||
          claim.membershipNumber.toLowerCase().contains(term) ||
          claim.burialSocietyName.toLowerCase().contains(term) ||
          request.deceasedName.toLowerCase().contains(term) ||
          (request.serviceRequestNo ?? '').toLowerCase().contains(term);
    }).toList();
  }

  Future<void> _decide(FuneralClaimDto claim) async {
    final amountController = TextEditingController(
      text: (claim.claimedAmountCents / 100).toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final result = await showDialog<ApproveFuneralClaimRequestDto>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decide Funeral Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Claimed: ${Formatters.formatCentsAsRand(claim.claimedAmountCents)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Approved amount (Rand)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Decision note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              ApproveFuneralClaimRequestDto(
                approvedAmountCents: 0,
                status: ClaimStatus.REJECTED,
                note: noteController.text,
              ),
            ),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              final cents = ((double.tryParse(amountController.text) ?? 0) * 100).round();
              Navigator.pop(
                context,
                ApproveFuneralClaimRequestDto(
                  approvedAmountCents: cents,
                  status: cents >= claim.claimedAmountCents
                      ? ClaimStatus.APPROVED
                      : ClaimStatus.PARTIALLY_APPROVED,
                  note: noteController.text,
                ),
              );
            },
            child: const Text('Save decision'),
          ),
        ],
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (result == null) return;

    try {
      await _api.approveClaim(claim.id, result);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update claim: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/feature-groups/funeral-management');
            }
          },
        ),
        title: const Text('Funeral Claims'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search claims',
                hintText: 'Claim, membership, society or deceased name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : entries.isEmpty
                        ? const Center(child: Text('No funeral claims found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                                    child: Text(
                                      '${entry.request.serviceRequestNo ?? 'Arrangement'} • ${entry.request.deceasedName}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  FuneralClaimCard(
                                    claim: entry.claim,
                                    onApprove: () => _decide(entry.claim),
                                    onReject: () => _decide(entry.claim),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _FuneralClaimEntry {
  final FuneralServiceRequestDto request;
  final FuneralClaimDto claim;

  const _FuneralClaimEntry(this.request, this.claim);
}
