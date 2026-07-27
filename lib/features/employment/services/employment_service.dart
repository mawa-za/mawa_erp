import 'dart:convert';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class EmploymentService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> list({String? status, String? query}) async {
    final response = await _api.get('/v2/employment', queryParameters: {
      if (status != null && status != 'ALL') 'status': status,
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to load employee records: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    final values = decoded is List ? decoded : const <dynamic>[];
    final rows = values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final term = (query ?? '').trim().toLowerCase();
    if (term.isEmpty) return rows;
    return rows.where((row) {
      final employee = row['employee'] is Map
          ? Map<String, dynamic>.from(row['employee'] as Map)
          : const <String, dynamic>{};
      final haystack = [
        row['employeeNumber'],
        row['position'],
        employee['number'],
        employee['name1'],
        employee['name2'],
        employee['name3'],
        employee['identityNumber'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(term);
    }).toList();
  }

  Future<String> hire(Map<String, dynamic> payload) async {
    final response = await _api.post('/v2/employment', body: payload);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to hire employee: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return (decoded['id'] ?? '').toString();
    return '';
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/v2/employment/$id', body: payload);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to update employee record: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getBankDetails(String employmentId) async {
    final response = await _api.get('/v2/employment/$employmentId/bank-details');
    if (response.statusCode != 200) {
      throw AppException('Failed to load employee banking details: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['partnerBankAccountDtoList'] is! List) return const [];
    return (decoded['partnerBankAccountDtoList'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> submitBankDetails(String employmentId, Map<String, dynamic> payload) async {
    final response = await _api.post(
      '/v2/employment/$employmentId/bank-details/submit-for-approval',
      body: payload,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to submit employee banking details: ${response.body}');
    }
  }

  Future<void> terminate(String id) async {
    final response = await _api.put('/v2/employment/$id/terminate');
    if (response.statusCode != 200) {
      throw AppException('Failed to terminate employee: ${response.body}');
    }
  }

  Future<void> rehire(String id, {required String startDate, String? endDate}) async {
    final response = await _api.put('/v2/employment/$id/rehire', queryParameters: {
      'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
    if (response.statusCode != 200) {
      throw AppException('Failed to rehire employee: ${response.body}');
    }
  }
}
