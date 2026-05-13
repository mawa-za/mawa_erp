import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/approval.dart';

class ApprovalService {
  final ApiClient _apiClient = ApiClient();

  Future<Approval> submitApproval(ApprovalSubmission submission) async {
    final response = await _apiClient.post(
      '/v2/approvals/submit',
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
      '/v2/approvals',
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
    final response = await _apiClient.get('/v2/approvals/$id');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to load approval: ${response.statusCode}');
    }
  }

  Future<Approval> takeAction(String id, String action, {String? comment}) async {
    final response = await _apiClient.post(
      '/v2/approvals/$id/action',
      body: {
        'action': action,
        'comment': comment,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Approval.fromJson(data);
    } else {
      throw Exception('Failed to perform action: ${response.statusCode}');
    }
  }
}
