import 'dart:convert';
import '../../core/api_client.dart';
import 'models/partner.dart';
import 'models/partner_identity.dart';

class PartnerService {
  static final PartnerService _instance = PartnerService._internal();
  factory PartnerService() => _instance;
  PartnerService._internal();

  Future<List<Partner>> getPartnersByRole(String role) async {
    try {
      final response = await ApiClient().get('/v2/partner?role=$role');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load partners by role: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PartnerRole>> getPartnerRoles(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId/role');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PartnerRole.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load partner roles: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> savePartnerRoles(String partnerId, List<String> roles) async {
    try {
      final response = await ApiClient().post(
        '/v2/partner/$partnerId/role',
        body: roles,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save partner roles: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PartnerIdentity>> getPartnerIdentities(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId/identity');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PartnerIdentity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load partner identities: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PartnerContact>> getPartnerContacts(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId/contact');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PartnerContact.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load partner contacts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPartnerContact(String partnerId, String type, String value) async {
    try {
      final payload = {
        'partner': partnerId,
        'type': type,
        'value': value,
      };
      final response = await ApiClient().post(
        '/v2/partner/$partnerId/contact',
        body: payload,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add partner contact: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
