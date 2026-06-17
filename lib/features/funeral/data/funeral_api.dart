import 'dart:convert';
import '../../../core/api_client.dart';
import 'models/pickup_request_dto.dart';
import 'models/create_pickup_request_dto.dart';
import 'models/assign_pickup_request_dto.dart';
import 'models/complete_pickup_request_dto.dart';
import 'models/mortuary_inventory_dto.dart';
import 'models/mortuary_checkout_request_dto.dart';
import 'models/funeral_package_dto.dart';
import 'models/funeral_membership_cover_dto.dart';
import 'models/funeral_service_request_dto.dart';
import 'models/initiate_funeral_claims_request_dto.dart';
import 'models/funeral_claim_dto.dart';
import 'models/approve_funeral_claim_request_dto.dart';
import 'models/funeral_invoice_preview_request_dto.dart';
import 'models/funeral_invoice_preview_line_dto.dart';
import 'models/generate_funeral_invoices_response_dto.dart';
import 'models/invoice_payment_request_dto.dart';

class FuneralApi {
  final ApiClient _apiClient = ApiClient();

  // Pickup Requests
  Future<PickupRequestDto> createPickupRequest(CreatePickupRequestDto request) async {
    final response = await _apiClient.post('/v2/funeral/pickup-request', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PickupRequestDto.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create pickup request: ${response.body}');
  }

  Future<void> assignPickup(String id, String staffId) async {
    final response = await _apiClient.put(
      '/v2/funeral/pickup-request/$id/assign',
      body: AssignPickupRequestDto(staffId: staffId).toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to assign pickup: ${response.body}');
    }
  }

  Future<void> completePickup(String id, DateTime completionTime) async {
    final response = await _apiClient.put(
      '/v2/funeral/pickup-request/$id/complete',
      body: CompletePickupRequestDto(completionTime: completionTime).toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete pickup: ${response.body}');
    }
  }

  // Mortuary
  Future<List<MortuaryInventoryDto>> getMortuaryInventory() async {
    final response = await _apiClient.get('/v2/funeral/mortuary/inventory');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => MortuaryInventoryDto.fromJson(e)).toList();
    }
    throw Exception('Failed to load mortuary inventory: ${response.body}');
  }

  Future<void> checkoutFromMortuary(String id, MortuaryCheckoutRequestDto request) async {
    final response = await _apiClient.post(
      '/v2/funeral/mortuary/$id/checkout',
      body: request.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to checkout from mortuary: ${response.body}');
    }
  }

  // Packages and Membership
  Future<List<FuneralPackageDto>> getFuneralPackages() async {
    final response = await _apiClient.get('/v2/funeral/packages');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FuneralPackageDto.fromJson(e)).toList();
    }
    throw Exception('Failed to load funeral packages: ${response.body}');
  }

  Future<List<FuneralMembershipCoverDto>> checkMembership(String identityNumber) async {
    final response = await _apiClient.get('/v2/funeral/check-membership/$identityNumber');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FuneralMembershipCoverDto.fromJson(e)).toList();
    }
    throw Exception('Failed to check membership: ${response.body}');
  }

  // Funeral Service and Claims
  Future<FuneralServiceRequestDto> createServiceRequest(FuneralServiceRequestDto request) async {
    final response = await _apiClient.post('/v2/funeral/service-request', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return FuneralServiceRequestDto.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create service request: ${response.body}');
  }

  Future<void> initiateClaims(String serviceRequestId, InitiateFuneralClaimsRequestDto request) async {
    final response = await _apiClient.post(
      '/v2/funeral/service-request/$serviceRequestId/initiate-claims',
      body: request.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to initiate claims: ${response.body}');
    }
  }

  Future<List<FuneralClaimDto>> getClaims(String serviceRequestId) async {
    final response = await _apiClient.get('/v2/funeral/service-request/$serviceRequestId/claims');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FuneralClaimDto.fromJson(e)).toList();
    }
    throw Exception('Failed to load claims: ${response.body}');
  }

  Future<void> approveClaim(String claimId, ApproveFuneralClaimRequestDto request) async {
    final response = await _apiClient.put(
      '/v2/funeral/claims/$claimId/approve',
      body: request.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to approve claim: ${response.body}');
    }
  }

  // Invoicing
  Future<List<FuneralInvoicePreviewLineDto>> getInvoicePreview(FuneralInvoicePreviewRequestDto request) async {
    final response = await _apiClient.post('/v2/funeral/invoice-preview', body: request.toJson());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FuneralInvoicePreviewLineDto.fromJson(e)).toList();
    }
    throw Exception('Failed to get invoice preview: ${response.body}');
  }

  Future<GenerateFuneralInvoicesResponseDto> generateInvoices(Map<String, dynamic> request) async {
    final response = await _apiClient.post('/v2/funeral/generate-invoices', body: request);
    if (response.statusCode == 200) {
      return GenerateFuneralInvoicesResponseDto.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to generate invoices: ${response.body}');
  }

  Future<void> capturePayment(String invoiceId, InvoicePaymentRequestDto request) async {
    final response = await _apiClient.post(
      '/v2/invoice/$invoiceId/payment',
      body: request.toJson(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to capture payment: ${response.body}');
    }
  }

  // List Pickups (Fallback helper)
  Future<List<PickupRequestDto>> getPickupRequests() async {
    try {
      final response = await _apiClient.get('/v2/funeral/pickup-requests');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => PickupRequestDto.fromJson(e)).toList();
      }
    } catch (e) {
      // Return empty list if endpoint doesn't exist yet
    }
    return [];
  }
}
