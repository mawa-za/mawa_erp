import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/membership.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';
import '../models/membership_plan.dart';

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
        
        // Handle List response by wrapping it in a PaginatedResponse
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
        
        // Handle Map (Paginated) response
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

      if (oldId != null && oldId.isNotEmpty) {
        requests.add(ApiClient().get('/v2/premium?membershipId=$oldId'));
      }

      final responses = await Future.wait(requests);
      final List<Premium> allPremiums = [];
      final Set<String> seenIds = {};

      for (var response in responses) {
        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          final List<dynamic> data = decoded is List ? decoded : (decoded['content'] ?? []);
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
}
