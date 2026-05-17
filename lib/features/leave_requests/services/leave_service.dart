import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/leave_request.dart';

class LeaveService {
  static final LeaveService _instance = LeaveService._internal();
  factory LeaveService() => _instance;
  LeaveService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<LeaveRequest>> getLeaveRequests({String? status}) async {
    try {
      final response = await _apiClient.get(
        '/leave-request',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LeaveRequest.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load leave requests');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LeaveRequest> getLeaveRequestById(String id) async {
    final response = await _apiClient.get('/leave-request/$id');
    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load leave request');
  }

  Future<LeaveRequest> createLeaveRequest(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/leave-request', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create leave request');
  }

  Future<LeaveRequest> updateLeaveRequest(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/leave-request/$id', body: data);
    if (response.statusCode == 200) {
      return LeaveRequest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update leave request');
  }

  Future<void> deleteLeaveRequest(String id) async {
    final response = await _apiClient.delete('/leave-request/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete leave request');
    }
  }

  Future<void> submitLeaveRequest(String id) async {
    final response = await _apiClient.put('/leave-request/$id/submit');
    if (response.statusCode != 200) {
      throw Exception('Failed to submit leave request');
    }
  }

  Future<void> approveLeaveRequest(String id) async {
    final response = await _apiClient.put('/leave-request/$id/approve');
    if (response.statusCode != 200) {
      throw Exception('Failed to approve leave request');
    }
  }

  Future<void> rejectLeaveRequest(String id) async {
    final response = await _apiClient.put('/leave-request/$id/reject');
    if (response.statusCode != 200) {
      throw Exception('Failed to reject leave request');
    }
  }

  Future<void> cancelLeaveRequest(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/leave-request/$id/cancel', body: data);
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel leave request');
    }
  }
}
