import 'dart:convert';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class EmploymentService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> list({String? status, String? query}) async {
    final response = await _api.get('/v2/employment', queryParameters: {
      if (status != null && status != 'ALL') 'status': status,
    });
    _ensureSuccess(response.statusCode, response.body, 'load employee records');
    final decoded = jsonDecode(response.body);
    final rows = (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final term = (query ?? '').trim().toLowerCase();
    if (term.isEmpty) return rows;
    return rows.where((row) {
      final employee = _map(row['employee']);
      return [
        row['employeeNumber'],
        row['position'],
        row['positionDescription'],
        row['status'],
        employee['number'],
        employee['name1'],
        employee['name2'],
        employee['name3'],
        employee['identityNumber'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ').contains(term);
    }).toList();
  }

  Future<Map<String, dynamic>> requestHire(Map<String, dynamic> payload) async {
    final response = await _api.post('/v2/employment/actions/hire', body: payload);
    _ensureSuccess(response.statusCode, response.body, 'submit hire request');
    return _decodeMap(response.body);
  }

  Future<Map<String, dynamic>> requestAction(
    String employmentId,
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.post(
      '/v2/employment/$employmentId/actions/${actionType.toLowerCase()}',
      body: payload,
    );
    _ensureSuccess(response.statusCode, response.body, 'submit employment action');
    return _decodeMap(response.body);
  }

  Future<List<Map<String, dynamic>>> listActions({String? status, String? actionType}) async {
    final response = await _api.get('/v2/employment/actions', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (actionType != null && actionType.isNotEmpty) 'actionType': actionType,
    });
    _ensureSuccess(response.statusCode, response.body, 'load employment actions');
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> history({String? employmentId}) async {
    final response = await _api.get('/v2/employment/history', queryParameters: {
      if (employmentId != null && employmentId.isNotEmpty) 'employmentId': employmentId,
    });
    _ensureSuccess(response.statusCode, response.body, 'load employment history');
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/v2/employment/$id', body: payload);
    _ensureSuccess(response.statusCode, response.body, 'update employee record');
  }

  Future<List<Map<String, dynamic>>> getBankDetails(String employmentId) async {
    final response = await _api.get('/v2/employment/$employmentId/bank-details');
    _ensureSuccess(response.statusCode, response.body, 'load employee banking details');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['partnerBankAccountDtoList'] is! List) return const [];
    return (decoded['partnerBankAccountDtoList'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> submitBankDetails(String employmentId, Map<String, dynamic> payload) async {
    final response = await _api.post(
      '/v2/employment/$employmentId/bank-details/submit-for-approval',
      body: payload,
    );
    _ensureSuccess(response.statusCode, response.body, 'submit employee banking details');
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  void _ensureSuccess(int statusCode, String body, String action) {
    if (statusCode >= 200 && statusCode < 300) return;
    String message = body.trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) message = decoded['message'].toString();
    } catch (_) {
      // Preserve non-JSON response text.
    }
    throw AppException(message.isEmpty ? 'Failed to $action' : message);
  }
}
