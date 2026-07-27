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

  Future<List<Map<String, dynamic>>> quotations({String? status}) async {
    final response = await _apiClient.get('/v2/quotations', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return _decodeListResponse(response.body, response.statusCode, 'quotations');
  }

  Future<Map<String, dynamic>> createQuotation({
    String? customerPartnerId,
    String? customerReference,
    String? validUntil,
    String? requestedDeliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/quotations', body: {
      if (customerPartnerId != null && customerPartnerId.isNotEmpty) 'customerPartnerId': customerPartnerId,
      if (customerReference != null && customerReference.isNotEmpty) 'customerReference': customerReference,
      if (validUntil != null && validUntil.isNotEmpty) 'validUntil': validUntil,
      if (requestedDeliveryDate != null && requestedDeliveryDate.isNotEmpty) 'requestedDeliveryDate': requestedDeliveryDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'currency': 'ZAR',
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'quotation');
  }


  Future<Map<String, dynamic>> quotation(String id) async {
    final response = await _apiClient.get('/v2/quotations/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'quotation');
  }

  Future<Map<String, dynamic>> purchaseOrder(String id) async {
    final response = await _apiClient.get('/v2/purchase-orders/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'purchase order');
  }

  Future<Map<String, dynamic>> goodsReceipt(String id) async {
    final response = await _apiClient.get('/v2/goods-receipts/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'goods receipt');
  }

  Future<Map<String, dynamic>> salesOrder(String id) async {
    final response = await _apiClient.get('/v2/sales-orders/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'sales order');
  }

  Future<List<Map<String, dynamic>>> searchPartners(String query, {String? role}) async {
    final response = await _apiClient.get('/v2/partner', queryParameters: {
      'query': query,
      if (role != null && role.isNotEmpty) 'role': role,
    });
    return _decodeListResponse(response.body, response.statusCode, 'partners');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final response = await _apiClient.get('/product', queryParameters: {
      if (query.isNotEmpty) 'query': query,
      'stockControlled': 'true',
    });
    return _decodeListResponse(response.body, response.statusCode, 'products');
  }

  Future<Map<String, dynamic>> updateQuotationStatus(String id, String status) async {
    final response = await _apiClient.post('/v2/quotations/$id/status', body: {'status': status});
    return _decodeMapResponse(response.body, response.statusCode, 'quotation status');
  }

  Future<Map<String, dynamic>> convertQuotationToSalesOrder(String id, {String? warehouseId}) async {
    final response = await _apiClient.post('/v2/quotations/$id/convert-to-sales-order', body: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'quotation conversion');
  }

  Future<List<Map<String, dynamic>>> purchaseOrders({String? status}) async {
    final response = await _apiClient.get('/v2/purchase-orders', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return _decodeListResponse(response.body, response.statusCode, 'purchase orders');
  }

  Future<Map<String, dynamic>> createPurchaseOrder({
    String? supplierPartnerId,
    String? supplierReference,
    String? expectedDeliveryDate,
    String? warehouseId,
    String? receivingLocationId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/purchase-orders', body: {
      if (supplierPartnerId != null && supplierPartnerId.isNotEmpty) 'supplierPartnerId': supplierPartnerId,
      if (supplierReference != null && supplierReference.isNotEmpty) 'supplierReference': supplierReference,
      if (expectedDeliveryDate != null && expectedDeliveryDate.isNotEmpty) 'expectedDeliveryDate': expectedDeliveryDate,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (receivingLocationId != null && receivingLocationId.isNotEmpty) 'receivingLocationId': receivingLocationId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'currency': 'ZAR',
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'purchase order');
  }

  Future<Map<String, dynamic>> updatePurchaseOrderStatus(String id, String status) async {
    final response = await _apiClient.post('/v2/purchase-orders/$id/status', body: {'status': status});
    return _decodeMapResponse(response.body, response.statusCode, 'purchase order status');
  }

  Future<Map<String, dynamic>> receivePurchaseOrder(
    String id, {
    String? warehouseId,
    String? storageLocationId,
    String? supplierReference,
    String? notes,
    List<Map<String, dynamic>>? lines,
  }) async {
    final response = await _apiClient.post('/v2/purchase-orders/$id/goods-receipt', body: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (storageLocationId != null && storageLocationId.isNotEmpty) 'storageLocationId': storageLocationId,
      if (supplierReference != null && supplierReference.isNotEmpty) 'supplierReference': supplierReference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (lines != null && lines.isNotEmpty) 'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'purchase order receipt');
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
      'locationType': locationType ?? 'GENERAL_STORAGE',
    });
    return _decodeMapResponse(response.body, response.statusCode, 'storage location');
  }

  Future<Map<String, dynamic>> createGoodsReceipt({
    String? purchaseOrderId,
    required String warehouseId,
    required String storageLocationId,
    String? supplierPartnerId,
    String? supplierReference,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/goods-receipts', body: {
      if (purchaseOrderId != null && purchaseOrderId.isNotEmpty) 'purchaseOrderId': purchaseOrderId,
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
    String? customerReference,
    String? warehouseId,
    String? requestedDeliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/sales-orders', body: {
      if (customerPartnerId != null && customerPartnerId.isNotEmpty) 'customerPartnerId': customerPartnerId,
      if (customerReference != null && customerReference.isNotEmpty) 'customerReference': customerReference,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (requestedDeliveryDate != null && requestedDeliveryDate.isNotEmpty) 'requestedDeliveryDate': requestedDeliveryDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'currency': 'ZAR',
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'sales order');
  }

  Future<Map<String, dynamic>> reserveSalesOrder(String id) async {
    final response = await _apiClient.post('/v2/sales-orders/$id/reserve', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'sales order reservation');
  }

  Future<Map<String, dynamic>> issueSalesOrder(String id, {String? warehouseId, String? storageLocationId}) async {
    final response = await _apiClient.post('/v2/sales-orders/$id/issue', body: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (storageLocationId != null && storageLocationId.isNotEmpty) 'storageLocationId': storageLocationId,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'sales order issue');
  }

  Future<Map<String, dynamic>> updateSalesOrderStatus(String id, String status) async {
    final response = await _apiClient.post('/v2/sales-orders/$id/status', body: {'status': status});
    return _decodeMapResponse(response.body, response.statusCode, 'sales order status');
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
