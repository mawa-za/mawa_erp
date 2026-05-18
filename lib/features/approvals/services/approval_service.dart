import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/approval.dart';

class ApprovalService {
  final ApiClient _apiClient = ApiClient();

  Future<Approval> submitApproval(ApprovalSubmission submission) async {
    final response = await _apiClient.post(
      '/v2/approval/submit',
      body: submission.toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to submit approval: ${response.statusCode}');
    }
  }

  Future<List<Approval>> getApprovals({
    String? status,
    String? approvalType,
    String? requesterId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (approvalType != null) queryParams['approvalType'] = approvalType;
    if (requesterId != null) queryParams['requesterId'] = requesterId;

    final response = await _apiClient.get(
      '/v2/approval',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Approval.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load approvals: ${response.statusCode}');
    }
  }

  Future<Approval> getApprovalById(String id) async {
    final response = await _apiClient.get('/v2/approval/$id');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to load approval: ${response.statusCode}');
    }
  }

  Future<List<ApprovalAction>> getAuditTrail(String approvalRequestId) async {
    final response = await _apiClient.get('/v2/approval/$approvalRequestId/audit');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ApprovalAction.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load audit trail: ${response.statusCode}');
    }
  }

  Future<Approval> approve(String id, {String? comments, String? actionBy}) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/approve',
      body: {
        'comments': comments,
        'actionBy': actionBy,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to approve: ${response.statusCode}');
    }
  }

  Future<Approval> reject(String id, {String? comments, String? actionBy}) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/reject',
      body: {
        'comments': comments,
        'actionBy': actionBy,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to reject: ${response.statusCode}');
    }
  }

  Future<Approval> cancel(String id, {String? comments, String? actionBy}) async {
    final response = await _apiClient.post(
      '/v2/approval/$id/cancel',
      body: {
        'comments': comments,
        'actionBy': actionBy,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to cancel: ${response.statusCode}');
    }
  }
}
