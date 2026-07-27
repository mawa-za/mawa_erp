import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/leave_request.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveService {
  static final LeaveService _instance = LeaveService._internal();
  factory LeaveService() => _instance;
  LeaveService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<LeaveRequest>> getLeaveRequests({String? status}) async {
    try {
      final response = await _apiClient.get(
        '/v2/leave-request',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded is Map && decoded['content'] is List ? decoded['content'] as List<dynamic> : const []);
        return data
            .whereType<Map>()
            .map((json) => LeaveRequest.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw AppException('Failed to load leave requests (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LeaveRequest> getLeaveRequestById(String id) async {
    final response = await _apiClient.get('/v2/leave-request/$id');
    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw AppException('Failed to load leave request');
  }

  Future<LeaveRequest> createLeaveRequest(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/v2/leave-request', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw AppException('Failed to create leave request');
  }

  Future<LeaveRequest> updateLeaveRequest(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/v2/leave-request/$id', body: data);
    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw AppException('Failed to update leave request');
  }

  Future<void> deleteLeaveRequest(String id) async {
    final response = await _apiClient.delete('/v2/leave-request/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to delete leave request');
    }
  }

  Future<void> submitLeaveRequest(String id) async {
    final response = await _apiClient.put('/v2/leave-request/$id/submit');
    if (response.statusCode != 200) {
      throw AppException('Failed to submit leave request');
    }
  }

  Future<void> approveLeaveRequest(String id) async {
    final response = await _apiClient.put('/v2/leave-request/$id/approve');
    if (response.statusCode != 200) {
      throw AppException('Failed to approve leave request');
    }
  }

  Future<void> rejectLeaveRequest(String id) async {
    final response = await _apiClient.put('/v2/leave-request/$id/reject');
    if (response.statusCode != 200) {
      throw AppException('Failed to reject leave request');
    }
  }

  Future<void> cancelLeaveRequest(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/v2/leave-request/$id/cancel', body: data);
    if (response.statusCode != 200) {
      throw AppException('Failed to cancel leave request');
    }
  }
}
