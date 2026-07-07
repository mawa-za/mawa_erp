import 'dart:convert';
import '../../../core/api_client.dart';

class StockService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _apiClient.get('/v2/stock/dashboard');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeMap(response.body);
    }
    throw Exception('Failed to load stock dashboard: ${response.statusCode} ${response.body}');
  }

  Future<List<Map<String, dynamic>>> stock({String? warehouseId, String? storageLocationId, String? productId}) async {
    final response = await _apiClient.get('/v2/stock', queryParameters: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (storageLocationId != null && storageLocationId.isNotEmpty) 'storageLocationId': storageLocationId,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'stock');
  }

  Future<List<Map<String, dynamic>>> warehouses() async {
    final response = await _apiClient.get('/v2/warehouses');
    return _decodeListResponse(response.body, response.statusCode, 'warehouses');
  }

  Future<List<Map<String, dynamic>>> storageLocations({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/storage-locations', queryParameters: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'storage locations');
  }

  Future<List<Map<String, dynamic>>> goodsReceipts() async {
    final response = await _apiClient.get('/v2/goods-receipts');
    return _decodeListResponse(response.body, response.statusCode, 'goods receipts');
  }

  Future<List<Map<String, dynamic>>> putaways() async {
    final response = await _apiClient.get('/v2/putaways');
    return _decodeListResponse(response.body, response.statusCode, 'putaways');
  }

  Future<List<Map<String, dynamic>>> movements({String? productId}) async {
    final response = await _apiClient.get('/v2/stock-movements', queryParameters: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'stock movements');
  }

  Future<List<Map<String, dynamic>>> salesOrders() async {
    final response = await _apiClient.get('/v2/sales-orders');
    return _decodeListResponse(response.body, response.statusCode, 'sales orders');
  }

  Future<List<Map<String, dynamic>>> audit() async {
    final response = await _apiClient.get('/v2/audit-trail');
    return _decodeListResponse(response.body, response.statusCode, 'audit trail');
  }

  Future<Map<String, dynamic>> createWarehouse({required String warehouseCode, required String name, String? description}) async {
    final response = await _apiClient.post('/v2/warehouses', body: {
      'warehouseCode': warehouseCode,
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'warehouse');
  }

  Future<Map<String, dynamic>> createStorageLocation({required String warehouseId, required String locationCode, required String name, String? locationType}) async {
    final response = await _apiClient.post('/v2/storage-locations', body: {
      'warehouseId': warehouseId,
      'locationCode': locationCode,
      'name': name,
      'locationType': locationType ?? 'BIN',
    });
    return _decodeMapResponse(response.body, response.statusCode, 'storage location');
  }

  Future<Map<String, dynamic>> createGoodsReceipt({
    required String warehouseId,
    required String storageLocationId,
    String? supplierPartnerId,
    String? supplierReference,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/goods-receipts', body: {
      'warehouseId': warehouseId,
      'storageLocationId': storageLocationId,
      if (supplierPartnerId != null && supplierPartnerId.isNotEmpty) 'supplierPartnerId': supplierPartnerId,
      if (supplierReference != null && supplierReference.isNotEmpty) 'supplierReference': supplierReference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'goods receipt');
  }

  Future<Map<String, dynamic>> createPutaway({
    required String warehouseId,
    required String fromLocationId,
    required String toLocationId,
    String? goodsReceiptId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/putaways', body: {
      'warehouseId': warehouseId,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
      if (goodsReceiptId != null && goodsReceiptId.isNotEmpty) 'goodsReceiptId': goodsReceiptId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'putaway');
  }

  Future<Map<String, dynamic>> createSalesOrder({
    String? customerPartnerId,
    String? warehouseId,
    String? requestedDeliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/sales-orders', body: {
      if (customerPartnerId != null && customerPartnerId.isNotEmpty) 'customerPartnerId': customerPartnerId,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (requestedDeliveryDate != null && requestedDeliveryDate.isNotEmpty) 'requestedDeliveryDate': requestedDeliveryDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'sales order');
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _decodeMapResponse(String body, int statusCode, String label) {
    if (statusCode >= 200 && statusCode < 300) return _decodeMap(body);
    throw Exception('Failed to save $label: $statusCode $body');
  }

  List<Map<String, dynamic>> _decodeListResponse(String body, int statusCode, String label) {
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Failed to load $label: $statusCode $body');
    }
    if (body.trim().isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }
}
