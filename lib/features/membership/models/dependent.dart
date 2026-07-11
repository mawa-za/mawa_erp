import '../../../core/models/field_option.dart';

enum DependentType {
  ANY,
  MAIN_MEMBER,
  SPOUSE,
  CHILD,
  PARENT,
  EXTENDED_FAMILY,
  OTHER;

  String get label {
    switch (this) {
      case DependentType.ANY: return 'Any';
      case DependentType.MAIN_MEMBER: return 'Main Member';
      case DependentType.SPOUSE: return 'Spouse';
      case DependentType.CHILD: return 'Child';
      case DependentType.PARENT: return 'Parent';
      case DependentType.EXTENDED_FAMILY: return 'Extended Family';
      case DependentType.OTHER: return 'Other';
    }
  }

  static DependentType fromString(String? value) {
    if (value == null) return DependentType.OTHER;
    return DependentType.values.firstWhere(
      (e) => e.name == value || e.name == value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_'),
      orElse: () => DependentType.OTHER,
    );
  }
}

class Dependent {
  final String id;
  final String membershipId;
  final String dependentPartnerId;
  final String dependentType;
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
    required this.dependentType,
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

    String? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is List && date.length >= 3) {
        try {
          final year = date[0].toString();
          final month = date[1].toString().padLeft(2, '0');
          final day = date[2].toString().padLeft(2, '0');

          if (date.length >= 5) {
            final hour = date[3].toString().padLeft(2, '0');
            final minute = date[4].toString().padLeft(2, '0');
            return '$year-$month-$day $hour:$minute';
          }
          return '$year-$month-$day';
        } catch (e) {
          return date.toString();
        }
      }
      return date.toString();
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
      final idNum = json['identityNumber'] ?? json['identityNo'] ?? json['idNumber'] ?? json['id_number'] ?? json['identity_no'] ?? json['id_no'] ??
                    depPartnerMap?['identityNumber'] ?? depPartnerMap?['identityNo'] ?? depPartnerMap?['idNumber'] ?? depPartnerMap?['id_number'] ?? depPartnerMap?['identity_no'] ?? depPartnerMap?['id_no'];
      if (idNum != null && idNum.toString().isNotEmpty) {
        identity = DependentIdentity(
          type: FieldOption(
            field: 'IDENTITY-TYPE',
            code: 'ID', 
            type: 'ID',
            description: 'ID',
            validFrom: '',
            validTo: '',
          ),
          number: idNum.toString(),
        );
      }
    }

    // Name handling with more fallbacks
    String fName = (json['firstName'] ?? json['first_name'] ?? json['name2'] ?? depPartnerMap?['name2'] ?? depPartnerMap?['firstName'] ?? depPartnerMap?['first_name'] ?? '').toString();
    String lName = (json['lastName'] ?? json['last_name'] ?? json['name1'] ?? depPartnerMap?['name1'] ?? depPartnerMap?['lastName'] ?? depPartnerMap?['last_name'] ?? '').toString();
    
    if (fName.isEmpty && lName.isEmpty) {
      final fullNameVal = (json['fullName'] ?? json['full_name'] ?? json['name'] ?? depPartnerMap?['fullName'] ?? depPartnerMap?['full_name'] ?? depPartnerMap?['name'] ?? '').toString();
      if (fullNameVal.isNotEmpty) {
        final parts = fullNameVal.split(' ');
        if (parts.length > 1) {
          fName = parts.sublist(0, parts.length - 1).join(' ');
          lName = parts.last;
        } else {
          fName = fullNameVal;
        }
      }
    }

    return Dependent(
      id: (json['id'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      dependentPartnerId: depPartnerId,
      dependentType: (json['dependentType'] ?? json['relationship'] ?? '').toString(),
      active: json['active'] ?? true,
      firstName: fName,
      lastName: lName,
      number: (json['number'] ?? json['partnerNo'] ?? json['partnerNumber'] ?? 
               depPartnerMap?['number'] ?? depPartnerMap?['partnerNo'] ?? depPartnerMap?['partnerNumber'] ?? '').toString(),
      status: FieldOption.fromDynamic(json['status']),
      title: FieldOption.fromDynamic(json['title']),
      birthDate: parseDate(json['birthDate'] ?? json['dateOfBirth'] ?? depPartnerMap?['birthDate'] ?? depPartnerMap?['dateOfBirth']),
      gender: FieldOption.fromDynamic(json['gender']),
      maritalStatus: FieldOption.fromDynamic(json['maritalStatus']),
      identity: identity,
      createdAt: parseDate(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membershipId': membershipId,
      'dependentPartnerId': dependentPartnerId,
      'dependentType': dependentType,
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
      type: FieldOption.fromDynamic(json['type']),
      number: (json['number'] ?? '').toString(),
    );
  }
}
