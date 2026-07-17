import 'package:flutter/material.dart';
import '../../../../core/models/field_option.dart';
import '../../../../core/services/field_service.dart';
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

class FuneralServiceRequestWizardController extends ChangeNotifier {
  final FuneralApi _api = FuneralApi();
  final FieldService _fieldService = FieldService();

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
      ]);
      inventory = results[0] as List<MortuaryInventoryDto>;
      packages = results[1] as List<FuneralPackageDto>;
      causeOfDeathOptions = results[2] as List<FieldOption>;
      salesAreaOptions = results[3] as List<FieldOption>;
    } catch (e) {
      errorMessage = 'Failed to load initial data: $e';
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
      errorMessage = 'Failed to check membership: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createServiceRequest() async {
    if (selectedDeceased == null ||
        familyRepPartnerId == null ||
        selectedPackage == null ||
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
        packageId: selectedPackage!.id,
        extras: extras,
      );

      final result = await _api.createServiceRequest(request);
      serviceRequestId = result.id;
      
      if (selectedCovers.isNotEmpty) {
        final membershipIds = selectedCovers
            .where((c) => c.membershipId != null)
            .map((c) => c.membershipId!)
            .toList();
        final sourceRefs = selectedCovers
            .where((c) => c.sourceReference != null)
            .map((c) => c.sourceReference!)
            .toList();
        
        await _api.initiateClaims(
          serviceRequestId!,
          InitiateFuneralClaimsRequestDto(
            membershipIds: membershipIds,
            sourceReferences: sourceRefs.isEmpty ? null : sourceRefs,
            claimType: selectedCovers.length > 1 ? 'COMBINATION' : 'FUNERAL',
            groceryCoverSelectionId: groceryCoverSelectionId,
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
        deceasedName: selectedDeceased?.deceasedName ?? '',
        packageId: selectedPackage?.id ?? '',
        familyRepId: familyRepPartnerId ?? '',
        memberships: selectedCovers.map((c) => c.membershipId ?? c.sourceReference ?? '').toList(),
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
      generationResponse = await _api.generateInvoices({'serviceRequestId': serviceRequestId});
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

  bool get hasPendingClaims => claims.any((c) => c.status.name == 'PENDING');
}
