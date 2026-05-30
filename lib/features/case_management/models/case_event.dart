import 'package:intl/intl.dart';

class CaseEvent {
  final String id;
  final String caseId;
  final String eventType;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final DateTime? reminderAt;
  final String status;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  CaseEvent({
    required this.id,
    required this.caseId,
    required this.eventType,
    required this.title,
    this.description,
    required this.startAt,
    this.endAt,
    this.location,
    this.reminderAt,
    required this.status,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    if (date is List) {
      if (date.length >= 3) {
        try {
          return DateTime(
            (date[0] as num).toInt(),
            (date[1] as num).toInt(),
            (date[2] as num).toInt(),
            date.length >= 4 ? (date[3] as num).toInt() : 0,
            date.length >= 5 ? (date[4] as num).toInt() : 0,
            date.length >= 6 ? (date[5] as num).toInt() : 0,
          );
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  factory CaseEvent.fromJson(Map<String, dynamic> json) {
    return CaseEvent(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      eventType: (json['eventType'] ?? 'OTHER').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startAt: _parseDate(json['startAt']) ?? DateTime.now(),
      endAt: _parseDate(json['endAt']),
      location: json['location']?.toString(),
      reminderAt: _parseDate(json['reminderAt']),
      status: (json['status'] ?? 'SCHEDULED').toString(),
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'eventType': eventType,
      'title': title,
      'description': description,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'location': location,
      'reminderAt': reminderAt?.toIso8601String(),
      'status': status,
    };
  }
}

class CreateCaseEventRequest {
  final String eventType;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final DateTime? reminderAt;

  CreateCaseEventRequest({
    required this.eventType,
    required this.title,
    this.description,
    required this.startAt,
    this.endAt,
    this.location,
    this.reminderAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'title': title,
      'description': description,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'location': location,
      'reminderAt': reminderAt?.toIso8601String(),
    };
  }
}

class UpdateCaseEventStatusRequest {
  final String status;

  UpdateCaseEventStatusRequest({required this.status});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
    };
  }
}
