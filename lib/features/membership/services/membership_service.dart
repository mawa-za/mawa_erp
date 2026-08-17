import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/membership.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../models/membership_plan.dart';
import '../models/membership_claim.dart';
import '../models/group_society.dart';
import '../models/group_society_contact.dart';
import '../models/group_society_payment.dart';
import '../models/payment_batch_response.dart';
import '../models/receipt_response.dart';
import '../models/membership_change.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class MembershipService {
  static final MembershipService _instance = MembershipService._internal();
  factory MembershipService() => _instance;
  MembershipService._internal();

  Future<PaginatedResponse<Membership>> getMemberships({
    int page = 0,
    int size = 20,
    List<String>? sort,
    String query = '',
    List<String>? memberIds,
    String? status,
  }) async {
    try {
      final bool isSearch = query.isNotEmpty || (memberIds != null && memberIds.isNotEmpty);
      String path = (isSearch ? '/v2/membership' : '/v2/membership/all') + '?page=$page&size=$size';

      if (query.isNotEmpty) {
        path += '&query=${Uri.encodeComponent(query)}';
      }
      if (memberIds != null && memberIds.isNotEmpty) {
        for (var id in memberIds) {
          path += '&memberId=$id';
        }
      }
      if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
        path += '&status=${Uri.encodeComponent(status.toUpperCase())}';
      }
      if (sort != null && sort.isNotEmpty) {
        for (var s in sort) {
          path += '&sort=$s';
        }
      }

      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          return PaginatedResponse<Membership>(
            content: decoded.map((item) => Membership.fromJson(Map<String, dynamic>.from(item))).toList(),
            totalPages: 1,
            totalElements: decoded.length,
            first: true,
            last: true,
            size: decoded.length,
            number: 0,
            numberOfElements: decoded.length,
            empty: decoded.isEmpty,
          );
        }

        return PaginatedResponse<Membership>.fromJson(
          decoded as Map<String, dynamic>,
          (json) => Membership.fromJson(json),
        );
      } else {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'Memberships could not be loaded. Please try again.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> createMembership(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      } else {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to create membership: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMembership(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership/$id', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update membership: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMembership(String id) async {
    try {
      final response = await ApiClient().delete('/v2/membership/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete membership: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipDetail> getMembershipDetail(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership/$id');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return MembershipDetail.fromJson(Map<String, dynamic>.from(decoded.first));
        }
        return MembershipDetail.fromJson(decoded as Map<String, dynamic>);
      } else {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'The membership details could not be loaded. Please try again.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Dependent>> getMembershipDependents(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership/$id/dependents');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        return data.whereType<Map<String, dynamic>>().map((json) => Dependent.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load membership dependents: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipChange> addDependent(String membershipId, Map<String, dynamic> payload) async {
    final response = await ApiClient().post('/v2/membership/$membershipId/dependents', body: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MembershipChange.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_errorMessage(response.body, 'Failed to add dependent: ${response.statusCode}'));
  }

  Future<MembershipChange> replaceDependent(
      String membershipId, String dependentId, Map<String, dynamic> payload) async {
    final response = await ApiClient().put(
      '/v2/membership/$membershipId/dependents/$dependentId',
      body: payload,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MembershipChange.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_errorMessage(response.body, 'Failed to replace dependent: ${response.statusCode}'));
  }

  @Deprecated('Use replaceDependent')
  Future<MembershipChange> updateDependent(
      String membershipId, String dependentId, Map<String, dynamic> payload) {
    return replaceDependent(membershipId, dependentId, payload);
  }

  Future<MembershipChange> removeDependent(
      String membershipId, String dependentId, String reason) async {
    final response = await ApiClient().post(
      '/v2/membership/$membershipId/dependents/$dependentId/remove',
      body: {'reason': reason},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MembershipChange.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_errorMessage(response.body, 'Failed to remove dependent: ${response.statusCode}'));
  }

  @Deprecated('Use removeDependent with a reason')
  Future<MembershipChange> deleteDependent(String membershipId, String dependentId) {
    return removeDependent(membershipId, dependentId, 'Dependent removed');
  }

  String _errorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return '${decoded['message'] ?? decoded['error'] ?? fallback}';
    } catch (_) {}
    return fallback;
  }

  Future<List<Premium>> getMembershipPremiums(String membershipId, {String? oldId}) async {
    try {
      final List<Future<dynamic>> requests = [
        ApiClient().get('/v2/memberships/$membershipId/premiums'),
      ];

      if (oldId != null && oldId.isNotEmpty && oldId != membershipId && oldId != 'null') {
        requests.add(ApiClient().get('/v2/memberships/$oldId/premiums'));
      }

      final responses = await Future.wait(requests);
      final List<Premium> allPremiums = [];
      final Set<String> seenIds = {};

      for (var response in responses) {
        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);

          List<dynamic> data;
          if (decoded is List) {
            data = decoded;
          } else if (decoded is Map && decoded.containsKey('content')) {
            data = decoded['content'] ?? [];
          } else {
            data = [];
          }

          for (var json in data) {
            if (json is Map) {
              final premium = Premium.fromJson(Map<String, dynamic>.from(json));
              if (!seenIds.contains(premium.id)) {
                allPremiums.add(premium);
                seenIds.add(premium.id);
              }
            }
          }
        }
      }
      return allPremiums;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ReceiptResponse>> getPremiumReceipts(
    String membershipId,
    String premiumId,
  ) async {
    final response = await ApiClient().get(
      '/v2/memberships/$membershipId/premiums/$premiumId/receipts',
    );
    if (response.statusCode != 200) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'Unable to load premium receipts.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <ReceiptResponse>[];
    return decoded
        .whereType<Map>()
        .map((item) => ReceiptResponse.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> requestPremiumPaymentEdit({
    required String paymentBatchId,
    required String receiptId,
    required int amountCents,
    required String periodYYYYMM,
    required String requestedBy,
    required String reason,
  }) async {
    final response = await ApiClient().post(
      '/v2/payment-batches/$paymentBatchId/edit-request',
      body: {
        'receiptId': receiptId,
        'amountCents': amountCents,
        'periodYYYYMM': periodYYYYMM,
        'requestedBy': requestedBy,
        'reason': reason,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The premium payment edit request could not be submitted.',
      );
    }
  }

  Future<Map<String, dynamic>> getPendingMembershipStatusChange(String membershipId) async {
    final response = await ApiClient().get('/v2/membership/$membershipId/status-actions/pending');
    if (response.statusCode != 200) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'Pending membership status change could not be loaded.',
      );
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> requestMembershipStatusChange({
    required String membershipId,
    required String action,
    required String requestedBy,
    required String reason,
  }) async {
    final response = await ApiClient().post(
      '/v2/membership/$membershipId/status-actions/${action.toLowerCase()}',
      body: {
        'requestedBy': requestedBy,
        'reason': reason,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The membership status change could not be submitted for approval.',
      );
    }
  }

  Future<void> requestPremiumPaymentDeletion({
    required String paymentBatchId,
    required String requesterId,
    required String reason,
  }) async {
    final response = await ApiClient().post(
      '/v2/payment-batches/$paymentBatchId/deletion-request',
      body: {
        'requesterId': requesterId,
        'reason': reason,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The premium payment deletion request could not be submitted.',
      );
    }
  }

  Future<PaymentBatchResponse> transferManualPremiumPayment({
    required String paymentBatchId,
    required String targetMembershipId,
    required String targetPeriodYYYYMM,
    required String requestedBy,
    required String reason,
  }) async {
    final response = await ApiClient().post(
      '/v2/payment-batches/$paymentBatchId/transfer',
      body: {
        'targetMembershipId': targetMembershipId,
        'targetPeriodYYYYMM': targetPeriodYYYYMM,
        'requestedBy': requestedBy,
        'reason': reason,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: 'The premium payment could not be transferred.',
      );
    }
    return PaymentBatchResponse.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getUnpaidPremiums(String membershipId) async {
    try {
      final response = await ApiClient().get('/v2/memberships/$membershipId/premiums/unpaid');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        throw AppException('Failed to load unpaid premiums: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Membership Plan Methods ---

  Future<PaginatedResponse<MembershipPlan>> getMembershipPlans({int page = 0, int size = 100}) async {
    try {
      final response = await ApiClient().get('/v2/membership/plans?page=$page&size=$size');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          return PaginatedResponse<MembershipPlan>(
            content: decoded.map((item) => MembershipPlan.fromJson(Map<String, dynamic>.from(item))).toList(),
            totalPages: 1,
            totalElements: decoded.length,
            first: true,
            last: true,
            size: decoded.length,
            number: 0,
            numberOfElements: decoded.length,
            empty: decoded.isEmpty,
          );
        }

        return PaginatedResponse<MembershipPlan>.fromJson(
          decoded as Map<String, dynamic>,
          (json) => MembershipPlan.fromJson(json),
        );
      } else {
        throw AppException('Failed to load membership plans: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipPlan> getMembershipPlanById(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership/plans/$id');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return MembershipPlan.fromJson(Map<String, dynamic>.from(decoded.first));
        }
        return MembershipPlan.fromJson(decoded as Map<String, dynamic>);
      } else {
        throw AppException('Failed to load membership plan: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createMembershipPlan(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership/plans', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to create membership plan: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMembershipPlan(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership/plans/$id', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update membership plan: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMembershipPlan(String id) async {
    try {
      final response = await ApiClient().delete('/v2/membership/plans/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete membership plan: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Membership Plan Premium Rules ---

  Future<List<MembershipPlanPremiumRule>> getPremiumRules(String planId) async {
    try {
      final response = await ApiClient().get('/v2/membership/plans/$planId/premium-rule');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.map((item) => MembershipPlanPremiumRule.fromJson(item)).toList();
      } else {
        throw AppException('Failed to load premium rules: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPremiumRule(String planId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership/plans/$planId/premium-rule', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to add premium rule: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePremiumRule(String planId, String ruleId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership/plans/$planId/premium-rule/$ruleId', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update premium rule: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePremiumRule(String planId, String ruleId) async {
    try {
      final response = await ApiClient().delete('/v2/membership/plans/$planId/premium-rule/$ruleId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete premium rule: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Membership Plan Claim Payouts ---

  Future<List<MembershipPlanClaimPayout>> getClaimPayouts(String planId, {bool all = false}) async {
    try {
      final String path = all
          ? '/v2/membership/plans/$planId/claim-payout/all'
          : '/v2/membership/plans/$planId/claim-payout';
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.map((item) => MembershipPlanClaimPayout.fromJson(item)).toList();
      } else {
        throw AppException('Failed to load claim payouts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addClaimPayout(String planId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership/plans/$planId/claim-payout', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to add claim payout: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateClaimPayout(String planId, String payoutId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership/plans/$planId/claim-payout/$payoutId', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update claim payout: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClaimPayout(String planId, String payoutId) async {
    try {
      final response = await ApiClient().delete('/v2/membership/plans/$planId/claim-payout/$payoutId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete claim payout: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Membership Claim Methods ---

  Future<Map<String, dynamic>> createMembershipClaim(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership-claim', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to process claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipClaimPage> getMembershipClaimPage({
    String? status,
    String? query,
    int page = 0,
    int size = 50,
  }) async {
    var path = '/v2/membership-claim/page?page=$page&size=$size';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      path += '&status=${Uri.encodeComponent(status.toUpperCase())}';
    }
    if (query != null && query.trim().isNotEmpty) {
      path += '&query=${Uri.encodeQueryComponent(query.trim())}';
    }

    final response = await ApiClient().get(path);
    if (response.statusCode != 200) {
      throw AppException(_extractErrorMessage(
        response.body,
        'Failed to load membership claims: ${response.statusCode}',
      ));
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const MembershipClaimPage(items: [], page: 0, last: true);
    }
    final map = Map<String, dynamic>.from(decoded);
    final items = (map['content'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => MembershipClaim.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return MembershipClaimPage(
      items: items,
      page: (map['number'] as num?)?.toInt() ?? page,
      last: map['last'] == true,
    );
  }

  Future<List<MembershipClaim>> getMembershipClaims({String? membershipId}) async {
    try {
      String path = '/v2/membership-claim';

      if (membershipId != null && membershipId.isNotEmpty) {
        path += '?membershipId=$membershipId';
      }

      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        return data.whereType<Map<String, dynamic>>().map((json) => MembershipClaim.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load membership claims: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MembershipClaim>> getClaimsByMembership(String membershipId) async {
    try {
      final response = await ApiClient().get('/v2/membership-claim/membership/$membershipId');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        return data.whereType<Map<String, dynamic>>().map((json) => MembershipClaim.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load membership claims: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipClaim> getMembershipClaimById(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership-claim/$id');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return MembershipClaim.fromJson(Map<String, dynamic>.from(decoded.first));
        }
        return MembershipClaim.fromJson(decoded as Map<String, dynamic>);
      } else {
        throw AppException('Failed to load membership claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMembershipClaim(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership-claim/$id', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update membership claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> downloadMembershipClaimForm(String id) async {
    final response = await ApiClient().get('/v2/membership-claim/$id/claim-form');
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw AppException.fromHttp(
      statusCode: response.statusCode,
      responseBody: response.body,
      fallback: 'The claim form could not be generated. Please try again.',
    );
  }

  Future<void> submitMembershipClaim(String id) async {
    try {
      final response = await ApiClient().post('/v2/membership-claim/$id/submit');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to submit membership claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelMembershipClaim(String id) async {
    try {
      final response = await ApiClient().post('/v2/membership-claim/$id/cancel');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to cancel membership claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> linkClaims(String parentClaimId, List<String> claimIds) async {
    try {
      final response = await ApiClient().post(
        '/v2/membership-claim/$parentClaimId/linked-claims',
        body: {'claimIds': claimIds},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to link claims: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> detachClaim(String parentClaimId, String linkedClaimId) async {
    try {
      final response = await ApiClient().delete('/v2/membership-claim/$parentClaimId/linked-claims/$linkedClaimId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to detach claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Group Society Methods ---

  Future<List<GroupSociety>> getGroupSocieties({String? status, String? societyType}) async {
    try {
      String path = '/v2/group-society';
      final Map<String, dynamic> params = {};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (societyType != null && societyType.isNotEmpty) params['societyType'] = societyType;

      final response = await ApiClient().get(path, queryParameters: params);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }

        return data.whereType<Map<String, dynamic>>().map((json) => GroupSociety.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load group societies: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<GroupSociety> getGroupSocietyById(String id) async {
    try {
      final response = await ApiClient().get('/v2/group-society/$id');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return GroupSociety.fromJson(Map<String, dynamic>.from(decoded.first));
        }
        return GroupSociety.fromJson(decoded as Map<String, dynamic>);
      } else {
        throw AppException('Failed to load group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createGroupSociety(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to create group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateGroupSociety(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/group-society/$id', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to update group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Backwards-compatible helper used by the group society detail screen.
  ///
  /// The backend update endpoint is PUT /v2/group-society/{id}; older UI code
  /// calls this method name, so keep the alias here instead of changing screens.
  Future<void> postGroupSocietyUpdate(String id, Map<String, dynamic> payload) async {
    await updateGroupSociety(id, payload);
  }

  Future<void> deleteGroupSociety(String id) async {
    try {
      final response = await ApiClient().delete('/v2/group-society/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> suspendGroupSociety(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/suspend', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to suspend group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> activateGroupSociety(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/activate', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to activate group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeGroupSociety(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/close', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to close group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GroupSocietyContact>> getGroupSocietyContacts(String id) async {
    try {
      final response = await ApiClient().get('/v2/group-society/$id/contacts');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        return data.whereType<Map<String, dynamic>>().map((json) => GroupSocietyContact.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addGroupSocietyContact(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/contacts', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to add contact: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGroupSocietyContact(String contactId) async {
    try {
      final response = await ApiClient().delete('/v2/group-society/contacts/$contactId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to delete contact: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentBatchResponse> addGroupSocietyPayment(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/payments', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentBatchResponse.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to add payment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> adjustGroupSocietyBalance(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/adjustments', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw AppException(error['message'] ?? 'Failed to process adjustment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GroupSocietyPayment>> getGroupSocietyStatement(String id, {String? period}) async {
    try {
      String path = '/v2/group-society/$id/statement';
      if (period != null && period.isNotEmpty) {
        path += '?period=$period';
      }
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else {
          data = [];
        }
        return data.whereType<Map<String, dynamic>>().map((json) => GroupSocietyPayment.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load statement: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getGroupSocietyAttachmentIds(String id) async {
    final response = await ApiClient().get('/v2/attachment', queryParameters: {'objectId': id});
    if (response.statusCode != 200) {
      throw AppException('Unable to load group society documents: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final List<dynamic> data = decoded is List
        ? decoded
        : decoded is Map && decoded['content'] is List
            ? decoded['content'] as List
            : const [];
    return data
        .whereType<Map>()
        .map((item) => (item['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<Uint8List> downloadGroupSocietyAgreement(String id) async {
    final response = await ApiClient().get(
      '/v2/group-society/$id/agreement',
      accept: 'application/pdf',
    );
    if (response.statusCode != 200) {
      throw AppException('Unable to generate the group society agreement: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<GroupSociety?> getGroupSocietyByPartner(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/group-society/by-partner/$partnerId');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return GroupSociety.fromJson(Map<String, dynamic>.from(data));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw AppException('Failed to find group society for partner: ${response.statusCode}');
      }
    } catch (e) {
      return null;
    }
  }

  Future<GroupSociety> getGroupSocietyByGroupNo(String groupNo) async {
    try {
      final response = await ApiClient().get('/v2/group-society/by-group-no/$groupNo');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return GroupSociety.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw AppException('Failed to find group society for group no: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Membership Premium Payment Methods ---

  Future<PaymentBatchResponse> createMembershipPremiumPayment({
    required String membershipId,
    required String paymentMethod,
    required int amountCents,
    required String createdBy,
    String? periodYYYYMM,
    String? deviceId,
    String? terminalId,
    String? location,
    String? employeeResponsible,
    String? notes,
  }) async {
    try {
      final payload = {
        'membershipId': membershipId,
        'paymentMethod': paymentMethod,
        'amountCents': amountCents,
        'periodYYYYMM': periodYYYYMM,
        'createdBy': createdBy,
        'deviceId': deviceId,
        'terminalId': terminalId,
        'location': location,
        'employeeResponsible': employeeResponsible,
        'notes': notes,
      };

      final response = await ApiClient().post('/v2/payment-batches/membership-premiums', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentBatchResponse.fromJson(jsonDecode(response.body));
      } else {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'The membership premium payment could not be created. Please try again.',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentBatchResponse> captureManualPremiumReceipt({
    required String membershipId,
    required int amountCents,
    required String paymentMethod,
    required String periodYYYYMM,
    required DateTime originalReceiptDate,
    required String manualReceiptNo,
    required String captureMode,
    required String createdBy,
    required String originalCollectorEmployeeId,
    required String locationAreaCode,
    String? lateCaptureReason,
    String? proofAttachmentId,
    String? notes,
  }) async {
    final payload = {
      'membershipId': membershipId,
      'amountCents': amountCents,
      'paymentMethod': paymentMethod,
      'periodYYYYMM': periodYYYYMM,
      'originalReceiptDate': originalReceiptDate.toIso8601String().substring(0, 10),
      'manualReceiptNo': manualReceiptNo,
      'captureMode': captureMode,
      'createdBy': createdBy,
      'originalCollectorEmployeeId': originalCollectorEmployeeId,
      'locationAreaCode': locationAreaCode,
      'lateCaptureReason': lateCaptureReason,
      'proofAttachmentId': proofAttachmentId,
      'notes': notes,
    };
    final response = await ApiClient().post('/v2/payment-batches/membership-premiums/manual-receipts', body: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PaymentBatchResponse.fromJson(jsonDecode(response.body));
    }
    throw AppException(_extractErrorMessage(response.body, 'Failed to capture manual receipt (${response.statusCode})'));
  }

  Future<void> printReceipt(String receiptId) async {
    try {
      final response = await ApiClient().get('/v2/receipts/$receiptId/print');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw AppException('Failed to print receipt: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MembershipClaim>> getClaimsByType(String claimType) async {
    return _getMembershipClaimList('/v2/membership-claim/type/${Uri.encodeComponent(claimType)}');
  }

  Future<List<MembershipClaim>> getClaimsByStatus(String status) async {
    return _getMembershipClaimList('/v2/membership-claim/status/${Uri.encodeComponent(status)}');
  }

  Future<List<MembershipClaim>> getClaimsByDeceasedPartner(String deceasedPartnerId) async {
    return _getMembershipClaimList('/v2/membership-claim/deceased-partner/${Uri.encodeComponent(deceasedPartnerId)}');
  }

  Future<MembershipClaim> getMembershipClaimByClaimNo(String claimNo) async {
    try {
      final response = await ApiClient().get('/v2/membership-claim/claim-no/${Uri.encodeComponent(claimNo)}');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return MembershipClaim.fromJson(Map<String, dynamic>.from(decoded.first as Map));
        }
        return MembershipClaim.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
      throw AppException(_extractErrorMessage(response.body, 'Failed to load membership claim: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MembershipClaim>> _getMembershipClaimList(String path) async {
    try {
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        return _decodeList(response.body)
            .map((json) => MembershipClaim.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      throw AppException(_extractErrorMessage(response.body, 'Failed to load membership claims: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentBatchResponse> syncOfflineMembershipPremiumPayment(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/sync/payment-batches/membership-premiums', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentBatchResponse.fromJson(jsonDecode(response.body));
      }
      throw AppException(_extractErrorMessage(response.body, 'Failed to sync membership premium payment: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> migrateMemberships() async {
    try {
      final response = await ApiClient().get('/v2/membership/migrate');
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      }
      throw AppException(_extractErrorMessage(response.body, 'Failed to migrate memberships: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  List<dynamic> _decodeList(String body) {
    final dynamic decoded = body.isEmpty ? [] : jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['content'] is List) return decoded['content'] as List;
    if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
    return [];
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      if (body.isEmpty) return fallback;
      final dynamic error = jsonDecode(body);
      if (error is Map) {
        return (error['message'] ?? error['error'] ?? fallback).toString();
      }
    } catch (_) {}
    return fallback;
  }
  Future<List<MembershipChange>> getMembershipChanges(String membershipId) async {
    final response = await ApiClient().get('/v2/membership-changes/$membershipId');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rows = decoded is List ? decoded : <dynamic>[];
      return rows.map((item) => MembershipChange.fromJson(Map<String, dynamic>.from(item))).toList();
    }
    throw AppException(_extractMessage(response.body, 'Failed to load membership changes'));
  }

  Future<List<MembershipChangeAudit>> getMembershipChangeAudit(String membershipId) async {
    final response = await ApiClient().get('/v2/membership-changes/$membershipId/audit');
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rows = decoded is List ? decoded : <dynamic>[];
      return rows.map((item) => MembershipChangeAudit.fromJson(Map<String, dynamic>.from(item))).toList();
    }
    throw AppException(_extractMessage(response.body, 'Failed to load membership audit trail'));
  }

  Future<MembershipChangeConfiguration> getMembershipChangeConfiguration() async {
    final response = await ApiClient().get('/v2/membership-changes/configuration');
    if (response.statusCode == 200) {
      return MembershipChangeConfiguration.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_extractMessage(response.body, 'Failed to load membership change configuration'));
  }

  Future<void> updateMembershipChangeConfiguration(int months) async {
    final response = await ApiClient().put('/v2/membership-changes/configuration', body: {
      'planChangeWaitingPeriodMonths': months,
    });
    if (response.statusCode != 200) {
      throw AppException(_extractMessage(response.body, 'Failed to update membership change configuration'));
    }
  }

  Future<MembershipChange> requestMembershipTransfer(String membershipId, String newMemberId, String reason) async {
    final response = await ApiClient().post('/v2/membership-changes/$membershipId/transfer', body: {
      'newMemberId': newMemberId,
      'reason': reason,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MembershipChange.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_extractMessage(response.body, 'Failed to submit membership transfer'));
  }

  Future<MembershipChange> requestMembershipPlanChange(String membershipId, String newPlanId, String reason) async {
    final response = await ApiClient().post('/v2/membership-changes/$membershipId/plan', body: {
      'newPlanId': newPlanId,
      'reason': reason,
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MembershipChange.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException(_extractMessage(response.body, 'Failed to submit membership plan change'));
  }

  String _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return '${decoded['message'] ?? decoded['error'] ?? fallback}';
    } catch (_) {}
    return fallback;
  }


}

class MembershipClaimPage {
  final List<MembershipClaim> items;
  final int page;
  final bool last;

  const MembershipClaimPage({
    required this.items,
    required this.page,
    required this.last,
  });


}
