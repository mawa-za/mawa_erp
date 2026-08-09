import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/tombstone_models.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class TombstoneService {
  final ApiClient _api = ApiClient();

  Future<TombstoneDashboard> dashboard() async {
    final response = await _api.get('/v2/tombstones/dashboard');
    return TombstoneDashboard(_map(response));
  }

  Future<List<TombstoneOrder>> orders({String? status, String? fundingStatus, String? query}) async {
    final response = await _api.get('/v2/tombstones/orders', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (fundingStatus != null && fundingStatus.isNotEmpty) 'fundingStatus': fundingStatus,
      if (query != null && query.isNotEmpty) 'query': query,
    });
    return _list(response).map(TombstoneOrder.fromJson).toList();
  }

  Future<TombstoneOrder> order(String id) async {
    final response = await _api.get('/v2/tombstones/orders/$id');
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> createOrder(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> updateOrder(String id, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/orders/$id', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> addFunding(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/funding', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> createLayby(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/layby', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> recordLaybyPayment(String agreementId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/laybys/$agreementId/payments', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<List<Map<String, dynamic>>> laybys({String? status}) async {
    final response = await _api.get('/v2/tombstones/laybys', queryParameters: {if (status != null) 'status': status});
    return _list(response);
  }

  Future<TombstoneOrder> addAssessment(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/site-assessments', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<List<Map<String, dynamic>>> assessments({String? status}) async {
    final response = await _api.get('/v2/tombstones/site-assessments', queryParameters: {if (status != null) 'status': status});
    return _list(response);
  }

  Future<TombstoneOrder> createAmendment(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/amendments', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> decideAmendment(String amendmentId, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/amendments/$amendmentId/decision', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> addDesign(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/designs', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> approveDesign(String designId, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/designs/$designId/approve', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<List<Map<String, dynamic>>> designs({String? status}) async {
    final response = await _api.get('/v2/tombstones/designs', queryParameters: {if (status != null) 'status': status});
    return _list(response);
  }

  Future<TombstoneOrder> createProduction(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/production-jobs', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> updateProductionStatus(String jobId, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/production-jobs/$jobId/status', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<List<Map<String, dynamic>>> productionJobs({String? status}) async {
    final response = await _api.get('/v2/tombstones/production-jobs', queryParameters: {if (status != null) 'status': status});
    return _list(response);
  }

  Future<Map<String, dynamic>> supplierPaymentRequest(String jobId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/production-jobs/$jobId/supplier-payment-request', body: body);
    return _map(response);
  }

  Future<TombstoneOrder> createInstallation(String orderId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/orders/$orderId/installations', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> updateInstallationStatus(String id, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/installations/$id/status', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> updateChecklist(String installationId, String checklistId, Map<String, dynamic> body) async {
    final response = await _api.put('/v2/tombstones/installations/$installationId/checklist/$checklistId', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> completeInstallation(String id, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/installations/$id/complete', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> acceptInstallation(String id, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/installations/$id/accept', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<TombstoneOrder> createRework(String id, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/tombstones/installations/$id/rework', body: body);
    return TombstoneOrder.fromJson(_map(response));
  }

  Future<List<Map<String, dynamic>>> installations({String? status}) async {
    final response = await _api.get('/v2/tombstones/installations', queryParameters: {if (status != null) 'status': status});
    return _list(response);
  }

  Future<Map<String, dynamic>> cancelOrder(String id, String reason) async {
    final response = await _api.post('/v2/tombstones/orders/$id/cancel', queryParameters: {'reason': reason});
    return _map(response);
  }

  Map<String, dynamic> _map(dynamic response) {
    final code = response.statusCode as int;
    final text = response.body as String;
    if (code < 200 || code >= 300) throw AppException(_error(text, code));
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw AppException('Unexpected tombstone API response');
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    final code = response.statusCode as int;
    final text = response.body as String;
    if (code < 200 || code >= 300) throw AppException(_error(text, code));
    if (text.trim().isEmpty) return const [];
    final decoded = jsonDecode(text);
    if (decoded is List) return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    throw AppException('Unexpected tombstone API list response');
  }

  String _error(String body, int code) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded['message']?.toString() ?? decoded['error']?.toString() ?? 'Request failed ($code)';
    } catch (_) {}
    return body.trim().isEmpty ? 'Request failed ($code)' : body;
  }
}
