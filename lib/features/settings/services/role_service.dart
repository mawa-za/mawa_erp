import 'dart:convert';
import '../../../core/api_client.dart';
import '../../home/models/workcenter.dart';
import '../models/role.dart';
import '../models/role_permission.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class RoleService {
  final ApiClient _apiClient = ApiClient();

  Future<List<RolePermission>> getAllPermissions() async {
    final response = await _apiClient.get('/v2/permissions');
    if (response.statusCode != 200) {
      throw AppException('Unable to load permission catalogue (HTTP ${response.statusCode}): ${response.body}');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items.map((item) => RolePermission.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<Set<String>> getRolePermissions(String roleId) async {
    final path = '/v2/role/${Uri.encodeComponent(roleId)}/permissions';
    final response = await _apiClient.get(path);
    if (response.statusCode != 200) {
      throw AppException('Unable to load role permissions (HTTP ${response.statusCode}): ${response.body}');
    }
    return (jsonDecode(response.body) as List<dynamic>).map((item) => item.toString()).toSet();
  }

  Future<void> saveRolePermissions(String roleId, Set<String> codes) async {
    final path = '/v2/role/${Uri.encodeComponent(roleId)}/permissions';
    final response = await _apiClient.put(path, body: codes.toList()..sort());
    if (response.statusCode != 200) {
      throw AppException('Unable to save role permissions (HTTP ${response.statusCode}): ${response.body}');
    }
  }

  Future<List<Role>> getRoles() async {
    final response = await _apiClient.get('/v2/role');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Role.fromJson(json)).toList();
    } else {
      throw AppException('Failed to load roles: ${response.statusCode}');
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
      throw AppException(response.body.isNotEmpty ? response.body : 'Failed to create role: ${response.statusCode}');
    }
  }

  Future<Role> updateRole(Role role) async {
    final response = await _apiClient.put('/v2/role/${role.id}', body: role.toJson());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Role.fromJson(Map<String, dynamic>.from(data as Map));
    }
    throw AppException(response.body.isNotEmpty ? response.body : 'Failed to update role');
  }

  Future<void> deleteRole(String roleId) async {
    final response = await _apiClient.delete('/v2/role/$roleId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException(response.body.isNotEmpty ? response.body : 'Failed to delete role: ${response.statusCode}');
    }
  }

  Future<List<Workcenter>> getAllWorkcenters() async {
    final response = await _apiClient.get('/v2/workcenters');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Workcenter.fromJson(json)).toList();
    } else {
      throw AppException('Failed to load all workcenters: ${response.statusCode}');
    }
  }

  Future<List<Workcenter>> getRoleWorkcenters(String roleId) async {
    final response = await _apiClient.get('/v2/role/$roleId/workcenter');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Workcenter.fromJson(json)).toList();
    } else {
      throw AppException('Failed to load workcenters for role $roleId: ${response.statusCode}');
    }
  }

  Future<void> assignWorkcentersToRole(String roleId, List<Map<String, dynamic>> assignments) async {
    final response = await _apiClient.post(
      '/v2/role/$roleId/workcenter',
      body: assignments,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException(response.body.isNotEmpty ? response.body : 'Failed to assign workcenters to role: ${response.statusCode}');
    }
  }

  Future<void> removeWorkcenterFromRole(String roleId, String workcenterCode) async {
    final response = await _apiClient.delete(
      '/v2/role/$roleId/workcenter',
      queryParameters: {'workcenter': workcenterCode},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to remove workcenter from role');
    }
  }
}
