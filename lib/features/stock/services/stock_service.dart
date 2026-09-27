import 'dart:convert';
import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class StockService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _apiClient.get('/v2/stock/dashboard');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeMap(response.body);
    }
    throw AppException('Failed to load stock dashboard: ${response.statusCode} ${response.body}');
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
    String? quotationDate,
    String? validUntil,
    String? requestedDeliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.post('/v2/quotations', body: {
      if (customerPartnerId != null && customerPartnerId.isNotEmpty) 'customerPartnerId': customerPartnerId,
      if (customerReference != null && customerReference.isNotEmpty) 'customerReference': customerReference,
      if (quotationDate != null && quotationDate.isNotEmpty) 'quotationDate': quotationDate,
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

  Future<Map<String, dynamic>> updateQuotation(
    String id, {
    String? customerPartnerId,
    String? customerReference,
    String? quotationDate,
    String? validUntil,
    String? requestedDeliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await _apiClient.put('/v2/quotations/$id', body: {
      if (customerPartnerId != null && customerPartnerId.isNotEmpty) 'customerPartnerId': customerPartnerId,
      if (customerReference != null && customerReference.isNotEmpty) 'customerReference': customerReference,
      if (quotationDate != null && quotationDate.isNotEmpty) 'quotationDate': quotationDate,
      if (validUntil != null && validUntil.isNotEmpty) 'validUntil': validUntil,
      if (requestedDeliveryDate != null && requestedDeliveryDate.isNotEmpty) 'requestedDeliveryDate': requestedDeliveryDate,
      if (notes != null) 'notes': notes,
      'currency': 'ZAR',
      'lines': lines,
    });
    return _decodeMapResponse(response.body, response.statusCode, 'quotation update');
  }

  Future<Map<String, dynamic>> convertQuotationToInvoice(String id) async {
    final response = await _apiClient.post('/v2/quotations/$id/convert-to-invoice');
    return _decodeMapResponse(response.body, response.statusCode, 'quotation invoice');
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

  Future<Map<String, dynamic>> sendPurchaseOrderToMawaSupplier(String id) async {
    final response = await _apiClient.post('/v2/supplier-network/purchase-orders/$id/send');
    return _decodeMapResponse(response.body, response.statusCode, 'MAWA supplier delivery');
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

  Future<List<Map<String, dynamic>>> inventoryDocuments({String? type, String? status, String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/documents', queryParameters: {
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'inventory documents');
  }

  Future<Map<String, dynamic>> inventoryDocument(String id) async {
    final response = await _apiClient.get('/v2/inventory/documents/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'inventory document');
  }

  Future<Map<String, dynamic>> createInventoryDocument(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/v2/inventory/documents', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory document');
  }

  Future<Map<String, dynamic>> postInventoryDocument(String id) async {
    final response = await _apiClient.post('/v2/inventory/documents/$id/post', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory posting');
  }

  Future<Map<String, dynamic>> submitInventoryDocument(String id) async {
    final response = await _apiClient.post('/v2/inventory/documents/$id/submit', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory approval submission');
  }

  Future<Map<String, dynamic>> createWarehouseTransfer(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/v2/inventory/warehouse-transfers', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'warehouse transfer');
  }

  Future<Map<String, dynamic>> submitWarehouseTransfer(String id) async {
    final response = await _apiClient.post('/v2/inventory/warehouse-transfers/$id/submit', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'warehouse transfer approval');
  }

  Future<Map<String, dynamic>> dispatchWarehouseTransfer(String id) async {
    final response = await _apiClient.post('/v2/inventory/warehouse-transfers/$id/dispatch', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'warehouse transfer dispatch');
  }

  Future<Map<String, dynamic>> receiveWarehouseTransfer(String id, Map<String, dynamic> body) async {
    final response = await _apiClient.post('/v2/inventory/warehouse-transfers/$id/receive', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'warehouse transfer receipt');
  }

  Future<List<Map<String, dynamic>>> inventoryStockCounts({String? status, String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/stock-counts', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'inventory stock counts');
  }

  Future<Map<String, dynamic>> inventoryStockCount(String id) async {
    final response = await _apiClient.get('/v2/inventory/stock-counts/$id');
    return _decodeMapResponse(response.body, response.statusCode, 'inventory stock count');
  }

  Future<Map<String, dynamic>> createInventoryStockCount(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/v2/inventory/stock-counts', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory stock count');
  }

  Future<Map<String, dynamic>> recordInventoryStockCount(String id, List<Map<String, dynamic>> lines) async {
    final response = await _apiClient.put('/v2/inventory/stock-counts/$id/counts', body: {'lines': lines});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory stock count entries');
  }

  Future<Map<String, dynamic>> finalizeInventoryStockCount(String id) async {
    final response = await _apiClient.post('/v2/inventory/stock-counts/$id/finalize', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory stock count finalisation');
  }

  Future<List<Map<String, dynamic>>> inventoryReservations({String? status}) async {
    final response = await _apiClient.get('/v2/inventory/reservations', queryParameters: {if (status != null && status.isNotEmpty) 'status': status});
    return _decodeListResponse(response.body, response.statusCode, 'inventory reservations');
  }

  Future<Map<String, dynamic>> createInventoryReservation(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/v2/inventory/reservations', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory reservation');
  }

  Future<Map<String, dynamic>> releaseInventoryReservation(String id) async {
    final response = await _apiClient.post('/v2/inventory/reservations/$id/release', body: <String, dynamic>{});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory reservation release');
  }

  Future<List<Map<String, dynamic>>> inventoryAvailability({String? productId, String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/availability', queryParameters: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'inventory availability');
  }

  Future<List<Map<String, dynamic>>> reversibleInventoryMovements({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/movements/reversible', queryParameters: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'reversible inventory movements');
  }

  Future<Map<String, dynamic>> reverseInventoryMovement(String id, {String? notes}) async {
    final response = await _apiClient.post('/v2/inventory/movements/$id/reverse', body: {if (notes != null && notes.isNotEmpty) 'notes': notes});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory reversal');
  }

  Future<List<Map<String, dynamic>>> inventoryReplenishmentRecommendations({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/replenishment/recommendations', queryParameters: {if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId});
    return _decodeListResponse(response.body, response.statusCode, 'inventory replenishment recommendations');
  }

  Future<List<Map<String, dynamic>>> inventoryPurchaseRecommendations({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/purchase-recommendations', queryParameters: {if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId});
    return _decodeListResponse(response.body, response.statusCode, 'inventory purchase recommendations');
  }

  Future<List<Map<String, dynamic>>> inventoryExpiryAlerts({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/expiry-alerts', queryParameters: {if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId});
    return _decodeListResponse(response.body, response.statusCode, 'inventory expiry alerts');
  }

  Future<List<Map<String, dynamic>>> inventoryAgeing({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/ageing', queryParameters: {if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId});
    return _decodeListResponse(response.body, response.statusCode, 'inventory ageing');
  }

  Future<Map<String, dynamic>> inventoryHealth({String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/health', queryParameters: {if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory health');
  }

  Future<Map<String, dynamic>> inventoryBatchRecall(String batchNo) async {
    final response = await _apiClient.get('/v2/inventory/recall', queryParameters: {'batchNo': batchNo});
    return _decodeMapResponse(response.body, response.statusCode, 'inventory batch recall');
  }

  Future<List<Map<String, dynamic>>> inventoryReasonCodes() async {
    final response = await _apiClient.get('/v2/inventory/reason-codes');
    return _decodeListResponse(response.body, response.statusCode, 'inventory reason codes');
  }

  Future<Map<String, dynamic>> saveInventoryReasonCode(Map<String, dynamic> body) async {
    final response = await _apiClient.put('/v2/inventory/reason-codes', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory reason code');
  }

  Future<List<Map<String, dynamic>>> inventoryPolicies({String? productId, String? warehouseId}) async {
    final response = await _apiClient.get('/v2/inventory/setup/policies', queryParameters: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
    });
    return _decodeListResponse(response.body, response.statusCode, 'inventory policies');
  }

  Future<Map<String, dynamic>> saveInventoryPolicy(Map<String, dynamic> body) async {
    final response = await _apiClient.put('/v2/inventory/setup/policies', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory policy');
  }

  Future<List<Map<String, dynamic>>> inventoryUomConversions(String productId) async {
    final response = await _apiClient.get('/v2/inventory/setup/products/$productId/uom-conversions');
    return _decodeListResponse(response.body, response.statusCode, 'inventory UOM conversions');
  }

  Future<Map<String, dynamic>> saveInventoryUomConversion(Map<String, dynamic> body) async {
    final response = await _apiClient.put('/v2/inventory/setup/uom-conversions', body: body);
    return _decodeMapResponse(response.body, response.statusCode, 'inventory UOM conversion');
  }

  Future<List<Map<String, dynamic>>> inventoryReferenceWarehouses(String workcentre) async {
    final response = await _apiClient.get('/v2/inventory/reference/warehouses', queryParameters: {'workcentre': workcentre});
    return _decodeListResponse(response.body, response.statusCode, 'inventory warehouses');
  }

  Future<List<Map<String, dynamic>>> inventoryReferenceLocations(String workcentre, String warehouseId) async {
    final response = await _apiClient.get('/v2/inventory/reference/locations', queryParameters: {'workcentre': workcentre, 'warehouseId': warehouseId});
    return _decodeListResponse(response.body, response.statusCode, 'inventory locations');
  }

  Future<List<Map<String, dynamic>>> inventoryReferenceProducts(String workcentre, {String? query}) async {
    final response = await _apiClient.get('/v2/inventory/reference/products', queryParameters: {
      'workcentre': workcentre,
      if (query != null && query.isNotEmpty) 'query': query,
    });
    return _decodeListResponse(response.body, response.statusCode, 'inventory products');
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
    throw AppException('Failed to save $label: $statusCode $body');
  }

  List<Map<String, dynamic>> _decodeListResponse(String body, int statusCode, String label) {
    if (statusCode < 200 || statusCode >= 300) {
      throw AppException('Failed to load $label: $statusCode $body');
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
