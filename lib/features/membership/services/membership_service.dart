import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/membership.dart';
import '../models/membership_detail.dart';
import '../models/dependent.dart';
import '../models/premium.dart';

class MembershipService {
  static final MembershipService _instance = MembershipService._internal();
  factory MembershipService() => _instance;
  MembershipService._internal();

  Future<List<Membership>> getMemberships() async {
    try {
      final response = await ApiClient().get('/v2/membership');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Membership.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load memberships: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createMembership(Map<String, dynamic> payload) async {
    try {
      final response = await ApiClient().post('/v2/membership', body: payload);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create membership: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<MembershipDetail> getMembershipDetail(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership/$id');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return MembershipDetail.fromJson(data);
      } else {
        throw Exception('Failed to load membership details: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Dependent>> getMembershipDependents(String id) async {
    try {
      final response = await ApiClient().get('/v2/membership/$id/dependent');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Dependent.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load membership dependents: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Premium>> getMembershipPremiums(String membershipId) async {
    try {
      final response = await ApiClient().get('/v2/premium?membershipId=$membershipId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Premium.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load paid premiums: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
