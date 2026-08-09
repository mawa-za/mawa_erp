import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../models/appointment_booking.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AppointmentBookingService {
  static final AppointmentBookingService _instance = AppointmentBookingService._internal();
  factory AppointmentBookingService() => _instance;
  AppointmentBookingService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<AppointmentBooking>> getAppointments({
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
    String? employeeId,
    String? customerId,
    String? status,
  }) async {
    final response = await _apiClient.get('/v2/appointment', queryParameters: {
      if (date != null) 'bookDate': DateFormat('yyyy-MM-dd').format(date),
      if (fromDate != null) 'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
      if (toDate != null) 'toDate': DateFormat('yyyy-MM-dd').format(toDate),
      if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
    });

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded is List
          ? decoded
          : decoded is Map && decoded['content'] is List
              ? decoded['content'] as List
              : <dynamic>[];
      final appointments = data
          .whereType<Map>()
          .map((item) => AppointmentBooking.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      appointments.sort((a, b) {
        final left = a.startsAt ?? DateTime(1900);
        final right = b.startsAt ?? DateTime(1900);
        return left.compareTo(right);
      });
      return appointments;
    }
    throw AppException('Failed to load appointments: ${response.statusCode} ${response.body}');
  }

  Future<AppointmentBooking> getAppointment(String id) async {
    final response = await _apiClient.get('/v2/appointment/$id');
    if (response.statusCode == 200) {
      return AppointmentBooking.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw AppException('Failed to load appointment: ${response.statusCode} ${response.body}');
  }

  Future<String> createAppointment({
    required String customerId,
    required String employeeId,
    required DateTime date,
    required String time,
    String? productId,
  }) async {
    final response = await _apiClient.post('/v2/appointment', body: {
      if (productId != null && productId.isNotEmpty) 'serviceProductId': productId,
      'customerPartnerId': customerId,
      'employeePartnerId': employeeId,
      'appointmentDate': DateFormat('yyyy-MM-dd').format(date),
      'startTime': time,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['id'] != null) return decoded['id'].toString();
      return '';
    }
    throw AppException('Failed to create appointment: ${response.statusCode} ${response.body}');
  }

  Future<void> updateAppointment({
    required String id,
    DateTime? date,
    String? time,
    String? employeeId,
    String? status,
  }) async {
    final response = await _apiClient.put('/v2/appointment/$id', body: {
      if (date != null) 'bookDate': DateFormat('yyyy-MM-dd').format(date),
      if (time != null && time.isNotEmpty) 'startTime': time,
      if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      if (status != null && status.isNotEmpty) 'status': status,
    });

    if (response.statusCode != 200) {
      throw AppException('Failed to update appointment: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> updateAppointmentStatus({
    required String id,
    required String status,
  }) async {
    final response = await _apiClient.put('/v2/appointment/$id/status', body: {
      'status': status,
    });

    if (response.statusCode != 200) {
      throw AppException('Failed to update appointment status: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createInvoiceForAppointment(String id) async {
    final response = await _apiClient.post('/v2/appointment/$id/invoice');
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    }
    throw AppException('Failed to invoice appointment: ${response.statusCode} ${response.body}');
  }

  Future<void> cancelAppointment(String id) async {
    final response = await _apiClient.delete('/v2/appointment/$id');
    if (response.statusCode != 200) {
      throw AppException('Failed to cancel appointment: ${response.statusCode} ${response.body}');
    }
  }
}
