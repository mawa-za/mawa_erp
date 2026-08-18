import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class LaybyService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> list({String? status, String? query}) async {
    final response = await _api.get('/v2/laybys', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    });
    return _list(response.statusCode, response.body, 'laybys');
  }

  Future<Map<String, dynamic>> get(String id) async {
    final response = await _api.get('/v2/laybys/$id');
    return _map(response.statusCode, response.body, 'layby');
  }

  Future<Map<String, dynamic>> configuration() async {
    final response = await _api.get('/v2/laybys/configuration');
    return _map(response.statusCode, response.body, 'layby configuration');
  }

  Future<Map<String, dynamic>> updateConfiguration(Map<String, dynamic> body) async {
    final response = await _api.put('/v2/laybys/configuration', body: body);
    return _map(response.statusCode, response.body, 'layby configuration');
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/laybys', body: body);
    return _map(response.statusCode, response.body, 'layby');
  }

  Future<Map<String, dynamic>> createFromQuotation(String quotationId, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/quotations/$quotationId/convert-to-layby', body: body);
    return _map(response.statusCode, response.body, 'layby');
  }

  Future<Map<String, dynamic>> activate(String id) async {
    final response = await _api.post('/v2/laybys/$id/activate', body: <String, dynamic>{});
    return _map(response.statusCode, response.body, 'layby activation');
  }

  Future<Map<String, dynamic>> capturePayment(String id, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/laybys/$id/payments', body: body);
    return _map(response.statusCode, response.body, 'layby payment');
  }

  Future<Map<String, dynamic>> cancel(String id, Map<String, dynamic> body) async {
    final response = await _api.post('/v2/laybys/$id/cancel', body: body);
    return _map(response.statusCode, response.body, 'layby cancellation');
  }

  Future<Map<String, dynamic>> requestRefundApproval(String id) async {
    final response = await _api.post('/v2/laybys/$id/refund/request-approval', body: <String, dynamic>{});
    return _map(response.statusCode, response.body, 'layby refund approval request');
  }

  Future<Map<String, dynamic>> markRefundPaid(String id, {String? paymentReference, String? notes}) async {
    final response = await _api.post('/v2/laybys/$id/refund/paid', body: {
      if (paymentReference != null && paymentReference.trim().isNotEmpty) 'paymentReference': paymentReference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return _map(response.statusCode, response.body, 'layby refund payment');
  }

  Future<Map<String, dynamic>> fulfil(String id, {String? notes}) async {
    final response = await _api.post('/v2/laybys/$id/fulfil', body: {
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return _map(response.statusCode, response.body, 'layby fulfilment');
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final response = await _api.get('/v2/partner', queryParameters: {'query': query, 'role': 'CUSTOMER'});
    return _list(response.statusCode, response.body, 'customers');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final response = await _api.get('/product', queryParameters: {
      if (query.trim().isNotEmpty) 'query': query.trim(),
    });
    return _list(response.statusCode, response.body, 'products');
  }

  Future<List<Map<String, dynamic>>> warehouses() async {
    final response = await _api.get('/v2/warehouses', queryParameters: {'status': 'ACTIVE'});
    return _list(response.statusCode, response.body, 'warehouses');
  }

  Future<List<Map<String, dynamic>>> storageLocations(String warehouseId) async {
    final response = await _api.get('/v2/storage-locations', queryParameters: {'warehouseId': warehouseId, 'status': 'ACTIVE'});
    return _list(response.statusCode, response.body, 'storage locations');
  }

  Future<Uint8List> agreementPdf(String id) async {
    final response = await _api.get('/v2/laybys/$id/agreement-pdf');
    if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
    throw AppException('Failed to download layby agreement: ${response.statusCode} ${response.body}');
  }

  Future<Uint8List> statementPdf(String id) async {
    final response = await _api.get('/v2/laybys/$id/statement-pdf');
    if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
    throw AppException('Failed to download layby statement: ${response.statusCode} ${response.body}');
  }

  Map<String, dynamic> _map(int status, String body, String label) {
    if (status < 200 || status >= 300) throw AppException('Failed to process $label: $status $body');
    if (body.trim().isEmpty) return <String, dynamic>{};
    final value = jsonDecode(body);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(int status, String body, String label) {
    if (status < 200 || status >= 300) throw AppException('Failed to load $label: $status $body');
    if (body.trim().isEmpty) return <Map<String, dynamic>>[];
    final value = jsonDecode(body);
    if (value is List) return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return <Map<String, dynamic>>[];
  }
}
