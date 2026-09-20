import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class ResellerPortalService {
  final ApiClient _api = ApiClient();
  Future<Map<String, dynamic>> profile() => _map('/v2/reseller-portal/profile');
  Future<List<Map<String, dynamic>>> clients() => _list('/v2/reseller-portal/clients');
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> body) =>
      _postMap('/v2/reseller-portal/clients', body);
  Future<Map<String, dynamic>> retryClientProvisioning(String tenantId) =>
      _postMap('/v2/reseller-portal/clients/$tenantId/provision/retry', const {});
  Future<List<Map<String, dynamic>>> sessions() => _list('/v2/reseller-portal/support-sessions');
  Future<List<Map<String, dynamic>>> tickets() => _list('/v2/reseller-portal/support-tickets');
  Future<Map<String, dynamic>> startSession(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/reseller-portal/support-sessions', body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw AppException(response.body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  Future<Map<String, dynamic>> openSession(String sessionId) async {
    final response = await _api.post('/v2/reseller-portal/support-sessions/$sessionId/open', body: const {});
    if (response.statusCode < 200 || response.statusCode >= 300) throw AppException(response.body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  Future<Map<String, dynamic>> revokeSession(String sessionId) async {
    final response = await _api.post('/v2/reseller-portal/support-sessions/$sessionId/revoke', body: const {});
    if (response.statusCode < 200 || response.statusCode >= 300) throw AppException(response.body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  Future<Map<String, dynamic>> ticketDetail(String ticketId) => _postMap('/v2/reseller-portal/support-tickets/$ticketId/detail', const {});
  Future<Map<String, dynamic>> comment(String ticketId, String message) =>
      _postMap('/v2/reseller-portal/support-tickets/$ticketId/comment', {'message': message});
  Future<Map<String, dynamic>> updateStatus(String ticketId, String status) =>
      _postMap('/v2/reseller-portal/support-tickets/$ticketId/status', {'status': status});
  Future<Map<String, dynamic>> assign(String ticketId, String username) =>
      _postMap('/v2/reseller-portal/support-tickets/$ticketId/assign', {'assignedTo': username});
  Future<Map<String, dynamic>> escalate(String ticketId, String reason) =>
      _postMap('/v2/reseller-portal/support-tickets/$ticketId/escalate', {'reason': reason});
  Future<Map<String, dynamic>> _postMap(String path, Map<String, dynamic> body) async {
    final response = await _api.post(path, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw AppException(response.body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  Future<Map<String, dynamic>> _map(String path) async {
    final response = await _api.get(path);
    if (response.statusCode != 200) throw AppException(response.body);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await _api.get(path);
    if (response.statusCode != 200) throw AppException(response.body);
    return (jsonDecode(response.body) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
