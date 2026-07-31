import 'dart:convert';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AssetRegisterService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _api.get('/v2/assets/dashboard');
    if (response.statusCode != 200) {
      throw AppException('Failed to load asset summary: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> list({String? query, String? status}) async {
    final response = await _api.get('/v2/assets', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (status != null && status != 'ALL') 'status': status,
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to load assets: ${response.body}');
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
      throw AppException('Failed to create asset: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/v2/assets/$id', body: payload);
    if (response.statusCode != 200) {
      throw AppException('Failed to update asset: ${response.body}');
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
      throw AppException('Failed to assign asset: ${response.body}');
    }
  }

  Future<void> dispose(String id, {required String disposalDate, double proceeds = 0, String? notes}) async {
    final response = await _api.post('/v2/assets/$id/dispose', body: {
      'disposalDate': disposalDate,
      'disposalProceeds': proceeds,
      'notes': notes,
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to dispose asset: ${response.body}');
    }
  }
  Future<List<Map<String, dynamic>>> listReservations({String? query, String? status, DateTime? from, DateTime? to}) async {
    final response = await _api.get('/v2/product-hire/reservations', queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (status != null && status != 'ALL') 'status': status,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to load hire reservations: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> linkedAssets(String productId, {DateTime? startAt, DateTime? endAt}) async {
    final response = await _api.get('/v2/product-hire/services/$productId/assets', queryParameters: {
      if (startAt != null) 'startAt': startAt.toIso8601String(),
      if (endAt != null) 'endAt': endAt.toIso8601String(),
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to load available hire assets: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createReservation({
    required String assetId,
    required String serviceProductId,
    required int quantity,
    required DateTime startAt,
    required DateTime endAt,
    String? sourceReference,
    String? customerPartnerId,
    String? notes,
  }) async {
    final response = await _api.post('/v2/product-hire/reservations', body: {
      'assetId': assetId,
      'serviceProductId': serviceProductId,
      'quantity': quantity,
      'sourceType': 'MANUAL',
      'sourceReference': sourceReference,
      'customerPartnerId': customerPartnerId,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'notes': notes,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to reserve asset: ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> issueReservation(String id, {String condition = 'GOOD', String? notes}) async {
    final response = await _api.post('/v2/product-hire/reservations/$id/issue', body: {
      'condition': condition,
      'notes': notes,
    });
    if (response.statusCode != 200) throw AppException('Failed to issue asset: ${response.body}');
  }

  Future<void> returnReservation(String id, {required String condition, bool lost = false, String? damageNotes, String? notes}) async {
    final response = await _api.post('/v2/product-hire/reservations/$id/return', body: {
      'condition': condition,
      'lost': lost,
      'damageNotes': damageNotes,
      'notes': notes,
    });
    if (response.statusCode != 200) throw AppException('Failed to return asset: ${response.body}');
  }

  Future<void> cancelReservation(String id, {String? notes}) async {
    final response = await _api.post('/v2/product-hire/reservations/$id/cancel', body: {'notes': notes});
    if (response.statusCode != 200) throw AppException('Failed to cancel reservation: ${response.body}');
  }


}
