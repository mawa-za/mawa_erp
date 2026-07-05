import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/mortuary_inventory_dto.dart';
import '../../data/models/funeral_package_dto.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_service_request_dto.dart';
import '../../data/models/initiate_funeral_claims_request_dto.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../data/models/funeral_invoice_preview_line_dto.dart';
import '../../data/models/funeral_invoice_preview_request_dto.dart';
import '../../data/models/generate_funeral_invoices_response_dto.dart';
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../../../../core/models/field_option.dart';
import '../../../../core/services/field_service.dart';

class FuneralServiceRequestWizardController extends ChangeNotifier {
  final FuneralApi _api = FuneralApi();

  int currentStep = 0;
  bool isLoading = false;
  String? errorMessage;

  // Step 1: Deceased / Mortuary
  List<MortuaryInventoryDto> inventory = [];
  MortuaryInventoryDto? selectedDeceased;
  String deceasedIdentityNumber = '';

  // Step 2: Family Rep & Funeral Info
  String? familyRepPartnerId;
  String? familyRepName;
  String contactName = '';
  String contactNumber = '';
  DateTime funeralDate = DateTime.now().add(const Duration(days: 3));
  String funeralLocation = '';
  String deathCertificateNo = '';
  String? causeOfDeathCode;
  List<FieldOption> salesAreaOptions = [];
  List<FieldOption> causeOfDeathOptions = [];

  // Step 3: Package & Extras
  List<FuneralPackageDto> packages = [];
  FuneralPackageDto? selectedPackage;
  List<FuneralExtraDto> extras = [];

  // Step 4: Membership Cover
  List<FuneralMembershipCoverDto> availableCovers = [];
  List<FuneralMembershipCoverDto> selectedCovers = [];

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
        FieldService().getOptionsByField('SALES-AREA').catchError((_) => <FieldOption>[]),
        FieldService().getOptionsByField('CAUSE-OF-DEATH').catchError((_) => <FieldOption>[]),
      ]);
      inventory = results[0] as List<MortuaryInventoryDto>;
      packages = results[1] as List<FuneralPackageDto>;
      salesAreaOptions = results[2] as List<FieldOption>;
      causeOfDeathOptions = results[3] as List<FieldOption>;
      if (funeralLocation.isEmpty && salesAreaOptions.isNotEmpty) {
        funeralLocation = salesAreaOptions.first.code;
      }
      if (causeOfDeathCode == null && causeOfDeathOptions.isNotEmpty) {
        causeOfDeathCode = causeOfDeathOptions.first.code;
      }
    } catch (e) {
      errorMessage = 'Failed to load initial data: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setError(String? message) {
    errorMessage = message;
    notifyListeners();
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
      errorMessage = 'Failed to check membership: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }



  void toggleCoverSelection(FuneralMembershipCoverDto cover) {
    final selectionId = cover.selectionId;
    final existingIndex = selectedCovers.indexWhere((c) => c.selectionId == selectionId);
    if (existingIndex >= 0) {
      selectedCovers.removeAt(existingIndex);
    } else {
      selectedCovers.add(cover);
    }
    errorMessage = null;
    notifyListeners();
  }

  bool isCoverSelected(FuneralMembershipCoverDto cover) {
    return selectedCovers.any((c) => c.selectionId == cover.selectionId);
  }

  List<String> get selectedMembershipSelectionIds => selectedCovers
      .map((c) => c.membershipId?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty && (id.startsWith('LOCAL:') || id.startsWith('EXTERNAL:')))
      .toSet()
      .toList();

  bool get hasInvalidSelectedCovers => selectedCovers.any((c) => !c.hasValidClaimSelectionId);

  String get selectedClaimType => selectedCovers.length > 1 ? 'COMBINATION' : 'FUNERAL';

  int get selectedCoverTotalCents => selectedCovers.fold(
        0,
        (total, cover) => total + cover.amountForClaimType(selectedClaimType),
      );

  Future<bool> createServiceRequest() async {
    if (selectedDeceased == null || familyRepPartnerId == null || selectedPackage == null) {
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
        funeralDate: funeralDate,
        funeralLocation: funeralLocation.isNotEmpty ? funeralLocation : 'TBC',
        familyRepPartnerId: familyRepPartnerId!,
        deathCertificateNo: deathCertificateNo.trim(),
        causeOfDeath: causeOfDeathCode,
        packageId: selectedPackage!.id,
        extras: extras,
      );

      final result = await _api.createServiceRequest(request);
      serviceRequestId = result.id;
      
      if (selectedCovers.isNotEmpty) {
        final membershipSelections = selectedMembershipSelectionIds;

        if (membershipSelections.isEmpty) {
          throw Exception('The selected cover does not contain a valid claim selection id. Please run Check Cover again and select a valid cover.');
        }

        await _api.initiateClaims(
          serviceRequestId!,
          InitiateFuneralClaimsRequestDto(
            membershipIds: membershipSelections,
            claimType: selectedClaimType,
            deathCertificateNo: deathCertificateNo.trim(),
            causeOfDeath: causeOfDeathCode,
          ),
        );
      }
      
      await loadClaims();
      return true;
    } catch (e) {
      errorMessage = 'Failed to create service request: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadClaims() async {
    if (serviceRequestId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      claims = await _api.getClaims(serviceRequestId!);
    } catch (e) {
      errorMessage = 'Failed to load claims: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitClaimForApproval(String claimId) async {
    final normalizedClaimId = claimId.trim();
    if (normalizedClaimId.isEmpty) {
      errorMessage = 'Cannot submit claim for approval because the membership claim id is missing. Please refresh claims and try again.';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _api.submitClaimForApproval(normalizedClaimId);
      await loadClaims();
    } catch (e) {
      errorMessage = 'Failed to submit claim for approval: $e';
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
      errorMessage = 'Failed to approve claim: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInvoicePreview() async {
    isLoading = true;
    notifyListeners();
    try {
      final request = FuneralInvoicePreviewRequestDto(
        funeralServiceId: serviceRequestId,
        deceasedName: selectedDeceased?.deceasedName ?? '',
        packageId: selectedPackage?.id ?? '',
        familyRepId: familyRepPartnerId ?? '',
        memberships: selectedMembershipSelectionIds,
        claimType: selectedClaimType,
        extras: extras,
      );
      previewLines = await _api.getInvoicePreview(request);
    } catch (e) {
      errorMessage = 'Failed to load invoice preview: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateInvoices() async {
    if (serviceRequestId == null) return false;
    isLoading = true;
    notifyListeners();
    try {
      generationResponse = await _api.generateInvoices({'funeralServiceId': serviceRequestId});
      return true;
    } catch (e) {
      errorMessage = 'Failed to generate invoices: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void nextStep() {
    if (currentStep < 6) {
      currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  bool get hasDraftClaims => claims.any((c) => c.status == ClaimStatus.DRAFT);

  bool get hasPendingClaims => claims.any((c) => ['DRAFT', 'PENDING', 'SUBMITTED', 'IN_PROGRESS'].contains(c.status.name));
}
