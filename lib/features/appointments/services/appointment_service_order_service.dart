import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/appointment_service_order.dart';

class AppointmentServiceOrderService {
  final ApiClient _apiClient = ApiClient();

  Future<AppointmentServiceOrder> createFromAppointment(
    String appointmentId,
  ) async {
    final response = await _apiClient.post(
      '/v2/service-order/from-appointment/$appointmentId',
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AppointmentServiceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw AppException(
      'Failed to create service order: ${response.statusCode} ${response.body}',
    );
  }

  Future<AppointmentServiceOrder> get(String id) async {
    final response = await _apiClient.get('/v2/service-order/$id');
    if (response.statusCode == 200) {
      return AppointmentServiceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw AppException(
      'Failed to load service order: ${response.statusCode} ${response.body}',
    );
  }

  Future<AppointmentServiceOrder> update({
    required String id,
    required String status,
    required DateTime serviceDate,
    required String location,
    required String notes,
    required List<AppointmentServiceOrderLine> lines,
    String? assignedEmployeePartnerId,
  }) async {
    final response = await _apiClient.put('/v2/service-order/$id', body: {
      'status': status,
      'serviceDate': serviceDate.toIso8601String().split('T').first,
      'location': location,
      'notes': notes,
      if (assignedEmployeePartnerId != null)
        'assignedEmployeePartnerId': assignedEmployeePartnerId,
      'lines': lines.map((line) => line.toJson()).toList(),
    });
    if (response.statusCode == 200) {
      return AppointmentServiceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw AppException(
      'Failed to save service order: ${response.statusCode} ${response.body}',
    );
  }

  Future<Map<String, dynamic>> createInvoice(String id) async {
    final response = await _apiClient.post('/v2/service-order/$id/invoice');
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
}
