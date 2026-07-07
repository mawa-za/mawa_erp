import 'package:intl/intl.dart';

import '../../partners/models/partner.dart';

class AppointmentBooking {
  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final String time;
  final String duration;
  final String createdOn;
  final Partner? customer;
  final Partner? employeeResponsible;
  final String? productId;
  final String productDescription;

  const AppointmentBooking({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.time,
    required this.duration,
    required this.createdOn,
    this.customer,
    this.employeeResponsible,
    this.productId,
    required this.productDescription,
  });

  factory AppointmentBooking.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final customerJson = asMap(json['customerPartner'] ?? json['customer']);
    final employeeJson = asMap(json['employeeResponsible'] ?? json['employeePartner'] ?? json['employee']);
    final productJson = asMap(json['product'] ?? json['productDto']);

    return AppointmentBooking(
      id: (json['id'] ?? '').toString(),
      number: (json['appointmentNo'] ?? json['number'] ?? '').toString(),
      status: (json['status'] ?? 'BOOKED').toString(),
      date: parseDate(json['appointmentDate'] ?? json['bookDate'] ?? json['date']),
      time: normalizeTime(json['startTime'] ?? json['bookTime'] ?? json['time']),
      duration: (json['durationMinutes'] ?? json['duration'] ?? '').toString(),
      createdOn: (json['createdOn'] ?? '').toString(),
      customer: customerJson == null ? null : Partner.fromJson(customerJson),
      employeeResponsible: employeeJson == null ? null : Partner.fromJson(employeeJson),
      productId: productJson?['id']?.toString() ?? json['serviceProductId']?.toString() ?? json['productId']?.toString(),
      productDescription: (productJson?['description'] ?? productJson?['name'] ?? json['productDescription'] ?? '').toString(),
    );
  }


  static String normalizeTime(dynamic raw) {
    if (raw == null) return '';
    if (raw is List && raw.length >= 2) {
      final hour = int.tryParse(raw[0].toString()) ?? 0;
      final minute = int.tryParse(raw[1].toString()) ?? 0;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final value = raw.toString().trim();
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is List && raw.length >= 3) {
      return DateTime(
        int.tryParse(raw[0].toString()) ?? 0,
        int.tryParse(raw[1].toString()) ?? 1,
        int.tryParse(raw[2].toString()) ?? 1,
      );
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    for (final format in ['yyyy-MM-dd', 'dd/MM/yyyy', 'yyyy/MM/dd']) {
      try {
        return DateFormat(format).parseStrict(value);
      } catch (_) {}
    }
    return DateTime.tryParse(value);
  }

  DateTime? get startsAt {
    if (date == null) return null;
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date!.year, date!.month, date!.day, hour, minute);
  }

  String get dateLabel => date == null ? '-' : DateFormat('yyyy-MM-dd').format(date!);

  String get timeLabel => time.isEmpty ? '-' : time;

  String get customerName => customer?.fullName ?? 'No customer';

  String get employeeName => employeeResponsible?.fullName ?? 'Unassigned';

  String get serviceName => productDescription.isEmpty ? 'Appointment' : productDescription;

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isBooked => status.toUpperCase() == 'BOOKED';

  bool get isProcessed => status.toUpperCase() == 'PROCESSED';
}
