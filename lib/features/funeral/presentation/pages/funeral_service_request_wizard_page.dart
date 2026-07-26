import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../controllers/funeral_service_request_wizard_controller.dart';
import '../widgets/funeral_wizard_stepper.dart';
import '../widgets/funeral_package_card.dart';
import '../widgets/membership_cover_selection_card.dart';
import '../widgets/funeral_claim_approval_dialog.dart';
import '../widgets/invoice_preview_summary_card.dart';
import '../widgets/funeral_money_text.dart';
import '../widgets/funeral_status_chip.dart';
import '../../../../core/widgets/partner_search_dropdown.dart';
import '../../../../core/widgets/attachment_section.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/models/product_lookup.dart';

class FuneralServiceRequestWizardPage extends StatefulWidget {
  const FuneralServiceRequestWizardPage({super.key});

  @override
  State<FuneralServiceRequestWizardPage> createState() => _FuneralServiceRequestWizardPageState();
}

class _FuneralServiceRequestWizardPageState extends State<FuneralServiceRequestWizardPage> {
  late final FuneralServiceRequestWizardController _controller;
  final _idNumberController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _deathCertificateController = TextEditingController();

  final List<String> _stepTitles = [
    'Deceased', 'Cover', 'Representative', 'Package', 'Claims', 'Preview', 'Generate'
  ];

