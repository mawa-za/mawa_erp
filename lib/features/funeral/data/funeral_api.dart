import 'dart:convert';
import '../../../core/api_client.dart';
import '../../partners/models/partner.dart';
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
import 'models/funeral_payment_summary_dto.dart';

class FuneralApi {
  final ApiClient _apiClient = ApiClient();

  // Pickup Requests

  Future<List<Partner>> getEmployees() async {
    final response = await _apiClient.get('/employees');
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map((e) => Partner.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception('Failed to load employees: ${response.body}');
  }

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
      return _decodeList(response.body)
          .map((e) => MortuaryInventoryDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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
  Future<List<FuneralPackageDto>> getFuneralPackages({bool activeOnly = true}) async {
    final response = await _apiClient.get(
      '/v2/funeral/packages',
      queryParameters: {'activeOnly': activeOnly},
    );
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map((e) => FuneralPackageDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception('Failed to load funeral packages: ${response.body}');
  }

  Future<FuneralPackageDto> createFuneralPackage(FuneralPackageDto package) async {
    final response = await _apiClient.post('/v2/funeral/packages', body: package.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return FuneralPackageDto.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
    }
    throw Exception('Failed to create funeral package: ${response.body}');
  }

  Future<FuneralPackageDto> updateFuneralPackage(FuneralPackageDto package) async {
    final response = await _apiClient.put('/v2/funeral/packages/${package.id}', body: package.toJson());
    if (response.statusCode == 200) {
      return FuneralPackageDto.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
    }
    throw Exception('Failed to update funeral package: ${response.body}');
  }

  Future<void> deleteFuneralPackage(String id) async {
    final response = await _apiClient.delete('/v2/funeral/packages/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete funeral package: ${response.body}');
    }
  }

  Future<List<FuneralMembershipCoverDto>> checkMembership(String identityNumber) async {
    final response = await _apiClient.get('/v2/funeral/check-membership/$identityNumber');
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map((e) => FuneralMembershipCoverDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    throw Exception('Failed to check membership: ${response.body}');
  }

  // Funeral Service and Claims
  Future<List<FuneralServiceRequestDto>> getServiceRequests({
    String? query,
    String? status,
  }) async {
    final response = await _apiClient.get(
      '/v2/funeral/service-requests',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map((e) => FuneralServiceRequestDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }
    throw Exception('Failed to load funeral service requests: ${response.body}');
  }

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
      return _decodeList(response.body)
          .map((e) => FuneralClaimDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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

  Future<List<FuneralPaymentSummaryDto>> getFuneralPayments() async {
    final response = await _apiClient.get('/v2/funeral/payments');
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map(
            (item) => FuneralPaymentSummaryDto.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    throw Exception('Failed to load funeral payments: ${response.body}');
  }

  // Invoicing
  Future<List<FuneralInvoicePreviewLineDto>> getInvoicePreview(FuneralInvoicePreviewRequestDto request) async {
    final response = await _apiClient.post('/v2/funeral/invoice-preview', body: request.toJson());
    if (response.statusCode == 200) {
      return _decodeList(response.body)
          .map((e) => FuneralInvoicePreviewLineDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
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
        return _decodeList(response.body)
            .map((e) => PickupRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      // Return empty list if endpoint doesn't exist yet
    }
    return [];
  }

  Future<List<FuneralClaimDto>> initiateClaimsAndReturn(
    String serviceRequestId,
    InitiateFuneralClaimsRequestDto request,
  ) async {
    final response = await _apiClient.post(
      '/v2/funeral/service-request/$serviceRequestId/initiate-claims',
      body: request.toJson(),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) return [];
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => FuneralClaimDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (decoded is Map && decoded['claims'] is List) {
        return (decoded['claims'] as List)
            .map((e) => FuneralClaimDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
    throw Exception('Failed to initiate claims: ${response.body}');
  }

  Future<GenerateFuneralInvoicesResponseDto> generateInvoicesFromPreviewRequest(
    FuneralInvoicePreviewRequestDto request,
  ) {
    return generateInvoices(request.toJson());
  }

  Future<List<PickupRequestDto>> getPickupRequestsBestEffort() {
    return getPickupRequests();
  }

  List<dynamic> _decodeList(String body) {
    final dynamic decoded = body.isEmpty ? [] : jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['content'] is List) return decoded['content'] as List;
    if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
    if (decoded is Map && decoded['items'] is List) return decoded['items'] as List;
    return [];
  }

}
