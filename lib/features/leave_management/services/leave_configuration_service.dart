import 'dart:convert';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveConfigurationService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> leaveTypes({bool activeOnly = false}) =>
      _getList('/v2/leave-configuration/types', query: {'activeOnly': activeOnly});

  Future<Map<String, dynamic>> saveLeaveType(Map<String, dynamic> value) async {
    final id = value['id']?.toString();
    return _save(id == null || id.isEmpty ? '/v2/leave-configuration/types' : '/v2/leave-configuration/types/$id', value, create: id == null || id.isEmpty);
  }

  Future<void> deactivateLeaveType(String id) async {
    final response = await _api.delete('/v2/leave-configuration/types/$id');
    _ensure(response.statusCode, response.body, 'deactivate leave type');
  }

  Future<List<Map<String, dynamic>>> calendars() => _getList('/v2/leave-configuration/calendars');

  Future<Map<String, dynamic>> saveCalendar(Map<String, dynamic> value) async {
    final id = value['id']?.toString();
    return _save(id == null || id.isEmpty ? '/v2/leave-configuration/calendars' : '/v2/leave-configuration/calendars/$id', value, create: id == null || id.isEmpty);
  }

  Future<List<Map<String, dynamic>>> profiles() => _getList('/v2/leave-configuration/profiles');

  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> value) async {
    final id = value['id']?.toString();
    return _save(id == null || id.isEmpty ? '/v2/leave-configuration/profiles' : '/v2/leave-configuration/profiles/$id', value, create: id == null || id.isEmpty);
  }

  Future<List<Map<String, dynamic>>> employeeAssignments({String? employmentId}) =>
      _getList('/v2/leave-configuration/employee-assignments', query: {if (employmentId != null) 'employmentId': employmentId});

  Future<Map<String, dynamic>> assignEmployee(Map<String, dynamic> value) =>
      _post('/v2/leave-configuration/employee-assignments', value, 'assign employee leave profile');

  Future<List<Map<String, dynamic>>> positionAssignments() =>
      _getList('/v2/leave-configuration/position-assignments');

  Future<Map<String, dynamic>> assignPosition(Map<String, dynamic> value) =>
      _post('/v2/leave-configuration/position-assignments', value, 'assign position leave profile');

  Future<List<Map<String, dynamic>>> balances({String? employmentId}) =>
      _getList('/v2/leave-balance', query: {if (employmentId != null && employmentId.isNotEmpty) 'employmentId': employmentId});

  Future<List<Map<String, dynamic>>> ledger(String employmentId) =>
      _getList('/v2/leave-balance/ledger', query: {'employmentId': employmentId});

  Future<List<Map<String, dynamic>>> adjustments() => _getList('/v2/leave-balance/adjustments');

  Future<Map<String, dynamic>> requestAdjustment(Map<String, dynamic> value) =>
      _post('/v2/leave-balance/adjustments', value, 'submit leave balance adjustment');

  Future<List<Map<String, dynamic>>> _getList(String path, {Map<String, dynamic>? query}) async {
    final response = await _api.get(path, queryParameters: query);
    _ensure(response.statusCode, response.body, 'load leave configuration');
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _save(String path, Map<String, dynamic> value, {required bool create}) async {
    final response = create ? await _api.post(path, body: value) : await _api.put(path, body: value);
    _ensure(response.statusCode, response.body, 'save leave configuration');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> value, String action) async {
    final response = await _api.post(path, body: value);
    _ensure(response.statusCode, response.body, action);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  void _ensure(int statusCode, String body, String action) {
    if (statusCode >= 200 && statusCode < 300) return;
    String message = body.trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) message = decoded['message'].toString();
    } catch (_) {
      // Preserve non-JSON body.
    }
    throw AppException(message.isEmpty ? 'Failed to $action' : message);
  }
}
