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

  factory CaseEvent.fromJson(Map<String, dynamic> json) {
    return CaseEvent(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      eventType: (json['eventType'] ?? 'OTHER').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startAt: DateTime.parse(json['startAt']),
      endAt: json['endAt'] != null ? DateTime.parse(json['endAt']) : null,
      location: json['location']?.toString(),
      reminderAt: json['reminderAt'] != null ? DateTime.parse(json['reminderAt']) : null,
      status: (json['status'] ?? 'SCHEDULED').toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
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
