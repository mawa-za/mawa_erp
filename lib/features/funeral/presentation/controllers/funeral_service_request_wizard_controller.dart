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
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../../data/models/funeral_enums.dart';
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

  // Step 4: Membership Cover
  List<FuneralMembershipCoverDto> availableCovers = [];
  List<FuneralMembershipCoverDto> selectedCovers = [];
  String? groceryCoverSelectionId;

  // Step 5: Claims
  String? serviceRequestId;
  List<FuneralClaimDto> claims = [];

  // Step 6: Invoice Preview
  List<FuneralInvoicePreviewLineDto> previewLines = [];

  // Step 7: Generated Invoices
  GenerateFuneralInvoicesResponseDto? generationResponse;

  Future<void> loadInitialData() async {
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
      ]);
      inventory = results[0] as List<MortuaryInventoryDto>;
      packages = results[1] as List<FuneralPackageDto>;
      _synchroniseSelectedPackage();
      causeOfDeathOptions = results[2] as List<FieldOption>;
      salesAreaOptions = results[3] as List<FieldOption>;
      products = results[4] as List<ProductLookup>;
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to load initial data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectDeceased(MortuaryInventoryDto item) {
    selectedDeceased = item;
    if (item.identityNumber != null && item.identityNumber!.isNotEmpty) {
      deceasedIdentityNumber = item.identityNumber!;
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

      final result = await _api.createServiceRequest(request);
      serviceRequestId = result.id;
      
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
    if (selectedCovers.isEmpty) {
      await loadClaims();
      return true;
    }
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      final selectionIds = selectedCovers.map((c) => c.sourceReference ?? c.membershipId)
          .whereType<String>().map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
      claims = await _api.initiateClaimsAndReturn(serviceRequestId!, InitiateFuneralClaimsRequestDto(
        membershipIds: selectionIds,
        claimType: selectedCovers.length > 1 ? 'COMBINATION' : 'FUNERAL',
        groceryCoverSelectionId: groceryCoverSelectionId,
      ));
      await loadClaims();
      return true;
    } catch (e) { errorMessage = friendlyErrorMessage('Failed to initiate funeral claims: $e'); return false; }
    finally { isLoading = false; notifyListeners(); }
  }

  Future<bool> submitClaimsForApproval() async {
    if (claims.isEmpty) return true;
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

  Future<List<int>> downloadClaimForm(String claimId) => _api.downloadClaimForm(claimId);

  Future<void> loadClaims() async {
    if (serviceRequestId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      claims = await _api.getClaims(serviceRequestId!);
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to load claims: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveClaim(String claimId, ApproveFuneralClaimRequestDto request) async {
    isLoading = true;
    notifyListeners();
    try {
      await _api.approveClaim(claimId, request);
      await loadClaims();
    } catch (e) {
      errorMessage = friendlyErrorMessage('Failed to approve claim: $e');
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
    final useCombinationBenefit = selectedCovers.length > 1;
    return selectedCovers.fold(
      0,
      (sum, cover) =>
          sum + _coverAmountCents(cover, useCombinationBenefit: useCombinationBenefit),
    );
  }
  int get shortfallCents => (arrangementTotalCents - selectedCoverTotalCents).clamp(0, 1 << 62).toInt();

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

  int _coverAmountCents(
    FuneralMembershipCoverDto cover, {
    required bool useCombinationBenefit,
  }) {
    final funeralAmount = cover.funeralAmountCents > 0
        ? cover.funeralAmountCents
        : cover.coverAmountCents;

    if (!useCombinationBenefit) {
      return funeralAmount;
    }

    return cover.combinationAmountCents > 0
        ? cover.combinationAmountCents
        : funeralAmount;
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
      notifyListeners();
    }
  }

  void goToInvoicePreview() {
    currentStep = 5;
    notifyListeners();
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep = currentStep == 5 && selectedCovers.isEmpty
          ? 3
          : currentStep - 1;
      notifyListeners();
    }
  }

  bool get hasPendingClaims => claims.any((c) {
        final status = c.status.name.toUpperCase();
        return status == 'PENDING' || status == 'DRAFT' || status == 'SUBMITTED';
      });
}
