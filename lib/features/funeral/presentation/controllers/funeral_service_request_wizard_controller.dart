import 'package:flutter/material.dart';
import '../../../../core/models/field_option.dart';
import '../../../../core/services/field_service.dart';
import '../../../../core/services/product_lookup_service.dart';
import '../../../../core/models/product_lookup.dart';
import '../../data/funeral_api.dart';
import '../../data/models/mortuary_inventory_dto.dart';
import '../../data/models/funeral_package_dto.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/initiate_funeral_claims_request_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_invoice_preview_request_dto.dart';
import '../../data/models/generate_funeral_invoices_response_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../data/models/group_society_cover_option_dto.dart';
import '../../data/models/group_society_funeral_claim_dto.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralServiceRequestWizardController extends ChangeNotifier {
  final FuneralApi _api = FuneralApi();
  final FieldService _fieldService = FieldService();
  final ProductLookupService _productService = ProductLookupService();

  int currentStep = 0;
  bool isLoading = false;
  String? errorMessage;

  // Step 1: Deceased / Mortuary
  List<MortuaryInventoryDto> inventory = [];
  MortuaryInventoryDto? selectedDeceased;
  String deceasedIdentityNumber = '';
  String deathCertificateNo = '';
  String? causeOfDeath;
  List<FieldOption> causeOfDeathOptions = [];

  // Step 2: Family Rep & Funeral Info
  String? familyRepPartnerId;
  String? familyRepName;
  String contactName = '';
  String contactNumber = '';
  DateTime funeralDate = DateTime.now().add(const Duration(days: 3));
  String funeralLocation = '';
  List<FieldOption> salesAreaOptions = [];

  // Step 3: Package & Extras
  List<FuneralPackageDto> packages = [];
  FuneralPackageDto? selectedPackage;
  List<FuneralExtraDto> extras = [];
  List<ProductLookup> products = [];

  // Cover step: Funding selection
  List<FuneralMembershipCoverDto> availableCovers = [];
  List<FuneralMembershipCoverDto> selectedCovers = [];
  String? groceryCoverSelectionId;
  String? selectedGroupSocietyId;
  String groupSocietyDeceasedFirstNames = '';
  String groupSocietyDeceasedLastName = '';
  String groupSocietyIdentityType = 'SA-ID';
  String groupSocietyIdentityNumber = '';
  int groupSocietyRequestedCoverCents = 0;
  String groupSocietyRequestedBy = 'SYSTEM';
  String? groupSocietyNotes;

  // Step 5: Claims
  String? serviceRequestId;
  List<FuneralClaimDto> claims = [];
  List<GroupSocietyCoverOptionDto> groupSocieties = [];
  List<GroupSocietyFuneralClaimDto> groupSocietyClaims = [];

  // Step 6: Invoice Preview
  List<FuneralInvoicePreviewLineDto> previewLines = [];

  // Step 7: Generated Invoices
  GenerateFuneralInvoicesResponseDto? generationResponse;

  Future<void> loadInitialData({String? resumeServiceRequestId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getMortuaryInventory(),
        _api.getFuneralPackages(),
        _fieldService.getOptionsByField('CAUSE-OF-DEATH'),
        _fieldService.getOptionsByField('SALES-AREA'),
        _productService.getProducts(),
        _api.getActiveGroupSocieties(),
      ]);
      inventory = results[0] as List<MortuaryInventoryDto>;
      packages = results[1] as List<FuneralPackageDto>;
      _synchroniseSelectedPackage();
      causeOfDeathOptions = results[2] as List<FieldOption>;
      salesAreaOptions = results[3] as List<FieldOption>;
      products = results[4] as List<ProductLookup>;
      groupSocieties = results[5] as List<GroupSocietyCoverOptionDto>;
      if (resumeServiceRequestId != null && resumeServiceRequestId.isNotEmpty) {
        await _restoreArrangement(resumeServiceRequestId);
      }
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to load initial data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreArrangement(String id) async {
    final request = await _api.getServiceRequest(id);
    serviceRequestId = request.id ?? id;
    selectedDeceased = _firstWhereOrNull(inventory, (item) => item.id == request.mortuaryInventoryId);
    selectedDeceased ??= MortuaryInventoryDto(
      id: request.mortuaryInventoryId,
      deceasedName: request.deceasedName,
      identityNumber: request.deceasedIdentityNumber,
      checkInDate: DateTime.now(),
    );
    deceasedIdentityNumber = request.deceasedIdentityNumber;
    deathCertificateNo = request.deathCertificateNo;
    causeOfDeath = request.causeOfDeath;
    familyRepPartnerId = request.familyRepPartnerId;
    funeralDate = request.funeralDate;
    funeralLocation = request.funeralLocation;
    extras = List.of(request.extras);
    selectedPackage = _firstWhereOrNull(packages, (item) => item.id == request.packageId);
    currentStep = request.status?.toUpperCase() == 'INVOICED'
        ? 6
        : request.wizardStep.clamp(0, 6).toInt();

    if (deceasedIdentityNumber.isNotEmpty) {
      availableCovers = await _api.checkMembership(deceasedIdentityNumber);
    }
    claims = await _api.getClaims(serviceRequestId!);
    groupSocietyClaims = await _api.getGroupSocietyCover(serviceRequestId!);
    if (groupSocietyClaims.isNotEmpty) {
      final claim = groupSocietyClaims.first;
      selectedGroupSocietyId = claim.groupSocietyId;
      groupSocietyDeceasedFirstNames = claim.deceasedFirstNames;
      groupSocietyDeceasedLastName = claim.deceasedLastName;
      groupSocietyIdentityType = claim.identityType;
      groupSocietyIdentityNumber = claim.identityNumber;
      groupSocietyRequestedCoverCents = claim.requestedCoverCents;
      groupSocietyNotes = claim.notes;
    }
    if (claims.isNotEmpty || groupSocietyClaims.isNotEmpty) {
      final claimReferences = claims
          .expand((claim) => [claim.sourceReference, claim.sourceMembershipId])
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet();
      selectedCovers = availableCovers.where((cover) {
        final values = [cover.sourceReference, cover.sourceMembershipId, cover.membershipId]
            .whereType<String>();
        return values.any(claimReferences.contains);
      }).toList();
      if (currentStep < 4) currentStep = 4;
    }
    if (currentStep >= 5) {
      await loadInvoicePreview();
    }
  }

  void selectDeceased(MortuaryInventoryDto item) {
    selectedDeceased = item;
    if (item.identityNumber != null && item.identityNumber!.isNotEmpty) {
      deceasedIdentityNumber = item.identityNumber!;
      if (groupSocietyIdentityNumber.isEmpty) {
        groupSocietyIdentityNumber = item.identityNumber!;
      }
    }
    if (groupSocietyDeceasedFirstNames.isEmpty &&
        groupSocietyDeceasedLastName.isEmpty) {
      final parts = item.deceasedName
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.length > 1) {
        groupSocietyDeceasedFirstNames =
            parts.sublist(0, parts.length - 1).join(' ');
        groupSocietyDeceasedLastName = parts.last;
      } else if (parts.isNotEmpty) {
        groupSocietyDeceasedFirstNames = parts.first;
      }
    }
    notifyListeners();
  }

  Future<void> checkMembership() async {
    if (deceasedIdentityNumber.isEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      availableCovers = await _api.checkMembership(deceasedIdentityNumber);
      if (availableCovers.isEmpty) {
        errorMessage = 'No memberships found for this identity number.';
      }
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to check membership: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createServiceRequest() async {
    final package = effectiveSelectedPackage;
    if (selectedDeceased == null ||
        familyRepPartnerId == null ||
        package == null ||
        deathCertificateNo.trim().isEmpty ||
        causeOfDeath == null ||
        causeOfDeath!.trim().isEmpty ||
        funeralLocation.trim().isEmpty) {
      errorMessage = 'Please complete all required fields';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final request = FuneralServiceRequestDto(
        mortuaryInventoryId: selectedDeceased!.id,
        deceasedName: selectedDeceased!.deceasedName,
        deceasedIdentityNumber: deceasedIdentityNumber,
        deathCertificateNo: deathCertificateNo.trim(),
        causeOfDeath: causeOfDeath!,
        funeralDate: funeralDate,
        funeralLocation: funeralLocation.isNotEmpty ? funeralLocation : 'TBC',
        familyRepPartnerId: familyRepPartnerId!,
        packageId: package.id,
        extras: extras,
      );

      final result = serviceRequestId == null
          ? await _api.createServiceRequest(request)
          : await _api.updateServiceRequestPackage(serviceRequestId!, request);
      serviceRequestId = result.id ?? serviceRequestId;

      return true;
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to create service request: $e');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> initiateArrangementAndClaims() async {
    final created = await createServiceRequest();
    if (!created) return false;

    // Group-society funding is chosen on the Cover step, but the approval
    // request can only be created after the funeral service request exists.
    // Submit it first so a validation failure does not leave duplicate
    // membership claims behind when the user retries.
    if (selectedGroupSocietyId != null && groupSocietyClaims.isEmpty) {
      final submitted = await _submitConfiguredGroupSocietyCover();
      if (!submitted) return false;
    }

    if (selectedCovers.isEmpty) {
      await loadClaims();
      return true;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (claims.isEmpty) {
        final selectionIds = selectedCovers
            .map((c) => c.sourceReference ?? c.membershipId)
            .whereType<String>()
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList();
        claims = await _api.initiateClaimsAndReturn(
          serviceRequestId!,
          InitiateFuneralClaimsRequestDto(
            membershipIds: selectionIds,
            // Selecting more than one membership does not turn the claim into a
            // COMBINATION claim. Each selected membership contributes its normal
            // FUNERAL benefit unless a separate combination workflow explicitly
            // requests COMBINATION.
            claimType: 'FUNERAL',
            groceryCoverSelectionId: groceryCoverSelectionId,
          ),
        );
      }
      await loadClaims();
      return true;
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to initiate funeral claims: $e');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitClaimsForApproval() async {
    if (claims.isEmpty) return true;
    final unprinted = claims.where((claim) => !claim.claimFormPrinted).toList();
    if (unprinted.isNotEmpty) {
      errorMessage = 'Print or download every claim form at least once before continuing.';
      notifyListeners();
      return false;
    }
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      for (final claim in claims.where((c) => c.rawStatus == 'DRAFT')) {
        await _api.submitClaimForApproval(claim.id);
      }
      await loadClaims();
      return true;
    } catch (e) { errorMessage = friendlyErrorMessage('Upload the signed claim form once in Claim Documentation before continuing: $e'); return false; }
    finally { isLoading = false; notifyListeners(); }
  }

  Future<List<int>> downloadClaimForm(String claimId) async {
    final bytes = await _api.downloadClaimForm(claimId);
    await loadClaims();
    return bytes;
  }

  bool get allClaimFormsPrinted => claims.isEmpty || claims.every((claim) => claim.claimFormPrinted);

  Future<void> loadClaims() async {
    if (serviceRequestId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getClaims(serviceRequestId!),
        _api.getGroupSocietyCover(serviceRequestId!),
      ]);
      claims = results[0] as List<FuneralClaimDto>;
      groupSocietyClaims = results[1] as List<GroupSocietyFuneralClaimDto>;
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to load claims: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  GroupSocietyCoverOptionDto? get selectedGroupSociety {
    final id = selectedGroupSocietyId;
    if (id == null || id.isEmpty) return null;
    return _firstWhereOrNull(groupSocieties, (society) => society.id == id);
  }

  bool get hasConfiguredGroupSocietyCover =>
      selectedGroupSocietyId != null &&
      selectedGroupSocietyId!.isNotEmpty &&
      groupSocietyRequestedCoverCents > 0;

  void configureGroupSocietyCover({
    required String groupSocietyId,
    required String deceasedFirstNames,
    required String deceasedLastName,
    required String identityType,
    required String identityNumber,
    required int requestedCoverCents,
    required String requestedBy,
    String? notes,
  }) {
    selectedGroupSocietyId = groupSocietyId;
    groupSocietyDeceasedFirstNames = deceasedFirstNames.trim();
    groupSocietyDeceasedLastName = deceasedLastName.trim();
    groupSocietyIdentityType = identityType.trim().toUpperCase();
    groupSocietyIdentityNumber = identityNumber.trim();
    groupSocietyRequestedCoverCents = requestedCoverCents;
    groupSocietyRequestedBy = requestedBy.trim().isEmpty ? 'SYSTEM' : requestedBy.trim();
    groupSocietyNotes = notes?.trim();
    errorMessage = null;
    notifyListeners();
  }

  void clearConfiguredGroupSocietyCover() {
    if (groupSocietyClaims.isNotEmpty) return;
    selectedGroupSocietyId = null;
    groupSocietyRequestedCoverCents = 0;
    groupSocietyNotes = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> _submitConfiguredGroupSocietyCover() async {
    if (serviceRequestId == null) {
      errorMessage = 'Create the funeral arrangement before requesting group society cover.';
      notifyListeners();
      return false;
    }
    if (!hasConfiguredGroupSocietyCover) return true;

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final claim = await _api.submitGroupSocietyCover(serviceRequestId!, {
        'groupSocietyId': selectedGroupSocietyId,
        'deceasedFirstNames': groupSocietyDeceasedFirstNames,
        'deceasedLastName': groupSocietyDeceasedLastName,
        'identityType': groupSocietyIdentityType,
        'identityNumber': groupSocietyIdentityNumber,
        'requestedCoverCents': groupSocietyRequestedCoverCents,
        'requestedBy': groupSocietyRequestedBy,
        'notes': groupSocietyNotes,
      });
      groupSocietyClaims = [claim];
      return true;
    } catch (error) {
      errorMessage = friendlyErrorMessage(
        'Failed to request group society cover: $error',
      );
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInvoicePreview() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final request = FuneralInvoicePreviewRequestDto(
        funeralServiceId: serviceRequestId,
        deceasedName: selectedDeceased?.deceasedName ?? '',
        packageId: effectiveSelectedPackage?.id ?? '',
        familyRepId: familyRepPartnerId ?? '',
        memberships: selectedCovers
            .map((c) => c.sourceReference ?? c.membershipId ?? '')
            .where((id) => id.trim().isNotEmpty)
            .toList(),
        extras: extras,
      );
      previewLines = await _api.getInvoicePreview(request);
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to load invoice preview: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateInvoices() async {
    if (serviceRequestId == null) return false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      generationResponse = await _api.generateInvoices({
        'funeralServiceId': serviceRequestId,
      });
      await loadInvoicePreview();
      return true;
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to generate invoices: $e');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  FuneralPackageDto? get effectiveSelectedPackage {
    final selectedId = selectedPackage?.id;
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final package in packages) {
        if (package.id == selectedId) return package;
      }
      return selectedPackage;
    }
    return packages.length == 1 ? packages.single : null;
  }

  int get packageAmountCents => effectiveSelectedPackage?.basePriceCents ?? 0;
  int get extrasTotalCents => extras.fold(0, (sum, e) => sum + e.amountCents);
  int get arrangementTotalCents => packageAmountCents + extrasTotalCents;
  int get selectedCoverTotalCents {
    return selectedCovers.fold(
      0,
      (sum, cover) => sum + _coverAmountCents(cover),
    );
  }
  int get requestedGroupSocietyCoverCents {
    if (groupSocietyClaims.isNotEmpty) {
      return groupSocietyClaims.fold(
        0,
        (sum, claim) => sum + claim.requestedCoverCents,
      );
    }
    return hasConfiguredGroupSocietyCover
        ? groupSocietyRequestedCoverCents
        : 0;
  }

  int get approvedGroupSocietyCoverCents => groupSocietyClaims
      .where((claim) => claim.isApproved)
      .fold(0, (sum, claim) => sum + claim.approvedCoverCents);
  int get shortfallCents => (arrangementTotalCents - selectedCoverTotalCents - approvedGroupSocietyCoverCents)
      .clamp(0, 1 << 62)
      .toInt();

  void selectPackage(FuneralPackageDto package) {
    selectedPackage = package;
    notifyListeners();
  }

  void toggleCoverSelection(FuneralMembershipCoverDto cover) {
    final selectionId = _coverSelectionId(cover);
    final isSelected = selectedCovers.any(
      (selected) => _coverSelectionId(selected) == selectionId,
    );

    if (isSelected) {
      selectedCovers.removeWhere(
        (selected) => _coverSelectionId(selected) == selectionId,
      );
      if (groceryCoverSelectionId == selectionId) {
        groceryCoverSelectionId = null;
      }
    } else {
      selectedCovers.add(cover);
    }
    notifyListeners();
  }

  int _coverAmountCents(FuneralMembershipCoverDto cover) {
    final funeralAmount = cover.funeralAmountCents > 0
        ? cover.funeralAmountCents
        : cover.coverAmountCents;
    return funeralAmount;
  }

  String? _coverSelectionId(FuneralMembershipCoverDto cover) =>
      cover.membershipId ?? cover.sourceReference;

  void _synchroniseSelectedPackage() {
    final selectedId = selectedPackage?.id;
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final package in packages) {
        if (package.id == selectedId) {
          selectedPackage = package;
          return;
        }
      }
      selectedPackage = null;
    }

    // A single available package is unambiguous and should immediately feed
    // the package, total-cost and shortfall calculations.
    if (packages.length == 1) {
      selectedPackage = packages.single;
    }
  }

  void nextStep() {
    if (currentStep < 6) {
      currentStep++;
      _saveProgress();
      notifyListeners();
    }
  }

  void goToInvoicePreview() {
    currentStep = 5;
    _saveProgress();
    notifyListeners();
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  void _saveProgress() {
    final id = serviceRequestId;
    if (id == null || id.isEmpty) return;
    _api.updateWizardStep(id, currentStep).catchError((_) {});
  }

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }

  bool get hasPendingClaims => claims.any((claim) {
        final status = claim.status.name.toUpperCase();
        return status == 'PENDING' || status == 'DRAFT' || status == 'SUBMITTED';
      }) || groupSocietyClaims.any((claim) => claim.isPending);
}
