import '../data/funeral_api.dart';
import '../data/models/funeral_claim_dto.dart';
import '../data/models/funeral_invoice_preview_line_dto.dart';
import '../data/models/funeral_invoice_preview_request_dto.dart';
import '../data/models/funeral_membership_cover_dto.dart';
import '../data/models/funeral_package_dto.dart';
import '../data/models/funeral_service_request_dto.dart';
import '../data/models/generate_funeral_invoices_response_dto.dart';
import '../data/models/initiate_funeral_claims_request_dto.dart';
import '../data/models/invoice_payment_request_dto.dart';
import '../data/models/mortuary_checkout_request_dto.dart';
import '../data/models/mortuary_inventory_dto.dart';

class FuneralServiceRequestService {
  static final FuneralServiceRequestService _instance = FuneralServiceRequestService._internal();
  factory FuneralServiceRequestService() => _instance;
  FuneralServiceRequestService._internal();

  final FuneralApi _api = FuneralApi();

  Future<List<MortuaryInventoryDto>> getMortuaryInventory() => _api.getMortuaryInventory();

  Future<void> checkoutFromMortuary(String id, MortuaryCheckoutRequestDto request) =>
      _api.checkoutFromMortuary(id, request);

  Future<List<FuneralPackageDto>> getFuneralPackages() => _api.getFuneralPackages();

  Future<List<FuneralMembershipCoverDto>> checkMembership(String identityNumber) =>
      _api.checkMembership(identityNumber);

  Future<FuneralServiceRequestDto> createServiceRequest(FuneralServiceRequestDto request) =>
      _api.createServiceRequest(request);

  Future<void> initiateClaims(String serviceRequestId, InitiateFuneralClaimsRequestDto request) =>
      _api.initiateClaims(serviceRequestId, request);

  Future<List<FuneralClaimDto>> initiateClaimsAndReturn(
    String serviceRequestId,
    InitiateFuneralClaimsRequestDto request,
  ) =>
      _api.initiateClaimsAndReturn(serviceRequestId, request);

  Future<List<FuneralClaimDto>> getClaims(String serviceRequestId) => _api.getClaims(serviceRequestId);

  Future<List<FuneralInvoicePreviewLineDto>> getInvoicePreview(
    FuneralInvoicePreviewRequestDto request,
  ) =>
      _api.getInvoicePreview(request);

  Future<GenerateFuneralInvoicesResponseDto> generateInvoices(
    FuneralInvoicePreviewRequestDto request,
  ) =>
      _api.generateInvoicesFromPreviewRequest(request);

  Future<void> capturePayment(String invoiceId, InvoicePaymentRequestDto request) =>
      _api.capturePayment(invoiceId, request);
}
