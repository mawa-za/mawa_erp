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

  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Unnamed Dependent';
    return parts.join(' ');
  }

  factory Dependent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      if (value == null) return null;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final depPartner = json['dependentPartner'] ?? json['dependentPartnerId'] ?? json['partnerId'] ?? json['partner'] ?? json['dependentPartnerPartner'];
    final depPartnerMap = asMap(depPartner);
    
    final String depPartnerId = depPartnerMap != null 
        ? (depPartnerMap['id'] ?? depPartnerMap['partnerId'] ?? depPartnerMap['partner'] ?? '').toString() 
        : (depPartner ?? '').toString();

    // Identity handling
    final identityObj = asMap(json['identity']);
    DependentIdentity? identity;
    if (identityObj != null) {
      identity = DependentIdentity.fromJson(identityObj);
    } else {
      final idNum = json['identityNumber'] ?? json['identityNo'] ?? json['idNumber'] ?? 
                    depPartnerMap?['identityNumber'] ?? depPartnerMap?['identityNo'] ?? depPartnerMap?['idNumber'];
      if (idNum != null && idNum.toString().isNotEmpty) {
        identity = DependentIdentity(
          type: FieldOption(code: 'ID', description: 'ID'),
          number: idNum.toString(),
        );
      }
    }

    // Name handling with more fallbacks
    String fName = (json['firstName'] ?? json['name2'] ?? depPartnerMap?['name2'] ?? depPartnerMap?['firstName'] ?? '').toString();
    String lName = (json['lastName'] ?? json['name1'] ?? depPartnerMap?['name1'] ?? depPartnerMap?['lastName'] ?? '').toString();
    
    if (fName.isEmpty && lName.isEmpty) {
      final fullName = (json['fullName'] ?? json['name'] ?? depPartnerMap?['fullName'] ?? depPartnerMap?['name'] ?? '').toString();
      if (fullName.isNotEmpty) {
        final parts = fullName.split(' ');
        if (parts.length > 1) {
          fName = parts.sublist(0, parts.length - 1).join(' ');
          lName = parts.last;
        } else {
          fName = fullName;
        }
      }
    }

    return Dependent(
      id: (json['id'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      dependentPartnerId: depPartnerId,
      relationship: (json['relationship'] ?? '').toString(),
      active: json['active'] ?? true,
      firstName: fName,
      lastName: lName,
      number: (json['number'] ?? json['partnerNo'] ?? json['partnerNumber'] ?? 
               depPartnerMap?['number'] ?? depPartnerMap?['partnerNo'] ?? depPartnerMap?['partnerNumber'] ?? '').toString(),
      status: json['status'] != null ? FieldOption.fromJson(asMap(json['status']) ?? {}) : null,
      title: json['title'] != null ? FieldOption.fromJson(asMap(json['title']) ?? {}) : null,
      birthDate: (json['birthDate'] ?? json['dateOfBirth'] ?? depPartnerMap?['birthDate'] ?? depPartnerMap?['dateOfBirth'])?.toString(),
      gender: json['gender'] != null ? FieldOption.fromJson(asMap(json['gender']) ?? {}) : null,
      maritalStatus: json['maritalStatus'] != null ? FieldOption.fromJson(asMap(json['maritalStatus']) ?? {}) : null,
      identity: identity,
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
      type: FieldOption.fromJson(json['type'] is Map ? Map<String, dynamic>.from(json['type']) : {}),
      number: (json['number'] ?? '').toString(),
    );
  }
}
