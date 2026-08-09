import 'dart:convert';

import '../../../core/api_client.dart';
import '../models/number_range_configuration.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class NumberRangeConfigurationService {
  final ApiClient _api = ApiClient();

  Future<List<NumberSequenceConfiguration>> getSequences({String? query}) async {
    final response = await _api.get(
      '/v2/number-range-configuration/sequences',
      queryParameters: {if (query != null && query.trim().isNotEmpty) 'query': query.trim()},
    );
    _ensureSuccess(response.statusCode, response.body, 'load number sequences');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => NumberSequenceConfiguration.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<NumberSequenceConfiguration> createSequence(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/number-range-configuration/sequences', body: body);
    _ensureSuccess(response.statusCode, response.body, 'create number sequence');
    return NumberSequenceConfiguration.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<NumberSequenceConfiguration> updateSequence(int id, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/number-range-configuration/sequences/$id', body: body);
    _ensureSuccess(response.statusCode, response.body, 'update number sequence');
    return NumberSequenceConfiguration.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<List<DocumentNumberRangeConfiguration>> getDocumentRanges({String? query}) async {
    final response = await _api.get(
      '/v2/number-range-configuration/document-ranges',
      queryParameters: {if (query != null && query.trim().isNotEmpty) 'query': query.trim()},
    );
    _ensureSuccess(response.statusCode, response.body, 'load document number ranges');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => DocumentNumberRangeConfiguration.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<DocumentNumberRangeConfiguration> createDocumentRange(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/number-range-configuration/document-ranges', body: body);
    _ensureSuccess(response.statusCode, response.body, 'create document number range');
    return DocumentNumberRangeConfiguration.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<DocumentNumberRangeConfiguration> updateDocumentRange(int id, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/number-range-configuration/document-ranges/$id', body: body);
    _ensureSuccess(response.statusCode, response.body, 'update document number range');
    return DocumentNumberRangeConfiguration.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<List<NumberRangeAllocationRecord>> getAllocations({String? seqType, String? deviceId}) async {
    final response = await _api.get(
      '/v2/number-range-configuration/allocations',
      queryParameters: {
        if (seqType != null && seqType.trim().isNotEmpty) 'seqType': seqType.trim(),
        if (deviceId != null && deviceId.trim().isNotEmpty) 'deviceId': deviceId.trim(),
      },
    );
    _ensureSuccess(response.statusCode, response.body, 'load allocated ranges');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => NumberRangeAllocationRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<NumberRangeAuditRecord>> getAudit({String? sourceType, String? rangeKey}) async {
    final response = await _api.get(
      '/v2/number-range-configuration/audit',
      queryParameters: {
        if (sourceType != null && sourceType.trim().isNotEmpty) 'sourceType': sourceType.trim(),
        if (rangeKey != null && rangeKey.trim().isNotEmpty) 'rangeKey': rangeKey.trim(),
      },
    );
    _ensureSuccess(response.statusCode, response.body, 'load number range audit');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => NumberRangeAuditRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  void _ensureSuccess(int statusCode, String body, String action) {
    if (statusCode >= 200 && statusCode < 300) return;
    String message = body.trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) message = decoded['message'].toString();
    } catch (_) {
      // Use the response body when it is not JSON.
    }
    throw AppException(message.isEmpty ? 'Failed to $action' : message);
  }
}
