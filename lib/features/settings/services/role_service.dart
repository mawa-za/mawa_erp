import 'dart:convert';
import '../../../core/api_client.dart';
import '../../home/models/workcenter.dart';
import '../models/role.dart';

class RoleService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Role>> getRoles() async {
    final response = await _apiClient.get('/v2/role');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Role.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load roles: ${response.statusCode}');
    }
  }

  Future<Role> createRole(Role role) async {
    final response = await _apiClient.post(
      '/v2/role',
      body: role.toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Role.fromJson(data);
    } else {
      throw Exception('Failed to create role: ${response.statusCode}');
    }
  }

  Future<void> deleteRole(String roleId) async {
    final response = await _apiClient.delete('/v2/role/$roleId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete role: ${response.statusCode}');
    }
  }

  Future<List<Workcenter>> getAllWorkcenters() async {
    final response = await _apiClient.get('/workcenter');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Workcenter.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load all workcenters: ${response.statusCode}');
    }
  }

  Future<List<Workcenter>> getRoleWorkcenters(String roleId) async {
    final response = await _apiClient.get('/v2/role/$roleId/workcenter');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Workcenter.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load workcenters for role $roleId: ${response.statusCode}');
    }
  }

  Future<void> assignWorkcentersToRole(String roleId, List<Map<String, dynamic>> assignments) async {
    final response = await _apiClient.post(
      '/v2/role/$roleId/workcenter',
      body: assignments,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to assign workcenters to role: ${response.statusCode}');
    }
  }

  Future<void> removeWorkcenterFromRole(String roleId, String workcenterCode) async {
    final response = await _apiClient.delete(
      '/v2/role/$roleId/workcenter',
      queryParameters: {'workcenter': workcenterCode},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to remove workcenter from role');
    }
  }
}
