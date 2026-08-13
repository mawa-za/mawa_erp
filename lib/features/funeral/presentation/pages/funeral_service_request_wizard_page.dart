import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mawa_erp/core/errors/app_error.dart';
import '../controllers/funeral_service_request_wizard_controller.dart';
import '../widgets/funeral_wizard_stepper.dart';
import '../widgets/funeral_package_card.dart';
import '../widgets/membership_cover_selection_card.dart';
import '../widgets/invoice_preview_summary_card.dart';
import '../widgets/funeral_money_text.dart';
import '../widgets/funeral_status_chip.dart';
import '../../../../core/files/download_bytes.dart';
import '../../../../core/widgets/attachment_section.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/mawa_design.dart';
import '../../../../core/widgets/mawa_ui.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/models/product_lookup.dart';
import '../../../invoicing/screens/invoice_detail_screen.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class FuneralServiceRequestWizardPage extends StatefulWidget {
  const FuneralServiceRequestWizardPage({super.key, this.serviceRequestId});

  final String? serviceRequestId;

  @override
  State<FuneralServiceRequestWizardPage> createState() => _FuneralServiceRequestWizardPageState();
}

class _FuneralServiceRequestWizardPageState extends State<FuneralServiceRequestWizardPage> {
  late final FuneralServiceRequestWizardController _controller;
  final _idNumberController = TextEditingController();
  final _familyNamesController = TextEditingController();
  final _familySurnameController = TextEditingController();
  final _familyContactController = TextEditingController();
  final _deathCertificateController = TextEditingController();
  final _deliveryDirectionsController = TextEditingController();

  final List<String> _stepTitles = [
    'Deceased', 'Cover', 'Representative', 'Package', 'Claims', 'Preview', 'Generate'
  ];

  List<String> get _visibleStepTitles => _stepTitles;

  int get _visibleCurrentStep => _controller.currentStep;

