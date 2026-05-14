import 'dart:convert';
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
        String errorMessage = 'Failed to load memberships (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
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
        throw Exception(error['message'] ?? 'Failed to create membership: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to update membership: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to delete membership: ${response.statusCode}');
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
        String errorMessage = 'Failed to load membership details (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
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
        final List<dynamic> data = decoded is List ? decoded : (decoded['content'] ?? []);
        return data.map((json) => Dependent.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load membership dependents: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addDependent(String membershipId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership/$membershipId/dependents', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to add dependent: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDependent(String membershipId, String dependentId, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().put('/v2/membership/$membershipId/dependents/$dependentId', body: payload);
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update dependent: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Premium>> getMembershipPremiums(String membershipId, {String? oldId}) async {
    try {
      final List<Future<dynamic>> requests = [
        ApiClient().get('/v2/premium?membershipId=$membershipId'),
      ];

      if (oldId != null && oldId.isNotEmpty && oldId != membershipId && oldId != 'null') {
        requests.add(ApiClient().get('/v2/premium?membershipId=$oldId'));
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
            data = decoded['content'];
          } else {
            data = [];
          }

          for (var json in data) {
            final premium = Premium.fromJson(Map<String, dynamic>.from(json));
            if (!seenIds.contains(premium.id)) {
              allPremiums.add(premium);
              seenIds.add(premium.id);
            }
          }
        }
      }
      return allPremiums;
    } catch (e) {
      rethrow;
    }
  }

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
        throw Exception('Failed to load membership plans: ${response.statusCode}');
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
        throw Exception('Failed to load membership plan: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to create membership plan: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createMembershipClaim(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership-claim', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to process claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MembershipClaim>> getMembershipClaims({String? membershipId}) async {
    try {
      String path = '/v2/membership-claim';
      if (membershipId != null && membershipId.isNotEmpty) {
        path += '?membershipId=$membershipId';
      }
      
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MembershipClaim.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load membership claims: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MembershipClaim>> getClaimsByMembership(String membershipId) async {
    try {
      final response = await ApiClient().get('/v2/membership-claim/membership/$membershipId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MembershipClaim.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load membership claims: ${response.statusCode}');
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
        throw Exception('Failed to load membership claim: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to update membership claim: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitMembershipClaim(String id) async {
    try {
      final response = await ApiClient().post('/v2/membership-claim/$id/submit');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to submit membership claim: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to cancel membership claim: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to link claims: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GroupSociety>> getGroupSocieties({String? status, String? societyType}) async {
    try {
      String path = '/v2/group-society';
      final Map<String, dynamic> params = {};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (societyType != null && societyType.isNotEmpty) params['societyType'] = societyType;

      final response = await ApiClient().get(path, queryParameters: params);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroupSociety.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load group societies: ${response.statusCode}');
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
        throw Exception('Failed to load group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createGroupSociety(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create group society: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to update group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> postGroupSocietyUpdate(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGroupSociety(String id) async {
    try {
      final response = await ApiClient().delete('/v2/group-society/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> suspendGroupSociety(String id) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/suspend');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to suspend group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> activateGroupSociety(String id) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/activate');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to activate group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeGroupSociety(String id) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/close');
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to close group society: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GroupSocietyContact>> getGroupSocietyContacts(String id) async {
    try {
      final response = await ApiClient().get('/v2/group-society/$id/contacts');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroupSocietyContact.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to add contact: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<GroupSocietyPayment> addGroupSocietyPayment(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/payments', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return GroupSocietyPayment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to add payment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GroupSocietyPayment>> getGroupSocietyPayments(String id) async {
    try {
      final response = await ApiClient().get('/v2/group-society/$id/payments');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroupSocietyPayment.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load payments: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> debitGroupSocietyClaim(String id, Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/group-society/$id/claims/debit', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to process claim debit: ${response.statusCode}');
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
        throw Exception(error['message'] ?? 'Failed to process adjustment: ${response.statusCode}');
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
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GroupSocietyPayment.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load statement: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<GroupSociety> getGroupSocietyByPartner(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/group-society/by-partner/$partnerId');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return GroupSociety.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Failed to find group society for partner: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<GroupSociety> getGroupSocietyByGroupNo(String groupNo) async {
    try {
      final response = await ApiClient().get('/v2/group-society/by-group-no/$groupNo');
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return GroupSociety.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Failed to find group society for group no: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
