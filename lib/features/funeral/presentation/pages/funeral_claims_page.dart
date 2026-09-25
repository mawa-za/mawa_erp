import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/files/download_bytes.dart';
import '../../../../core/widgets/attachment_section.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/group_society_cover_option_dto.dart';
import '../../data/models/group_society_funeral_claim_dto.dart';
import '../../data/models/initiate_funeral_claims_request_dto.dart';
import '../widgets/funeral_claim_card.dart';

class FuneralClaimsPage extends StatefulWidget {
  final String serviceRequestId;

  const FuneralClaimsPage({super.key, required this.serviceRequestId});

  @override
  State<FuneralClaimsPage> createState() => _FuneralClaimsPageState();
}

class _FuneralClaimsPageState extends State<FuneralClaimsPage> {
  final FuneralApi _api = FuneralApi();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_ZA', symbol: 'R ');

  FuneralServiceRequestDto? _service;
  List<FuneralClaimDto> _claims = const [];
  List<GroupSocietyFuneralClaimDto> _groupClaims = const [];
  List<GroupSocietyCoverOptionDto> _groupSocieties = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = await _api.getServiceRequest(widget.serviceRequestId);
      final results = await Future.wait([
        _api.getClaims(widget.serviceRequestId),
        _api.getGroupSocietyCover(widget.serviceRequestId),
        _api.getActiveGroupSocieties(),
      ]);
      if (!mounted) return;
      setState(() {
        _service = service;
        _claims = results[0] as List<FuneralClaimDto>;
        _groupClaims = results[1] as List<GroupSocietyFuneralClaimDto>;
        _groupSocieties = results[2] as List<GroupSocietyCoverOptionDto>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _approvedMembershipCents => _claims.fold(
        0,
        (sum, claim) => sum +
            (!const {'REJECTED', 'CANCELLED'}.contains(claim.rawStatus) &&
                    claim.approvedAmountCents > 0
                ? claim.approvedAmountCents
                : 0),
      );

  int get _approvedGroupCents => _groupClaims
      .where((claim) => claim.isApproved)
      .fold(0, (sum, claim) => sum + claim.approvedCoverCents);

  int get _approvedFundingCents {
    final approved = _approvedMembershipCents + _approvedGroupCents;
    final total = _service?.totalAmountCents ?? 0;
    return approved.clamp(0, total).toInt();
  }

  int get _outstandingCents => ((_service?.totalAmountCents ?? 0) -
          _approvedFundingCents)
      .clamp(0, 1 << 62)
      .toInt();

  bool get _canAddFunding =>
      _service?.status?.toUpperCase() != 'CANCELLED';

  Future<void> _addFuneralCover() async {
    final service = _service;
    if (service == null) return;

    final searchController =
        TextEditingController(text: service.deceasedIdentityNumber);
    var searchByMembership = false;
    var searching = false;
    var covers = <FuneralMembershipCoverDto>[];
    final selected = <String>{};
    String? dialogError;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            final term = searchController.text.trim();
            if (term.isEmpty) {
              setDialogState(() => dialogError = searchByMembership
                  ? 'Enter a membership number.'
                  : 'Enter the deceased identity number.');
              return;
            }
            setDialogState(() {
              searching = true;
              dialogError = null;
              covers = [];
              selected.clear();
            });
            try {
              final result = searchByMembership
                  ? await _api.checkMembershipNumber(
                      term, service.deceasedCategory)
                  : await _api.checkMembership(term);
              setDialogState(() {
                covers = result;
                if (result.isEmpty) {
                  dialogError = 'No eligible funeral cover was found.';
                }
              });
            } catch (error) {
              setDialogState(
                  () => dialogError = friendlyErrorMessage(error));
            } finally {
              setDialogState(() => searching = false);
            }
          }

          return AlertDialog(
            title: const Text('Add Funeral Cover'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Funding can be added even after the funeral service has been invoiced.',
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Identity Number'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Membership Number'),
                          icon: Icon(Icons.card_membership_outlined),
                        ),
                      ],
                      selected: {searchByMembership},
                      onSelectionChanged: (values) {
                        setDialogState(() {
                          searchByMembership = values.first;
                          searchController.clear();
                          covers = [];
                          selected.clear();
                          dialogError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: searchByMembership
                                  ? 'Membership Number'
                                  : 'Deceased Identity Number',
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => search(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: searching ? null : search,
                          icon: searching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                      ],
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (covers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Select cover',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...covers.map((cover) {
                        final key = cover.sourceReference ??
                            cover.membershipId ??
                            '';
                        final amount = cover.funeralAmountCents > 0
                            ? cover.funeralAmountCents
                            : cover.coverAmountCents;
                        return CheckboxListTile(
                          value: selected.contains(key),
                          onChanged: key.isEmpty
                              ? null
                              : (value) => setDialogState(() {
                                    if (value == true) {
                                      selected.add(key);
                                    } else {
                                      selected.remove(key);
                                    }
                                  }),
                          title: Text(
                            '${cover.membershipNumber} • ${cover.burialSocietyName}',
                          ),
                          subtitle: Text(
                            '${cover.coverSource.name.replaceAll('_', ' ')} • ${_currency.format(amount / 100)}',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Create Claim'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCreate != true || selected.isEmpty) return;
    try {
      await _api.initiateClaimsAndReturn(
        widget.serviceRequestId,
        InitiateFuneralClaimsRequestDto(
          membershipIds: selected.toList(),
          sourceReferences: selected.toList(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Funeral cover claim created. Complete the documentation and submit it for approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addGroupSocietyFunding() async {
    final service = _service;
    if (service == null) return;
    if (_groupClaims.any((claim) =>
        const {'DRAFT', 'PENDING_APPROVAL', 'APPROVED'}
            .contains(claim.status.toUpperCase()))) {
      _showError('This funeral already has an active group society funding request.');
      return;
    }
    if (_groupSocieties.isEmpty) {
      _showError('No active group societies are available.');
      return;
    }

    final nameParts = service.deceasedName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final surname = nameParts.length > 1 ? nameParts.removeLast() : '';
    final firstNames = nameParts.isEmpty ? service.deceasedName : nameParts.join(' ');

    String? societyId = _groupSocieties.first.id;
    var identityType = service.deceasedIdentityNumber.trim().isEmpty
        ? 'OTHER'
        : 'SA-ID';
    final firstNamesController = TextEditingController(text: firstNames);
    final surnameController = TextEditingController(text: surname);
    final identityController =
        TextEditingController(text: service.deceasedIdentityNumber);
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String? dialogError;

    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedSociety = _groupSocieties
              .where((item) => item.id == societyId)
              .firstOrNull;
          return AlertDialog(
            title: const Text('Add Group Society Funding'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: societyId,
                      decoration: const InputDecoration(
                        labelText: 'Group Society',
                        border: OutlineInputBorder(),
                      ),
                      items: _groupSocieties
                          .map((society) => DropdownMenuItem(
                                value: society.id,
                                child: Text(
                                  '${society.groupNo} • ${society.name} (${_currency.format(society.availableBalanceCents / 100)})',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => societyId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNamesController,
                      decoration: const InputDecoration(
                        labelText: 'Deceased First Names',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: surnameController,
                      decoration: const InputDecoration(
                        labelText: 'Deceased Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: identityType,
                      decoration: const InputDecoration(
                        labelText: 'Identity Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['SA-ID', 'PASSPORT', 'OTHER']
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(
                          () => identityType = value ?? 'OTHER'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: identityController,
                      decoration: const InputDecoration(
                        labelText: 'Identity / Reference Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Requested Cover Amount (R)',
                        helperText: selectedSociety == null
                            ? null
                            : 'Available: ${_currency.format(selectedSociety.availableBalanceCents / 100)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dialogError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(
                      amountController.text.replaceAll(',', '').trim());
                  final amountCents = amount == null ? 0 : (amount * 100).round();
                  final selected = _groupSocieties
                      .where((item) => item.id == societyId)
                      .firstOrNull;
                  if (societyId == null ||
                      firstNamesController.text.trim().isEmpty ||
                      surnameController.text.trim().isEmpty ||
                      identityController.text.trim().isEmpty ||
                      amountCents <= 0) {
                    setDialogState(() => dialogError =
                        'Complete the society, deceased details and requested amount.');
                    return;
                  }
                  if (selected != null &&
                      amountCents > selected.availableBalanceCents) {
                    setDialogState(() => dialogError =
                        'The requested amount exceeds the available group society balance.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Create Draft'),
              ),
            ],
          );
        },
      ),
    );

    if (create != true || societyId == null) return;
    final amount = double.tryParse(
            amountController.text.replaceAll(',', '').trim()) ??
        0;
    try {
      await _api.submitGroupSocietyCover(widget.serviceRequestId, {
        'groupSocietyId': societyId,
        'deceasedFirstNames': firstNamesController.text.trim(),
        'deceasedLastName': surnameController.text.trim(),
        'identityType': identityType,
        'identityNumber': identityController.text.trim(),
        'requestedCoverCents': (amount * 100).round(),
        'notes': notesController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Group society funding draft created. Supporting documentation is required before submission.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _submitMembershipClaim(FuneralClaimDto claim) async {
    try {
      await _api.submitClaimForApproval(claim.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim submitted for approval.')),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _submitGroupClaim(GroupSocietyFuneralClaimDto claim) async {
    try {
      await _api.submitGroupSocietyCoverForApproval(
        widget.serviceRequestId,
        claim.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group society claim submitted for approval.')),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _downloadClaimForm(FuneralClaimDto claim) async {
    try {
      final bytes = await _api.downloadClaimForm(claim.id);
      await downloadBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: 'claim-form-${claim.claimNumber ?? claim.id}.pdf',
        mimeType: 'application/pdf',
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyErrorMessage(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Funding & Claims'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 16),
                      _buildFundingActions(),
                      const SizedBox(height: 24),
                      _buildMembershipClaims(),
                      const SizedBox(height: 24),
                      _buildGroupSocietyClaims(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary() {
    final service = _service!;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.serviceRequestNo ?? 'Funeral Service',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text((service.status ?? 'DRAFT').replaceAll('_', ' '))),
              ],
            ),
            const SizedBox(height: 6),
            Text(service.deceasedName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _amountTile('Service Total', service.totalAmountCents),
                _amountTile('Approved Funding', _approvedFundingCents),
                _amountTile('Family / Outstanding', _outstandingCents),
              ],
            ),
            if ((service.status ?? '').toUpperCase() == 'INVOICED') ...[
              const SizedBox(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This service is already invoiced. Approved late funding will automatically reconcile the family invoice; financially active invoices are preserved using credit notes.',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amountTile(String label, int cents) => Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              _currency.format(cents / 100),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
      );

  Widget _buildFundingActions() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Funding', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Funding is independent from the funeral arrangement and can be added before or after invoicing.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _canAddFunding ? _addFuneralCover : null,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Add Funeral Cover'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _canAddFunding ? _addGroupSocietyFunding : null,
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('Add Group Society Funding'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipClaims() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Funeral Cover Claims',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (_claims.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No funeral cover claims have been created.'),
            ),
          )
        else
          ..._claims.map((claim) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FuneralClaimCard(claim: claim),
                      if (claim.rawStatus == 'DRAFT') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Claim Documentation',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        AttachmentSection(
                          objectId: claim.id,
                          documentTypeField: 'DOCUMENT-TYPE-CLAIM',
                          allowDelete: true,
                          protectedDocumentTypes: const {'CLAIM-FORM'},
                          hiddenDocumentTypes: const {'CLAIM-FORM'},
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _downloadClaimForm(claim),
                              icon: Icon(claim.claimFormPrinted
                                  ? Icons.check_circle_outline
                                  : Icons.download_outlined),
                              label: Text(claim.claimFormPrinted
                                  ? 'Claim Form Downloaded'
                                  : 'Download Claim Form'),
                            ),
                            FilledButton.icon(
                              onPressed: () => _submitMembershipClaim(claim),
                              icon: const Icon(Icons.approval_outlined),
                              label: const Text('Submit for Approval'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildGroupSocietyClaims() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group Society Funding',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (_groupClaims.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No group society funding has been created.'),
            ),
          )
        else
          ..._groupClaims.map((claim) {
            final status = claim.status.toUpperCase();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.groups_2_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                claim.societyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                              Text('${claim.groupNo} • ${claim.claimNo}'),
                            ],
                          ),
                        ),
                        Chip(label: Text(status.replaceAll('_', ' '))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Requested: ${_currency.format(claim.requestedCoverCents / 100)}'
                      '${claim.approvedCoverCents > 0 ? ' • Approved: ${_currency.format(claim.approvedCoverCents / 100)}' : ''}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deceased: ${claim.deceasedFirstNames} ${claim.deceasedLastName} • ${claim.identityType}: ${claim.identityNumber}',
                    ),
                    if (claim.isDraft) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Supporting Documentation',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'At least one supporting document is required before this claim can be submitted.',
                      ),
                      const SizedBox(height: 8),
                      AttachmentSection(
                        objectId: claim.id,
                        documentTypeField:
                            'DOCUMENT-TYPE-GROUP-SOCIETY-FUNERAL-CLAIM',
                        allowDelete: true,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _submitGroupClaim(claim),
                          icon: const Icon(Icons.approval_outlined),
                          label: const Text('Submit for Approval'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