  @override
  void initState() {
    super.initState();
    _controller = FuneralServiceRequestWizardController();
    _controller.loadInitialData(resumeServiceRequestId: widget.serviceRequestId);
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_idNumberController.text != _controller.deceasedIdentityNumber) {
      _idNumberController.text = _controller.deceasedIdentityNumber;
    }
    if (_deliveryDirectionsController.text != _controller.deceasedDeliveryDirections) {
      _deliveryDirectionsController.text = _controller.deceasedDeliveryDirections;
    }
    if (_familyNamesController.text != _controller.familyRepresentativeNames) {
      _familyNamesController.text = _controller.familyRepresentativeNames;
    }
    if (_familySurnameController.text != _controller.familyRepresentativeSurname) {
      _familySurnameController.text = _controller.familyRepresentativeSurname;
    }
    if (_familyContactController.text != _controller.familyRepresentativeContactDetails) {
      _familyContactController.text = _controller.familyRepresentativeContactDetails;
    }
    if (_deathCertificateController.text != _controller.deathCertificateNo) {
      _deathCertificateController.text = _controller.deathCertificateNo;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _idNumberController.dispose();
    _familyNamesController.dispose();
    _familySurnameController.dispose();
    _familyContactController.dispose();
    _deathCertificateController.dispose();
    _deliveryDirectionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MawaDesign.page,
          appBar: AppBar(
            title: const Text('Funeral Arrangement Wizard'),
            leading: IconButton(
              tooltip: 'Close wizard',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => context.pop(),
            ),
          ),
          body: Column(
            children: [
              FuneralWizardStepper(
                currentStep: _visibleCurrentStep,
                steps: _visibleStepTitles,
              ),
              if (_controller.errorMessage != null)
                Container(
                  width: double.infinity,
                  color: MawaDesign.redSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: MawaDesign.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(
                            color: MawaDesign.redDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: MawaDesign.red,
                        onPressed: () => setState(
                          () => _controller.errorMessage = null,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 1440
                        ? 1440.0
                        : constraints.maxWidth;
                    return Center(
                      child: SizedBox(
                        width: width,
                        height: constraints.maxHeight,
                        child: _controller.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildStepContent(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(),
        );
      },
    );
  }

  Widget _buildStepContent() {
    switch (_controller.currentStep) {
      case 0:
        return _buildDeceasedStep();
      case 1:
        return _buildCoverStep();
      case 2:
        return _buildFamilyRepStep();
      case 3:
        return _buildPackageStep();
      case 4:
        return _buildClaimsStep();
      case 5:
        return _buildPreviewStep();
      case 6:
        return _buildGenerateStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDeceasedStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select Deceased from Mortuary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_controller.inventory.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No deceased in inventory.'))),
        ..._controller.inventory.map((item) => RadioListTile<String>(
              value: item.id,
              groupValue: _controller.selectedDeceased?.id,
              title: Text(item.deceasedName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tag: ${item.tagNumber ?? "N/A"} • In: ${Formatters.formatFriendlyDate(item.checkInDate)}'),
              onChanged: (val) {
                if (val != null) {
                  _controller.selectDeceased(_controller.inventory.firstWhere((i) => i.id == val));
                }
              },
            )),
        const SizedBox(height: 24),
        TextFormField(
          controller: _idNumberController,
          decoration: const InputDecoration(
            labelText: 'Deceased Identity Number',
            border: OutlineInputBorder(),
            helperText: 'Required for membership cover check',
          ),
          onChanged: (val) {
            _controller.deceasedIdentityNumber = val;
            if (_controller.groupSocietyClaims.isEmpty) {
              _controller.groupSocietyIdentityNumber = val;
            }
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: _controller.dateOfDeath ?? now,
              firstDate: DateTime(now.year - 120),
              lastDate: now,
            );
            if (date != null) {
              setState(() => _controller.dateOfDeath = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Death *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _controller.dateOfDeath == null
                  ? 'Select date of death'
                  : Formatters.formatDate(_controller.dateOfDeath!),
              style: TextStyle(
                color: _controller.dateOfDeath == null
                    ? Theme.of(context).hintColor
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SearchableDropdownFormField<String>(
          value: _controller.causeOfDeath,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Cause of Death',
            border: OutlineInputBorder(),
          ),
          items: _controller.causeOfDeathOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option.description,
                    child: Text(option.description),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _controller.causeOfDeath = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deathCertificateController,
          decoration: const InputDecoration(
            labelText: 'Death Certificate Number',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _controller.deathCertificateNo = value,
        ),
      ],
    );
  }

  Widget _buildFamilyRepStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Family Representative Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _familyNamesController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Names *',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _controller.familyRepresentativeNames = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _familySurnameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Surname *',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _controller.familyRepresentativeSurname = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _familyContactController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Contact Details *',
            hintText: 'Cellphone, alternate contact, email or other contact details',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _controller.familyRepresentativeContactDetails = value,
        ),
        const Divider(height: 48),
        const Text('Funeral Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Funeral Date'),
          subtitle: Text(Formatters.formatDate(_controller.funeralDate)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _controller.funeralDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _controller.funeralDate = date);
            }
          },
        ),
        const SizedBox(height: 8),
        SearchableDropdownFormField<String>(
          value: _controller.funeralLocation.isEmpty ? null : _controller.funeralLocation,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Funeral Location / Area',
            border: OutlineInputBorder(),
          ),
          items: _controller.salesAreaOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option.description,
                    child: Text(option.description),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _controller.funeralLocation = value ?? ''),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deliveryDirectionsController,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Directions to Deceased Delivery Location',
            hintText: 'Type clear directions, landmarks, gate details, village/section, or turn-by-turn instructions.',
            helperText: 'These directions will appear on the Funeral Service Request Form.',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _controller.deceasedDeliveryDirections = value,
        ),
      ],
    );
  }

