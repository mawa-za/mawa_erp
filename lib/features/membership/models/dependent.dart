import '../../../core/models/field_option.dart';

class Dependent {
  final String id;
  final String membershipId;
  final String dependentPartnerId;
  final String relationship;
  final bool active;
  
  // Enriched fields for UI
  final String firstName;
  final String lastName;
  final String number;
  final FieldOption? status;
  final FieldOption? title;
  final String? birthDate;
  final FieldOption? gender;
  final FieldOption? maritalStatus;
  final DependentIdentity? identity;

  final String? createdAt;
  final String createdBy;
  final String? updatedAt;
  final String? updatedBy;

  Dependent({
    required this.id,
    required this.membershipId,
    required this.dependentPartnerId,
    required this.relationship,
    required this.active,
    this.firstName = '',
    this.lastName = '',
    this.number = '',
    this.status,
    this.title,
    this.birthDate,
    this.gender,
    this.maritalStatus,
    this.identity,
    this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: (json['id'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      dependentPartnerId: (json['dependentPartnerId'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      active: json['active'] ?? true,
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      status: json['status'] != null ? FieldOption.fromJson(json['status']) : null,
      title: json['title'] != null ? FieldOption.fromJson(json['title']) : null,
      birthDate: json['birthDate']?.toString(),
      gender: json['gender'] != null ? FieldOption.fromJson(json['gender']) : null,
      maritalStatus: json['maritalStatus'] != null ? FieldOption.fromJson(json['maritalStatus']) : null,
      identity: json['identity'] != null ? DependentIdentity.fromJson(json['identity']) : null,
      createdAt: json['createdAt']?.toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: json['updatedAt']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membershipId': membershipId,
      'dependentPartnerId': dependentPartnerId,
      'relationship': relationship,
      'active': active,
      'firstName': firstName,
      'lastName': lastName,
      'number': number,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }
}

class DependentIdentity {
  final FieldOption type;
  final String number;

  DependentIdentity({required this.type, required this.number});

  factory DependentIdentity.fromJson(Map<String, dynamic> json) {
    return DependentIdentity(
      type: FieldOption.fromJson(json['type'] ?? {}),
      number: (json['number'] ?? '').toString(),
    );
  }
}
