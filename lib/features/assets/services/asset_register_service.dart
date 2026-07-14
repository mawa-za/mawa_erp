import 'dart:convert';

import '../../../core/api_client.dart';

class AssetRegisterService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _api.get('/v2/assets/dashboard');
    if (response.statusCode != 200) {
      throw Exception('Failed to load asset summary: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> list({String? query, String? status}) async {
    final response = await _api.get('/v2/assets', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (status != null && status != 'ALL') 'status': status,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to load assets: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final response = await _api.post('/v2/assets', body: payload);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create asset: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/v2/assets/$id', body: payload);
    if (response.statusCode != 200) {
      throw Exception('Failed to update asset: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> assign(String id, {String? partnerId, String? location, String? notes}) async {
    final response = await _api.post('/v2/assets/$id/assign', body: {
      'custodianPartnerId': partnerId,
      'location': location,
      'notes': notes,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to assign asset: ${response.body}');
    }
  }

  Future<void> dispose(String id, {required String disposalDate, double proceeds = 0, String? notes}) async {
    final response = await _api.post('/v2/assets/$id/dispose', body: {
      'disposalDate': disposalDate,
      'disposalProceeds': proceeds,
      'notes': notes,
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to dispose asset: ${response.body}');
    }
  }
}
