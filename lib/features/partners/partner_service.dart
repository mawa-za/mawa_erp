import 'dart:convert';
import '../../core/api_client.dart';
import 'models/partner.dart';
import 'models/partner_identity.dart';

class PartnerService {
  static final PartnerService _instance = PartnerService._internal();
  factory PartnerService() => _instance;
  PartnerService._internal();

  final ApiClient _apiClient = ApiClient();

  // --- Core Partner Operations ---

  Future<Partner> getPartnerById(String id) async {
    try {
      final response = await _apiClient.get('/v2/partner/$id');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return Partner.fromJson(Map<String, dynamic>.from(decoded.first));
        }
        return Partner.fromJson(decoded as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load partner: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Partner>> getPartners({String? query, String? role}) async {
    try {
      final Map<String, dynamic> params = {};
      if (query != null && query.isNotEmpty) params['query'] = query;
      if (role != null && role.isNotEmpty) params['role'] = role;

      final response = await _apiClient.get('/v2/partner', queryParameters: params);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => Partner.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load partners: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Partner> createPartner(Map<String, dynamic> partnerInboundDto) async {
    try {
      final response = await _apiClient.post('/v2/partner', body: partnerInboundDto);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Partner.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create partner: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Partner> editPartner(String id, Map<String, dynamic> partnerEditDto) async {
    try {
      final response = await _apiClient.put('/v2/partner/$id', body: partnerEditDto);
      if (response.statusCode == 200) {
        return Partner.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to edit partner: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archivePartner(String id) async {
    try {
      final response = await _apiClient.put('/v2/partner/$id/archive');
      if (response.statusCode != 200) {
        throw Exception('Failed to archive partner: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unarchivePartner(String id) async {
    try {
      final response = await _apiClient.put('/v2/partner/$id/unarchive');
      if (response.statusCode != 200) {
        throw Exception('Failed to unarchive partner: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Identity Management ---

  Future<List<PartnerIdentity>> getPartnerIdentities(String partnerId) async {
    try {
      final response = await _apiClient.get('/v2/partner/$partnerId/identity');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => PartnerIdentity.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load partner identities: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPartnerIdentity(String id, Map<String, dynamic> identityCreateDto) async {
    try {
      final response = await _apiClient.post('/v2/partner/$id/identity', body: identityCreateDto);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add identity: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> editPartnerIdentity(String id, Map<String, dynamic> identityEditDto) async {
    try {
      final response = await _apiClient.put('/v2/partner/$id/identity', body: identityEditDto);
      if (response.statusCode != 200) {
        throw Exception('Failed to edit identity: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Global search by identity
  Future<PartnerIdentity?> getIdentity(String idType, String idNumber) async {
    try {
      final response = await _apiClient.get('/v2/partner/identity', queryParameters: {
        'idType': idType,
        'idNumber': idNumber,
      });
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        return PartnerIdentity.fromJson(decoded as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteIdentity(String idType, String idNumber) async {
    try {
      final response = await _apiClient.delete('/v2/partner/identity', queryParameters: {
        'idType': idType,
        'idNumber': idNumber,
      });
      if (response.statusCode != 200) {
        throw Exception('Failed to delete identity: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> validateIdentity(String id, String type) async {
    try {
      final response = await _apiClient.get('/validate/identity/$id', queryParameters: {'type': type});
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Contact Management ---

  Future<List<PartnerContact>> getPartnerContacts(String partnerId, {String? value, String? type}) async {
    try {
      final response = await _apiClient.get('/v2/partner/$partnerId/contact', queryParameters: {
        if (value != null) 'value': value,
        if (type != null) 'type': type,
      });
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => PartnerContact.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load partner contacts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Global contact search
  Future<List<PartnerContact>> getPartnersContact({String? value, String? type}) async {
    try {
      final response = await _apiClient.get('/v2/partner/contact', queryParameters: {
        if (value != null) 'value': value,
        if (type != null) 'type': type,
      });
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => PartnerContact.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPartnerContact(String id, Map<String, dynamic> contactCreateDto) async {
    try {
      final response = await _apiClient.post('/v2/partner/$id/contact', body: contactCreateDto);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add contact: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> editPartnerContact(String id, String contactType, Map<String, dynamic> contactEditDto) async {
    try {
      final response = await _apiClient.put(
        '/v2/partner/$id/contact',
        queryParameters: {'contactType': contactType},
        body: contactEditDto,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to edit contact: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteContact(String id, String type) async {
    try {
      final response = await _apiClient.delete(
        '/v2/partner/$id/contact',
        queryParameters: {'type': type},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete contact: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Attribute Management ---

  Future<List<PartnerAttribute>> getAttributes(String id) async {
    try {
      final response = await _apiClient.get('/v2/partner/$id/attribute');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => PartnerAttribute.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load attributes: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addPartnerAttribute(String id, Map<String, dynamic> attributeCreateDto) async {
    try {
      final response = await _apiClient.post('/v2/partner/$id/attribute', body: attributeCreateDto);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add attribute: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> editAttribute(String id, String attribute, Map<String, dynamic> attributeEditDto) async {
    try {
      final response = await _apiClient.put(
        '/v2/partner/$id/attribute',
        queryParameters: {'attribute': attribute},
        body: attributeEditDto,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to edit attribute: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeAttribute(String id, String attribute) async {
    try {
      final response = await _apiClient.delete(
        '/v2/partner/$id/attribute',
        queryParameters: {'attribute': attribute},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove attribute: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Role Management ---

  Future<List<PartnerRole>> getPartnerRoles(String partnerId) async {
    try {
      final response = await _apiClient.get('/v2/partner/$partnerId/role');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => PartnerRole.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load partner roles: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignPartnerRoles(String id, List<String> roles) async {
    try {
      final response = await _apiClient.post('/v2/partner/$id/role', body: roles);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to assign roles: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePartnerRole(String id, String role) async {
    try {
      final response = await _apiClient.delete(
        '/v2/partner/$id/role',
        queryParameters: {'role': role},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete role: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
