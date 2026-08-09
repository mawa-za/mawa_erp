import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/service_order.dart';

class ServiceOrderService {
  final ApiClient _apiClient = ApiClient();

  Future<ServiceOrder> create({
    required String customerPartnerId,
    required DateTime orderDate,
    String status = 'DRAFT',
    String location = '',
    String notes = '',
    String? assignedEmployeePartnerId,
    String? salesAreaId,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
    List<ServiceOrderLine> lines = const [],
  }) async {
    final response = await _apiClient.post('/v2/service-orders', body: {
      'customerPartnerId': customerPartnerId,
      'orderDate': orderDate.toIso8601String().split('T').first,
      'status': status,
      'location': location,
      'notes': notes,
      if (assignedEmployeePartnerId != null)
        'assignedEmployeePartnerId': assignedEmployeePartnerId,
      if (salesAreaId != null) 'salesAreaId': salesAreaId,
      if (scheduledStartAt != null)
        'scheduledStartAt': scheduledStartAt.toIso8601String(),
      if (scheduledEndAt != null)
        'scheduledEndAt': scheduledEndAt.toIso8601String(),
      'lines': lines.map((line) => line.toJson()).toList(),
    });
    return _decodeOrder(response.statusCode, response.body, 'create');
  }

  Future<ServiceOrder> createFromAppointment(String appointmentId) async {
    final response = await _apiClient.post(
      '/v2/service-orders/from-appointment/$appointmentId',
    );
    return _decodeOrder(response.statusCode, response.body, 'create');
  }

  Future<ServiceOrder> createFromServiceRequest(
    String serviceRequestId, {
    bool additional = false,
  }) async {
    final suffix = additional ? '?additional=true' : '';
    final response = await _apiClient.post(
      '/v2/service-orders/from-service-request/$serviceRequestId$suffix',
    );
    return _decodeOrder(response.statusCode, response.body, 'create');
  }

  Future<List<ServiceOrder>> search({
    String? status,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryParameters = <String, String>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (customerId != null && customerId.trim().isNotEmpty)
        'customerId': customerId.trim(),
      if (fromDate != null)
        'fromDate': fromDate.toIso8601String().split('T').first,
      if (toDate != null) 'toDate': toDate.toIso8601String().split('T').first,
    };
    final response = await _apiClient.get(
      '/v2/service-orders',
      queryParameters: queryParameters,
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (order) => ServiceOrder.fromJson(
                Map<String, dynamic>.from(order),
              ),
            )
            .toList();
      }
      return <ServiceOrder>[];
    }
    throw AppException(
      'Failed to load service orders: ${response.statusCode} ${response.body}',
    );
  }

  Future<ServiceOrder> get(String id) async {
    final response = await _apiClient.get('/v2/service-orders/$id');
    return _decodeOrder(response.statusCode, response.body, 'load');
  }

  Future<ServiceOrder> update({
    required String id,
    required String status,
    required DateTime orderDate,
    required String location,
    required String notes,
    required List<ServiceOrderLine> lines,
    String? assignedEmployeePartnerId,
    String? salesAreaId,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
  }) async {
    final response = await _apiClient.put('/v2/service-orders/$id', body: {
      'status': status,
      'orderDate': orderDate.toIso8601String().split('T').first,
      'location': location,
      'notes': notes,
      if (assignedEmployeePartnerId != null)
        'assignedEmployeePartnerId': assignedEmployeePartnerId,
      if (salesAreaId != null) 'salesAreaId': salesAreaId,
      if (scheduledStartAt != null)
        'scheduledStartAt': scheduledStartAt.toIso8601String(),
      if (scheduledEndAt != null)
        'scheduledEndAt': scheduledEndAt.toIso8601String(),
      'lines': lines.map((line) => line.toJson()).toList(),
    });
    return _decodeOrder(response.statusCode, response.body, 'save');
  }

  Future<Map<String, dynamic>> createInvoice(String id) async {
    final response = await _apiClient.post('/v2/service-orders/$id/invoice');
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    }
    throw AppException(
      'Failed to invoice service order: ${response.statusCode} ${response.body}',
    );
  }

  ServiceOrder _decodeOrder(int statusCode, String body, String action) {
    if (statusCode == 200 || statusCode == 201) {
      return ServiceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(body) as Map),
      );
    }
    throw AppException(
      'Failed to $action service order: $statusCode $body',
    );
  }
}
