import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../../../core/services/product_lookup_service.dart';

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
  final _locationController = TextEditingController();
  final _deathCertificateController = TextEditingController();

  final List<String> _stepTitles = [
    'Deceased',
    'Representative',
    'Cover',
    'Claims',
    'Package',
    'Preview',
    'Generate'
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
    _locationController.dispose();
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
        return _buildFamilyRepStep();
      case 2:
        return _buildCoverStep();
      case 3:
        return _buildClaimsStep();
      case 4:
        return _buildPackageStep();
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
          value: _controller.salesAreaOptions.any((o) => o.code == _controller.funeralLocation)
              ? _controller.funeralLocation
              : null,
          decoration: const InputDecoration(
            labelText: 'Funeral Location / Area',
            helperText: 'Field option: SALES-AREA',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: _controller.salesAreaOptions
              .map((opt) => DropdownMenuItem(value: opt.code, child: Text(opt.description)))
              .toList(),
          onChanged: (v) => setState(() => _controller.funeralLocation = v ?? ''),
          validator: (v) => v == null || v.isEmpty ? 'Funeral location is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deathCertificateController,
          decoration: const InputDecoration(
            labelText: 'Certificate Number',
            helperText: 'Death certificate / supporting certificate number',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => _controller.deathCertificateNo = v.trim().toUpperCase(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _controller.causeOfDeathOptions.any((o) => o.code == _controller.causeOfDeathCode)
              ? _controller.causeOfDeathCode
              : null,
          decoration: const InputDecoration(
            labelText: 'Cause of Death',
            helperText: 'Field option: CAUSE-OF-DEATH',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: _controller.causeOfDeathOptions
              .map((opt) => DropdownMenuItem(value: opt.code, child: Text(opt.description)))
              .toList(),
          onChanged: (v) => setState(() => _controller.causeOfDeathCode = v),
          validator: (v) => v == null || v.isEmpty ? 'Cause of death is required' : null,
        ),
      ],
    );
  }

  Widget _buildPackageStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select Funeral Package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Claims are initiated before package selection. The package selected here is used for final costing and invoice splitting.', style: TextStyle(color: Colors.grey)),
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
      ],
    );
  }

  Widget _buildCoverStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Find Cover and Initiate Claims', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              isSelected: _controller.isCoverSelected(cover),
              claimType: _controller.selectedClaimType,
              onTap: () => _controller.toggleCoverSelection(cover),
            )),
        if (_controller.availableCovers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _controller.selectedCovers.isEmpty
                  ? 'Select one or more memberships to use for claim initiation.'
                  : '${_controller.selectedCovers.length} cover(s) selected. Claim type: ${_controller.selectedClaimType}. Estimated cover: R ${(_controller.selectedCoverTotalCents / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: _controller.selectedCovers.isEmpty ? Colors.grey : Colors.green.shade700,
                fontWeight: _controller.selectedCovers.isEmpty ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          if (_controller.hasInvalidSelectedCovers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'One selected cover is missing a valid claim selection id. Please run Check Cover again.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
                    const Divider(),
                    AttachmentSection(
                      objectId: claim.id,
                      objectType: 'claims',
                      documentTypeField: 'CLAIM-DOCUMENT-TYPE',
                      readOnly: claim.status != ClaimStatus.DRAFT,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (claim.status == ClaimStatus.DRAFT)
                          ElevatedButton.icon(
                            onPressed: () => _controller.submitClaimForApproval(claim.id),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Submit for Approval'),
                          ),
                        if (claim.status == ClaimStatus.PENDING || claim.status == ClaimStatus.SUBMITTED || claim.status == ClaimStatus.IN_PROGRESS)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Submitted to approval workflow', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        if (claim.status == ClaimStatus.PENDING)
                          TextButton(
                            onPressed: () => _handleClaimApproval(claim),
                            child: const Text('Review & Approve'),
                          ),
                      ],
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
                    const SizedBox(height: 12),
                    if (_controller.generationResponse!.invoices.isNotEmpty)
                      ..._controller.generationResponse!.invoices.map(
                        (invoice) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(invoice.invoiceNo.isEmpty ? invoice.invoiceId : invoice.invoiceNo),
                          subtitle: Text('Total: R${(invoice.totalCents / 100).toStringAsFixed(2)} • ${invoice.status}'),
                          trailing: TextButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open'),
                            onPressed: () => context.push('/invoices/${invoice.invoiceId}/preview'),
                          ),
                        ),
                      ),
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
      case 2:
        return 'Initiate Claims';
      case 3:
        return 'Continue to Package';
      case 4:
        return 'Continue to Preview';
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
        _controller.setError('Please select a deceased person from the list.');
        return;
      }
      if (_controller.deceasedIdentityNumber.isEmpty) {
        _controller.setError('Identity number is required for the membership check step.');
        return;
      }
      _controller.setError(null);
      _controller.nextStep();
    } else if (_controller.currentStep == 1) {
      if (_controller.familyRepPartnerId == null) {
        _controller.setError('Please search and select a family representative.');
        return;
      }
      if (_controller.funeralLocation.trim().isEmpty) {
        _controller.setError('Please select a funeral location / sales area.');
        return;
      }
      _controller.setError(null);
      _controller.nextStep();
    } else if (_controller.currentStep == 2) {
      if (_controller.availableCovers.isEmpty) {
        _controller.setError('Please run Check Cover before initiating claims.');
        return;
      }
      if (_controller.selectedCovers.isEmpty) {
        _controller.setError('Please select at least one membership cover before initiating claims.');
        return;
      }
      if (_controller.hasInvalidSelectedCovers) {
        _controller.setError('One selected cover is missing a valid claim selection id. Please run Check Cover again and reselect the cover.');
        return;
      }
      final success = await _controller.createServiceRequest();
      if (success) _controller.nextStep();
    } else if (_controller.currentStep == 3) {
      if (_controller.hasDraftClaims) {
        _controller.setError('Please attach claim documentation and submit all draft claims for approval before choosing the funeral package.');
        return;
      }
      _controller.setError(null);
      _controller.nextStep();
    } else if (_controller.currentStep == 4) {
      if (_controller.selectedPackage == null) {
        _controller.setError('Please select a funeral package.');
        return;
      }
      final updated = await _controller.updatePackageSelection();
      if (!updated) return;
      await _controller.loadInvoicePreview();
      _controller.nextStep();
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
    showDialog(
      context: context,
      builder: (context) => const _FuneralExtraProductDialog(),
    ).then((extra) {
      if (extra is FuneralExtraDto) {
        setState(() => _controller.extras.add(extra));
      }
    });
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


class _FuneralExtraProductDialog extends StatefulWidget {
  const _FuneralExtraProductDialog();

  @override
  State<_FuneralExtraProductDialog> createState() => _FuneralExtraProductDialogState();
}

class _FuneralExtraProductDialogState extends State<_FuneralExtraProductDialog> {
  final _service = ProductLookupService();
  final _amountController = TextEditingController();
  List<ProductLookup> _products = [];
  ProductLookup? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _service.getProducts(type: 'FUNERAL-EXTRA');
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Funeral Extra'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.red))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<ProductLookup>(
                        value: _selected,
                        decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                        isExpanded: true,
                        items: _products
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.description} (${p.code})'),
                                ))
                            .toList(),
                        onChanged: (p) {
                          setState(() {
                            _selected = p;
                            _amountController.text = ((p?.priceCents ?? 0) / 100).toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: 'Amount (Rand)', prefixText: 'R ', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () {
                  final cents = ((double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0) * 100).round();
                  Navigator.pop(
                    context,
                    FuneralExtraDto(
                      description: _selected!.description,
                      amountCents: cents,
                      productId: _selected!.id,
                      productCode: _selected!.code,
                    ),
                  );
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
