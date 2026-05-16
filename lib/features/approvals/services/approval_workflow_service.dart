import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/approval_workflow.dart';

class ApprovalWorkflowService {
  final ApiClient _apiClient = ApiClient();

  Future<PaginatedResponse<ApprovalWorkflow>> getWorkflows({int page = 0, int size = 20}) async {
    final response = await _apiClient.get(
      '/v2/approvals/workflows/all',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PaginatedResponse.fromJson(
        data,
        (item) => ApprovalWorkflow.fromJson(item),
      );
    } else {
      throw Exception('Failed to load approval workflows: ${response.statusCode}');
    }
  }

  Future<ApprovalWorkflow> createWorkflow(ApprovalWorkflow workflow) async {
    final response = await _apiClient.post(
      '/v2/approvals/workflows',
      body: workflow.toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return ApprovalWorkflow.fromJson(data);
    } else {
      throw Exception('Failed to create approval workflow: ${response.statusCode}');
    }
  }

  Future<ApprovalWorkflow> getWorkflowById(String id) async {
    final response = await _apiClient.get('/v2/approvals/workflows/$id');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ApprovalWorkflow.fromJson(data);
    } else {
      throw Exception('Failed to load approval workflow: ${response.statusCode}');
    }
  }

  Future<ApprovalWorkflow> updateWorkflow(String id, ApprovalWorkflow workflow) async {
    final response = await _apiClient.put(
      '/v2/approvals/workflows/$id',
      body: workflow.toJson(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ApprovalWorkflow.fromJson(data);
    } else {
      throw Exception('Failed to update approval workflow: ${response.statusCode}');
    }
  }

  Future<void> deleteWorkflow(String id) async {
    final response = await _apiClient.delete('/v2/approvals/workflows/$id');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete approval workflow: ${response.statusCode}');
    }
  }
}
