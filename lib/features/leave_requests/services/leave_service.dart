import 'dart:convert';

import '../../../core/api_client.dart';
import '../models/leave_request.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveService {
  static final LeaveService _instance = LeaveService._internal();
  factory LeaveService() => _instance;
  LeaveService._internal();

  final ApiClient _api = ApiClient();

  Future<List<LeaveRequest>> getLeaveRequests({String? status}) async {
    final response = await _api.get('/v2/leave-request', queryParameters: {
      if (status != null && status != 'ALL') 'status': status,
    });
    _ensureSuccess(response.statusCode, response.body, 'load leave requests');
    final decoded = jsonDecode(response.body);
    final values = decoded is List ? decoded : (decoded is Map && decoded['content'] is List ? decoded['content'] as List : const []);
    return values.whereType<Map>().map((item) => LeaveRequest.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<LeaveRequest> getLeaveRequestById(String id) async {
    final response = await _api.get('/v2/leave-request/$id');
    _ensureSuccess(response.statusCode, response.body, 'load leave request');
    return LeaveRequest.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<LeaveRequestPreview> preview(Map<String, dynamic> data) async {
    final response = await _api.post('/v2/leave-request/preview', body: data);
    _ensureSuccess(response.statusCode, response.body, 'calculate leave request');
    return LeaveRequestPreview.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<LeaveRequest> createLeaveRequest(Map<String, dynamic> data) async {
    final response = await _api.post('/v2/leave-request', body: data);
    _ensureSuccess(response.statusCode, response.body, 'create leave request');
    return LeaveRequest.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<LeaveRequest> updateLeaveRequest(String id, Map<String, dynamic> data) async {
    final response = await _api.put('/v2/leave-request/$id', body: data);
    _ensureSuccess(response.statusCode, response.body, 'update leave request');
    return LeaveRequest.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<LeaveRequest> submitLeaveRequest(String id) async {
    final response = await _api.put('/v2/leave-request/$id/submit');
    _ensureSuccess(response.statusCode, response.body, 'submit leave request');
    return LeaveRequest.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<LeaveRequest> cancelLeaveRequest(String id, String reason) async {
    final response = await _api.put('/v2/leave-request/$id/cancel', body: {'reason': reason});
    _ensureSuccess(response.statusCode, response.body, 'cancel leave request');
    return LeaveRequest.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<void> deleteLeaveRequest(String id) async {
    final response = await _api.delete('/v2/leave-request/$id');
    _ensureSuccess(response.statusCode, response.body, 'delete leave request');
  }

  Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    final response = await _api.get('/v2/leave-configuration/types', queryParameters: {'activeOnly': true});
    _ensureSuccess(response.statusCode, response.body, 'load leave types');
    final decoded = jsonDecode(response.body);
    return (decoded is List ? decoded : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

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