  Widget _buildPackageStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final mainContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MawaSectionHeader(
              title: 'Select funeral package',
              description:
                  'Choose the package that best suits the family’s needs and add any additional products.',
            ),
            const SizedBox(height: 16),
            if (_controller.packages.isEmpty)
              const MawaEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No funeral packages available',
                description:
                    'Configure an active funeral package before continuing with the arrangement.',
              )
            else
              ..._controller.packages.map(
                (package) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FuneralPackageCard(
                    package: package,
                    isSelected:
                        _controller.effectiveSelectedPackage?.id == package.id,
                    onTap: () => _controller.selectPackage(package),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            MawaSurface(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MawaSectionHeader(
                    title: 'Extras',
                    description:
                        'Add optional products to personalise the funeral arrangement.',
                    trailing: TextButton.icon(
                      onPressed: _showAddExtraDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add extra'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_controller.extras.isEmpty)
                    const MawaEmptyState(
                      icon: Icons.add_shopping_cart_outlined,
                      title: 'No extras added yet',
                      description:
                          'Select “Add extra” to include additional products in this arrangement.',
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 30),
                    )
                  else
                    ..._controller.extras.map(
                      (extra) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: MawaDesign.surfaceMuted,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: MawaDesign.border),
                        ),
                        child: ListTile(
                          leading: const MawaIconBadge(
                            icon: Icons.add_box_outlined,
                            color: MawaDesign.info,
                            size: 38,
                          ),
                          title: Text(extra.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FuneralMoneyText(
                                cents: extra.amountCents,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove extra',
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: MawaDesign.red,
                                onPressed: () => setState(
                                  () => _controller.extras.remove(extra),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

        final summary = _buildCostSummary();
        return SingleChildScrollView(
          padding: MawaDesign.responsivePagePadding(constraints.maxWidth),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mainContent),
                    const SizedBox(width: 20),
                    SizedBox(width: 330, child: summary),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mainContent,
                    const SizedBox(height: 18),
                    summary,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCostSummary() {
    final theme = Theme.of(context);
    return MawaSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cost summary', style: theme.textTheme.titleLarge),
          const SizedBox(height: 18),
          _moneySummaryRow('Package', _controller.packageAmountCents),
          _moneySummaryRow('Extras', _controller.extrasTotalCents),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          _moneySummaryRow(
            'Total funeral cost',
            _controller.arrangementTotalCents,
            bold: true,
          ),
          _moneySummaryRow(
            'Funeral cover selected',
            _controller.selectedCoverTotalCents,
            bold: true,
          ),
          if (_controller.selectedCovers.length > 1)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Each selected membership contributes its Funeral benefit. A Combination benefit is only used for an explicit Combination claim.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          if (_controller.requestedGroupSocietyCoverCents > 0)
            _moneySummaryRow(
              'Group society cover requested',
              _controller.requestedGroupSocietyCoverCents,
              bold: true,
            ),
          if (_controller.requestedGroupSocietyCoverCents >
              _controller.approvedGroupSocietyCoverCents)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Pending group society cover is not deducted from the family shortfall until it is approved.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _controller.shortfallCents > 0
                  ? MawaDesign.redSoft
                  : MawaDesign.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _moneySummaryRow(
              'Family shortfall',
              _controller.shortfallCents,
              bold: true,
              colour: _controller.shortfallCents > 0
                  ? MawaDesign.redDark
                  : MawaDesign.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneySummaryRow(
    String label,
    int cents, {
    bool bold = false,
    Color? colour,
  }) {
    final style = TextStyle(
      color: colour,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          FuneralMoneyText(cents: cents, style: style),
        ],
      ),
    );
  }

  Widget _buildCoverStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MawaSectionHeader(
          title: 'Select funding cover',
          description:
              'Use one or more membership covers, a group society, or both to fund the funeral service.',
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Membership Cover',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _controller.checkMembership,
              icon: const Icon(Icons.search),
              label: const Text('Check Cover'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_controller.availableCovers.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No membership cover was found. You may still continue with group society funding or family payment.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ..._controller.availableCovers.map(
          (cover) => MembershipCoverSelectionCard(
            cover: cover,
            isSelected: _controller.selectedCovers.any(
              (selected) =>
                  (selected.membershipId ?? selected.sourceReference) ==
                  (cover.membershipId ?? cover.sourceReference),
            ),
            onTap: () => _controller.toggleCoverSelection(cover),
          ),
        ),
        if (_controller.selectedCovers.isNotEmpty) ...[
          const SizedBox(height: 12),
          SearchableDropdownFormField<String>(
            value: _controller.groceryCoverSelectionId,
            decoration: const InputDecoration(
              labelText: 'Cover to use for grocery claim',
              border: OutlineInputBorder(),
            ),
            items: _controller.selectedCovers.map((cover) {
              final id = cover.membershipId ?? cover.sourceReference ?? '';
              return DropdownMenuItem(
                value: id,
                child: Text(
                  '${cover.membershipNumber} • ${cover.burialSocietyName}',
                ),
              );
            }).toList(),
            onChanged: (value) =>
                setState(() => _controller.groceryCoverSelectionId = value),
          ),
        ],
        if (_controller.availableCovers.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Select one or more memberships to use for claim initiation.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Group Society Cover',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select an active group society and the amount it should fund. The approval request will be created when the funeral arrangement is initiated.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 14),
        _buildGroupSocietyCoverCard(),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    final serviceId = _controller.serviceRequestId;
    if (serviceId == null) {
      return const Center(child: Text('Create the funeral arrangement before uploading documents.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Claim Documentation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Upload the signed claim form and supporting documents once. They will be attached to every generated claim and the claims will then be submitted for approval.'),
        const SizedBox(height: 16),
        AttachmentSection(objectId: serviceId, documentTypeField: 'DOCUMENT-TYPE-CLAIM'),
      ],
    );
  }

  Widget _buildClaimsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Initiated Claims', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _controller.loadClaims, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        if (_controller.groupSocietyClaims.isNotEmpty) ...[
          _buildGroupSocietyCoverCard(),
          const SizedBox(height: 16),
        ],
        if (_controller.claims.isEmpty && _controller.groupSocietyClaims.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No cover claims have been initiated for this request.'))),
        ..._controller.claims.map((claim) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(claim.burialSocietyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Member: ${claim.membershipNumber}'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Claimed: '),
                              FuneralMoneyText(cents: claim.claimedAmountCents, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (claim.approvedAmountCents > 0 || claim.status == ClaimStatus.REJECTED || claim.status == ClaimStatus.PARTIALLY_APPROVED)
                            Row(
                              children: [
                                const Text('Approved: '),
                                FuneralMoneyText(cents: claim.approvedAmountCents, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                        ],
                      ),
                      trailing: FuneralStatusChip(status: claim.status),
                    ),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final bytes = await _controller.downloadClaimForm(claim.id);
                            await downloadBytes(
                              bytes: Uint8List.fromList(bytes),
                              fileName: 'claim-form-${claim.claimNumber ?? claim.id}.pdf',
                              mimeType: 'application/pdf',
                            );
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  friendlyErrorMessage(
                                    'Unable to download claim form: $error',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(claim.claimFormPrinted ? Icons.check_circle_outline : Icons.download),
                        label: Text(claim.claimFormPrinted ? 'Claim Form Downloaded' : 'Download Claim Form'),
                      ),
                      if (claim.claimFormPrinted)
                        Chip(
                          avatar: const Icon(Icons.verified_outlined, size: 16),
                          label: Text('Printed ${claim.claimFormPrintCount} time${claim.claimFormPrintCount == 1 ? '' : 's'}'),
                        ),
                    ]),
                    AttachmentSection(objectId: claim.id, documentTypeField: 'DOCUMENT-TYPE-CLAIM'),
                    if (claim.status == ClaimStatus.PENDING &&
                        !claim.managedExternally)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.approval_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                claim.rawStatus == 'DRAFT'
                                    ? 'Complete the claim documentation and continue to submit this claim to Approval Requests.'
                                    : 'This claim is awaiting a decision in the system-wide Approval Requests process.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (claim.status == ClaimStatus.PENDING &&
                        claim.managedExternally)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Approval is managed in the source membership tenant.',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )),
        if (_controller.hasPendingClaims)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Some claims are still pending. Final invoices should ideally be generated after claim approval.')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGroupSocietyCoverCard() {
    final claims = _controller.groupSocietyClaims;
    if (claims.isNotEmpty) {
      final claim = claims.first;
      final status = claim.status.toUpperCase();
      final statusColor = status == 'APPROVED'
          ? Colors.green
          : status == 'REJECTED'
              ? Colors.red
              : Colors.orange;
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: statusColor.withOpacity(.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(.12),
                    child: Icon(Icons.groups_2_outlined, color: statusColor),
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
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${claim.groupNo} • ${claim.claimNo}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _groupClaimAmount(
                      'Requested Cover',
                      claim.requestedCoverCents,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _groupClaimAmount(
                      'Approved Cover',
                      claim.approvedCoverCents,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Deceased: ${claim.deceasedFirstNames} ${claim.deceasedLastName} • ${claim.identityType}: ${claim.identityNumber}',
              ),
              if (claim.isPending) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This request is awaiting approval. Pending amounts remain part of the family shortfall until approved.',
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

    final selected = _controller.selectedGroupSociety;
    if (selected != null && _controller.hasConfiguredGroupSocietyCover) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: const Icon(Icons.groups_2_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${selected.groupNo} • Selected for this arrangement',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'change') {
                        _showGroupSocietyCoverDialog();
                      } else if (value == 'remove') {
                        _controller.clearConfiguredGroupSocietyCover();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'change', child: Text('Change')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _groupClaimAmount(
                      'Requested Cover',
                      _controller.groupSocietyRequestedCoverCents,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _groupClaimAmount(
                      'Available Balance',
                      selected.availableBalanceCents,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Deceased: ${_controller.groupSocietyDeceasedFirstNames} ${_controller.groupSocietyDeceasedLastName} • ${_controller.groupSocietyIdentityType}: ${_controller.groupSocietyIdentityNumber}',
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The group society approval request will be submitted after the package and arrangement details are saved.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: const Icon(Icons.groups_2_outlined)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Group Society Funding',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fund all or part of the funeral from an active group society balance.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _controller.groupSocieties.isEmpty
                  ? null
                  : _showGroupSocietyCoverDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Select Society'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupClaimAmount(String label, int cents) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            FuneralMoneyText(
              cents: cents,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      );

  Future<void> _showGroupSocietyCoverDialog() async {
    final societies = _controller.groupSocieties;
    if (societies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active group societies are available.')),
      );
      return;
    }

    var selectedSocietyId = _controller.selectedGroupSocietyId ?? societies.first.id;
    final fullName = (_controller.selectedDeceased?.deceasedName ?? '').trim();
    final nameParts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstNames = TextEditingController(
      text: _controller.groupSocietyDeceasedFirstNames.isNotEmpty
          ? _controller.groupSocietyDeceasedFirstNames
          : nameParts.length > 1
              ? nameParts.sublist(0, nameParts.length - 1).join(' ')
              : fullName,
    );
    final lastName = TextEditingController(
      text: _controller.groupSocietyDeceasedLastName.isNotEmpty
          ? _controller.groupSocietyDeceasedLastName
          : nameParts.length > 1
              ? nameParts.last
              : '',
    );
    final identity = TextEditingController(
      text: _controller.groupSocietyIdentityNumber.isNotEmpty
          ? _controller.groupSocietyIdentityNumber
          : _controller.deceasedIdentityNumber,
    );
    final amount = TextEditingController(
      text: _controller.groupSocietyRequestedCoverCents > 0
          ? (_controller.groupSocietyRequestedCoverCents / 100)
              .toStringAsFixed(2)
          : '',
    );
    final notes = TextEditingController(text: _controller.groupSocietyNotes ?? '');
    var identityType = _controller.groupSocietyIdentityType;

    final configured = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected =
              societies.firstWhere((item) => item.id == selectedSocietyId);
          return AlertDialog(
            title: const Row(
              children: [
                CircleAvatar(child: Icon(Icons.groups_2_outlined)),
                SizedBox(width: 12),
                Expanded(child: Text('Select Group Society Cover')),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableDropdownFormField<String>(
                      value: selectedSocietyId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Group Society'),
                      items: societies
                          .map(
                            (society) => DropdownMenuItem(
                              value: society.id,
                              child: Text(
                                '${society.name} (${society.groupNo}) — R ${society.availableBalance.toStringAsFixed(2)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => selectedSocietyId = value!,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Available balance: R ${selected.availableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstNames,
                            decoration: const InputDecoration(
                              labelText: 'Deceased First Names',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lastName,
                            decoration: const InputDecoration(
                              labelText: 'Deceased Last Name',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: SearchableDropdownFormField<String>(
                            value: identityType,
                            decoration:
                                const InputDecoration(labelText: 'ID Type'),
                            items: const [
                              DropdownMenuItem(
                                value: 'SA-ID',
                                child: Text('SA ID'),
                              ),
                              DropdownMenuItem(
                                value: 'PASSPORT',
                                child: Text('Passport'),
                              ),
                              DropdownMenuItem(
                                value: 'OTHER',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => identityType = value!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: identity,
                            decoration: const InputDecoration(
                              labelText: 'Identification Number',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amount,
                      decoration: const InputDecoration(
                        labelText: 'Requested Cover Amount (R)',
                        prefixText: 'R ',
                        helperText:
                            'The amount will be validated against the final funeral total after package selection.',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final requestedAmount = double.tryParse(
                    amount.text.trim().replaceAll(',', '.'),
                  );
                  if (firstNames.text.trim().isEmpty ||
                      lastName.text.trim().isEmpty ||
                      identity.text.trim().isEmpty ||
                      requestedAmount == null ||
                      requestedAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Complete the deceased details and enter a valid cover amount.',
                        ),
                      ),
                    );
                    return;
                  }
                  final requestedCents = (requestedAmount * 100).round();
                  if (requestedCents > selected.availableBalanceCents) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The requested amount exceeds the available group society balance.',
                        ),
                      ),
                    );
                    return;
                  }
                  final prefs = await SharedPreferences.getInstance();
                  _controller.configureGroupSocietyCover(
                    groupSocietyId: selectedSocietyId,
                    deceasedFirstNames: firstNames.text,
                    deceasedLastName: lastName.text,
                    identityType: identityType,
                    identityNumber: identity.text,
                    requestedCoverCents: requestedCents,
                    requestedBy: prefs.getString('userId') ?? 'SYSTEM',
                    notes: notes.text,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Use This Cover'),
              ),
            ],
          );
        },
      ),
    );

    firstNames.dispose();
    lastName.dispose();
    identity.dispose();
    amount.dispose();
    notes.dispose();

    if (configured == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Group society funding selected. It will be submitted for approval when the arrangement is initiated.',
          ),
        ),
      );
    }
  }

  Widget _buildPreviewStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InvoicePreviewSummaryCard(
          lines: _controller.previewLines,
          onInvoiceTap: (invoiceId) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
              ),
            );
            if (mounted) await _controller.loadInvoicePreview();
          },
        ),
        const SizedBox(height: 16),
        if (_controller.hasPendingClaims)
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'WARNING: You have pending claims. If you generate invoices now, any pending claim amounts will be billed to the family representative.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenerateStep() {
    if (_controller.generationResponse == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              _controller.previewLines.any((line) => line.invoiceId == null || line.invoiceId!.isEmpty)
                  ? 'Finalize and Generate Invoices'
                  : 'Review and Update Final Invoices',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _controller.previewLines.any((line) => line.invoiceId == null || line.invoiceId!.isEmpty)
                    ? 'This will create any missing final invoices from the approved claim split. Existing invoices will be reused.'
                    : 'The final invoices already exist. This will refresh those same invoices from the latest approved split without creating duplicates.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _controller.generateInvoices,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _controller.previewLines.any((line) => line.invoiceId == null || line.invoiceId!.isEmpty)
                    ? 'Generate Invoices Now'
                    : 'Update Existing Invoices',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const Text('Processing Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Service ID: ${_controller.generationResponse!.funeralServiceId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text('Invoices Ready: ${_controller.generationResponse!.invoiceIds.length}'),
                    if (_controller.previewLines.any((line) => line.invoiceId != null && line.invoiceId!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      ..._controller.previewLines
                          .where((line) => line.invoiceId != null && line.invoiceId!.isNotEmpty)
                          .map((line) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.receipt_long_outlined),
                                title: Text(line.invoiceNo ?? 'Invoice'),
                                subtitle: Text('${line.entityName}${line.invoiceStatus == null ? '' : ' • ${line.invoiceStatus!.replaceAll('_', ' ')}'}'),
                                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(invoiceId: line.invoiceId!),
                                  ),
                                ),
                              )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                       if (_controller.generationResponse!.invoiceIds.isNotEmpty) {
                         context.push('/funeral/invoice/${_controller.generationResponse!.invoiceIds.first}/payment');
                       }
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Capture Payment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_controller.currentStep == 6 &&
        _controller.generationResponse != null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: MawaDesign.surface,
        border: Border(top: BorderSide(color: MawaDesign.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                if (_controller.currentStep > 0)
                  OutlinedButton.icon(
                    onPressed: _controller.previousStep,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                  )
                else
                  const SizedBox(width: 1),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _onNextPressed,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(_getNextButtonText()),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(140, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNextButtonText() {
    switch (_controller.currentStep) {
      case 3:
        return 'Initiate Request';
      case 4:
        return 'Submit Claims for Approval';
      case 5:
        return 'Proceed to Generation';
      case 6:
        return 'Done';
      default:
        return 'Continue';
    }
  }

  Future<void> _onNextPressed() async {
    if (_controller.currentStep == 0) {
      if (_controller.selectedDeceased == null) {
        _controller.errorMessage = 'Please select a deceased person from the list.';
        return;
      }
      if (_controller.deceasedIdentityNumber.isEmpty) {
        setState(() => _controller.errorMessage = 'Identity number is required for the membership check step.');
        return;
      }
      if (_controller.causeOfDeath == null || _controller.causeOfDeath!.isEmpty) {
        setState(() => _controller.errorMessage = 'Please select the cause of death.');
        return;
      }
      if (_controller.dateOfDeath == null) {
        setState(() => _controller.errorMessage = 'Date of Death is required.');
        return;
      }
      if (_controller.deathCertificateNo.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Death Certificate Number is required.');
        return;
      }
      _controller.errorMessage = null;
      await _controller.checkMembership();
      _controller.nextStep();
    } else if (_controller.currentStep == 1) {
      // Cover selection is optional, but the membership lookup has already
      // happened before the user can proceed to package selection.
      _controller.errorMessage = null;
      _controller.nextStep();
    } else if (_controller.currentStep == 2) {
      if (_controller.familyRepresentativeNames.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Family representative names are required.');
        return;
      }
      if (_controller.familyRepresentativeSurname.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Family representative surname is required.');
        return;
      }
      if (_controller.familyRepresentativeContactDetails.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Family representative contact details are required.');
        return;
      }
      if (_controller.funeralLocation.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Please select the Funeral Location / Area.');
        return;
      }
      _controller.errorMessage = null;
      _controller.nextStep();
    } else if (_controller.currentStep == 3) {
      if (_controller.effectiveSelectedPackage == null) {
        _controller.errorMessage = 'Please select a funeral package.';
        return;
      }
      final success = await _controller.initiateArrangementAndClaims();
      if (success) {
        _controller.nextStep();
      }
    } else if (_controller.currentStep == 4) {
      final submitted = await _controller.submitClaimsForApproval();
      if (submitted) {
        await _controller.loadInvoicePreview();
        _controller.nextStep();
      }
    } else if (_controller.currentStep == 5) {
      if (_controller.hasPendingClaims) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pending Claims'),
            content: const Text('Some claims are still pending. Generating invoices now will bill the pending cover amounts to the family representative. Proceed anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Wait for Approval')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed to Generate')),
            ],
          ),
        );
        if (confirm != true) return;
      }
      _controller.nextStep();
    } else if (_controller.currentStep == 6) {
      context.pop();
    }
  }

  void _showAddExtraDialog() {
    ProductLookup? selected;
    int quantity = 1;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MawaDialogHeader(
                      icon: Icons.add_shopping_cart_rounded,
                      title: 'Add product extra',
                      description:
                          'Add an optional product to the funeral arrangement.',
                      onClose: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 22),
                    SearchableDropdownFormField<ProductLookup>(
                      value: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Product',
                      ),
                      items: _controller.products
                          .map(
                            (product) => DropdownMenuItem(
                              value: product,
                              child: Text(
                                '${product.code} • ${product.description}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selected = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: '1',
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      onChanged: (value) => quantity = int.tryParse(value) ?? 1,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selected == null
                                ? null
                                : () {
                                    final product = selected!;
                                    final safeQuantity = quantity < 1 ? 1 : quantity;
                                    setState(
                                      () => _controller.extras.add(
                                        FuneralExtraDto(
                                          description:
                                              '${product.code} - ${product.description} x $safeQuantity',
                                          amountCents:
                                              product.priceCents * safeQuantity,
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                            child: const Text('Add product'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