  @override
  void initState() {
    super.initState();
    _controller = FuneralServiceRequestWizardController();
    _controller.loadInitialData();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_idNumberController.text != _controller.deceasedIdentityNumber) {
      _idNumberController.text = _controller.deceasedIdentityNumber;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _idNumberController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _deathCertificateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Funeral Arrangement Wizard'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
          body: Column(
            children: [
              FuneralWizardStepper(
                currentStep: _controller.currentStep,
                steps: _stepTitles,
              ),
              if (_controller.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade50,
                  width: double.infinity,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () => setState(() => _controller.errorMessage = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildStepContent(),
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
          onChanged: (val) => _controller.deceasedIdentityNumber = val,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
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
        PartnerSearchDropdown(
          role: 'CUSTOMER',
          label: 'Search Family Representative',
          initialPartnerId: _controller.familyRepPartnerId,
          onPartnerSelected: (p) {
            setState(() {
              _controller.familyRepPartnerId = p?.id;
              _controller.familyRepName = p?.fullName;
              if (p != null) {
                _contactNameController.text = p.fullName;
                _contactNumberController.text = p.phone;
                _controller.contactName = p.fullName;
                _controller.contactNumber = p.phone;
              }
            });
          },
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _contactNameController,
          decoration: const InputDecoration(labelText: 'Contact Name', border: OutlineInputBorder()),
          onChanged: (v) => _controller.contactName = v,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactNumberController,
          decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) => RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
              ? null
              : 'Contact Number must be 10 numeric digits',
          onChanged: (v) => _controller.contactNumber = v,
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
        DropdownButtonFormField<String>(
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
      ],
    );
  }

  Widget _buildPackageStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select Funeral Package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._controller.packages.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FuneralPackageCard(
                package: p,
                isSelected: _controller.selectedPackage?.id == p.id,
                onTap: () => setState(() => _controller.selectedPackage = p),
              ),
            )),
        const Divider(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Extras', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _showAddExtraDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Extra'),
            ),
          ],
        ),
        if (_controller.extras.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No extras added.', style: TextStyle(color: Colors.grey)),
          ),
        ..._controller.extras.map((e) => Card(
          child: ListTile(
                title: Text(e.description),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FuneralMoneyText(cents: e.amountCents, style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _controller.extras.remove(e)),
                    ),
                  ],
                ),
              ),
        )),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _moneySummaryRow('Package', _controller.packageAmountCents),
              _moneySummaryRow('Extras', _controller.extrasTotalCents),
              const Divider(),
              _moneySummaryRow('Total funeral cost', _controller.arrangementTotalCents, bold: true),
              _moneySummaryRow('Selected cover total', _controller.selectedCoverTotalCents, bold: true),
              _moneySummaryRow('Family shortfall', _controller.shortfallCents, bold: true),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _moneySummaryRow(String label, int cents, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
      FuneralMoneyText(cents: cents, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
    ]),
  );

  Widget _buildCoverStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Membership Cover', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _controller.checkMembership,
              icon: const Icon(Icons.search),
              label: const Text('Check Cover'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_controller.availableCovers.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Text('No memberships found or check not performed.', textAlign: TextAlign.center),
            ),
          ),
        ..._controller.availableCovers.map((cover) => MembershipCoverSelectionCard(
              cover: cover,
              isSelected: _controller.selectedCovers.any((c) => (c.membershipId ?? c.sourceReference) == (cover.membershipId ?? cover.sourceReference)),
              onTap: () {
                setState(() {
                  final id = cover.membershipId ?? cover.sourceReference;
                  if (_controller.selectedCovers.any((c) => (c.membershipId ?? c.sourceReference) == id)) {
                    _controller.selectedCovers.removeWhere((c) => (c.membershipId ?? c.sourceReference) == id);
                  } else {
                    _controller.selectedCovers.add(cover);
                  }
                });
              },
            )),
        if (_controller.selectedCovers.isNotEmpty) ...[
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:_controller.groceryCoverSelectionId,
            decoration:const InputDecoration(labelText:'Cover to use for grocery claim',border:OutlineInputBorder()),
            items:_controller.selectedCovers.map((c){final id=c.membershipId??c.sourceReference??'';return DropdownMenuItem(value:id,child:Text('${c.membershipNumber} • ${c.burialSocietyName}'));}).toList(),
            onChanged:(v)=>setState(()=>_controller.groceryCoverSelectionId=v),
          ),
        ],
        if (_controller.availableCovers.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Select one or more memberships to use for claim initiation.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
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
        AttachmentSection(objectId: serviceId, documentTypeField: 'CLAIM-DOCUMENT-TYPE'),
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
        const SizedBox(height: 16),
        if (_controller.claims.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No claims initiated for this request.'))),
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
                          final bytes = await _controller.downloadClaimForm(claim.id);
                          await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'claim-form-${claim.claimNumber ?? claim.id}.pdf');
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download Claim Form'),
                      ),
                    ]),
                    AttachmentSection(objectId: claim.id, documentTypeField: 'CLAIM-DOCUMENT-TYPE'),
                    if (claim.status == ClaimStatus.PENDING &&
                        !claim.managedExternally)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleClaimApproval(claim),
                            child: const Text('Review & Approve'),
                          ),
                        ],
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

  Widget _buildPreviewStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InvoicePreviewSummaryCard(lines: _controller.previewLines),
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
            const Text('Finalize and Generate Invoices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'This will create final invoices for the burial societies and the family representative based on the approved claims.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _controller.generateInvoices,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Generate Invoices Now', style: TextStyle(fontSize: 16)),
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
                    Text('Invoices Generated: ${_controller.generationResponse!.invoiceIds.length}'),
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
    if (_controller.currentStep == 6 && _controller.generationResponse != null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep > 0)
            OutlinedButton(
              onPressed: _controller.previousStep,
              child: const Text('Previous'),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: _onNextPressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(_getNextButtonText()),
          ),
        ],
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
      if (_controller.familyRepPartnerId == null) {
        setState(() => _controller.errorMessage = 'Please search and select a family representative.');
        return;
      }
      if (_controller.funeralLocation.trim().isEmpty) {
        setState(() => _controller.errorMessage = 'Please select the Funeral Location / Area.');
        return;
      }
      _controller.errorMessage = null;
      _controller.nextStep();
    } else if (_controller.currentStep == 3) {
      if (_controller.selectedPackage == null) {
        _controller.errorMessage = 'Please select a funeral package.';
        return;
      }
      final success = await _controller.initiateArrangementAndClaims();
      if (success) {
        for (final claim in _controller.claims) {
          final bytes = await _controller.downloadClaimForm(claim.id);
          await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'claim-form-${claim.claimNumber ?? claim.id}.pdf');
        }
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
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Product Extra'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<ProductLookup>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
            items: _controller.products.map((p) => DropdownMenuItem(value: p, child: Text('${p.code} • ${p.description}'))).toList(),
            onChanged: (v) => setDialogState(() => selected = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: '1',
            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (v) => quantity = int.tryParse(v) ?? 1,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: selected == null ? null : () {
            final p = selected!;
            final qty = quantity < 1 ? 1 : quantity;
            setState(() => _controller.extras.add(FuneralExtraDto(
              description: '${p.code} - ${p.description} x $qty',
              amountCents: p.priceCents * qty,
            )));
            Navigator.pop(context);
          }, child: const Text('Add')),
        ],
      )),
    );
  }

  Future<void> _handleClaimApproval(claim) async {
    final result = await showDialog<ApproveFuneralClaimRequestDto>(
      context: context,
      builder: (context) => FuneralClaimApprovalDialog(claim: claim),
    );

    if (result != null) {
      await _controller.approveClaim(claim.id, result);
    }
  }
}
