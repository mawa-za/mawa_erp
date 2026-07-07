import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/approval_workflow.dart';

class ApprovalWorkflowService {
  final ApiClient _apiClient = ApiClient();

  Future<List<ApprovalWorkflow>> getWorkflows() async {
    final response = await _apiClient.get('/v2/approval-workflow');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ApprovalWorkflow.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load approval workflows: ${response.statusCode}');
    }
  }

  Future<List<ApprovalWorkflow>> getActiveWorkflows() async {
    final response = await _apiClient.get('/v2/approval-workflow/active');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ApprovalWorkflow.fromJson(item)).toList();
    }
    throw Exception('Failed to load active workflows');
  }

  Future<ApprovalWorkflow> getWorkflowByType(String approvalType, {bool activeOnly = false}) async {
    final path = activeOnly 
        ? '/v2/approval-workflow/type/$approvalType/active' 
        : '/v2/approval-workflow/type/$approvalType';
    final response = await _apiClient.get(path);
    if (response.statusCode == 200) {
      return ApprovalWorkflow.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load workflow by type');
  }

  Future<ApprovalWorkflow> createWorkflow(ApprovalWorkflow workflow) async {
    final response = await _apiClient.post(
      '/v2/approval-workflow',
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
    final response = await _apiClient.get('/v2/approval-workflow/$id');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ApprovalWorkflow.fromJson(data);
    } else {
      throw Exception('Failed to load approval workflow: ${response.statusCode}');
    }
  }

  Future<ApprovalWorkflow> updateWorkflow(String id, ApprovalWorkflow workflow) async {
    final response = await _apiClient.put(
      '/v2/approval-workflow/$id',
      body: workflow.toJson(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ApprovalWorkflow.fromJson(data);
    } else {
      throw Exception('Failed to update approval workflow: ${response.statusCode}');
    }
  }

  Future<void> activateWorkflow(String id) async {
    final response = await _apiClient.patch('/v2/approval-workflow/$id/activate');
    if (response.statusCode != 200) {
      throw Exception('Failed to activate workflow');
    }
  }

  Future<void> deactivateWorkflow(String id) async {
    final response = await _apiClient.patch('/v2/approval-workflow/$id/deactivate');
    if (response.statusCode != 200) {
      throw Exception('Failed to deactivate workflow');
    }
  }

  Future<void> deleteWorkflow(String id) async {
    final response = await _apiClient.delete('/v2/approval-workflow/$id');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete approval workflow: ${response.statusCode}');
    }
  }
}
