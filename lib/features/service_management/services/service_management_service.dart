import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class ServiceManagementService {
  final ApiClient _api = ApiClient();
  static const _base = '/v2/service-management';

  Future<Map<String, dynamic>> dashboard() async =>
      _map(await _api.get('$_base/dashboard'), 'load service dashboard');

  Future<List<Map<String, dynamic>>> requests({String? status}) async => _list(
        await _api.get('$_base/requests', queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        }),
        'load service requests',
      );

  Future<Map<String, dynamic>> createOrderFromRequest(String id) async =>
      _map(await _api.post('$_base/requests/$id/order'), 'create service order');

  Future<Map<String, dynamic>> createContractFromRequest(String id) async =>
      _map(await _api.post('$_base/requests/$id/contract'), 'create service contract');

  Future<List<Map<String, dynamic>>> contracts({String? status}) async => _list(
        await _api.get('$_base/contracts', queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        }),
        'load service contracts',
      );

  Future<Map<String, dynamic>> saveContract(Map<String, dynamic> body) async =>
      _map(await _api.put('$_base/contracts', body: body), 'save service contract');

  Future<Map<String, dynamic>> changeContractStatus(String id, String status) async =>
      _map(await _api.post('$_base/contracts/$id/status/$status'), 'update service contract');

  Future<List<Map<String, dynamic>>> resources() async =>
      _list(await _api.get('$_base/resources'), 'load service resources');

  Future<Map<String, dynamic>> saveResource(Map<String, dynamic> body) async =>
      _map(await _api.put('$_base/resources', body: body), 'save service resource');

  Future<List<Map<String, dynamic>>> resourceRequirements(String productId) async => _list(
        await _api.get('$_base/resource-requirements', queryParameters: {'productId': productId}),
        'load service resource requirements',
      );

  Future<Map<String, dynamic>> saveResourceRequirement(Map<String, dynamic> body) async =>
      _map(await _api.put('$_base/resource-requirements', body: body), 'save service resource requirement');

  Future<void> deleteResourceRequirement(String id) async {
    final response = await _api.delete('$_base/resource-requirements/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException('Failed to delete service resource requirement: ${response.statusCode} ${response.body}');
    }
  }


  Future<List<Map<String, dynamic>>> locations(String customerPartnerId) async =>
      _list(
        await _api.get('$_base/locations', queryParameters: {
          'customerPartnerId': customerPartnerId,
        }),
        'load service locations',
      );

  Future<Map<String, dynamic>> saveLocation(Map<String, dynamic> body) async =>
      _map(await _api.put('$_base/locations', body: body), 'save service location');

  Future<List<Map<String, dynamic>>> serviceProducts() async => _list(
        await _api.get('/v2/purple/provider-enrolment/products'),
        'load service products',
      );

  Future<Map<String, dynamic>> generateRecurring() async =>
      _map(await _api.post('$_base/recurring/generate'), 'generate recurring services');

  Map<String, dynamic> _map(dynamic response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    }
    throw AppException('Failed to $action: ${response.statusCode} ${response.body}');
  }

  List<Map<String, dynamic>> _list(dynamic response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = response.body.isEmpty ? const [] : jsonDecode(response.body);
      return (decoded as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw AppException('Failed to $action: ${response.statusCode} ${response.body}');
  }
}
