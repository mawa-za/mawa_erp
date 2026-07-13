import 'package:intl/intl.dart';
import 'partner_identity.dart';

class Partner {
  final String id;
  final String number;
  final String type; // INDIVIDUAL, ORGANISATION, GROUP
  final String name1; // Last Name / Organisation Name
  final String name2; // First Name
  final String name3; // Middle Name
  final String? name4;
  final String identityNumber;
  final String? idType;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String status;
  final String? title;
  final String? birthDate;
  final String? maritalStatus;
  final String? gender;
  final String? language;
  final String email;
  final String phone;
  final List<PartnerAddress> addresses;
  final List<PartnerIdentity> identities;
  final List<String> roles;

  Partner({
    required this.id,
    required this.number,
    required this.type,
    required this.name1,
    required this.name2,
    required this.name3,
    this.name4,
    required this.identityNumber,
    this.idType,
    this.validFrom,
    this.validTo,
    required this.status,
    this.title,
    this.birthDate,
    this.maritalStatus,
    this.gender,
    this.language,
    this.email = '',
    this.phone = '',
    this.addresses = const [],
    this.identities = const [],
    this.roles = const [],
  });

  String get fullName {
    if (type == 'ORGANISATION' || type == 'GROUP') {
      return name1;
    }
    final parts = [name2, name3, name1].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Unnamed Partner';
    return parts.join(' ');
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      if (value == null) return null;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    String getStringFromObj(dynamic obj, {String key = 'code'}) {
      if (obj == null) return '';
      if (obj is String) return obj;
      if (obj is Map) return (obj[key] ?? obj['description'] ?? '').toString();
      return obj.toString();
    }

    DateTime? parseToDateTime(dynamic value) {
      return PartnerIdentity.parseDate(value);
    }

    String? parseToIsoString(dynamic rawDate) {
      final dt = parseToDateTime(rawDate);
      return dt?.toIso8601String();
    }

    // Support both PartnerDto (id/number) and PartnerViewEntity/PartnerOutboundDto (partnerId/partnerNo)
    final id = (json['id'] ?? json['partnerId'] ?? '').toString();
    final number = (json['number'] ?? json['partnerNo'] ?? '').toString();
    
    final type = getStringFromObj(json['type'] ?? json['partnerType']);
    final status = getStringFromObj(json['status']);
    final title = getStringFromObj(json['title']);
    final gender = getStringFromObj(json['gender']);
    final maritalStatus = getStringFromObj(json['maritalStatus']);
    final language = getStringFromObj(json['language'], key: 'description');

    final identityObj = asMap(json['identity']);

    List<String> roles = [];
    if (json['roles'] is List) {
      roles = (json['roles'] as List).map((r) => r.toString()).toList();
    } else if (json['partnerRole'] != null) {
      roles = [json['partnerRole'].toString()];
    }

    return Partner(
      id: id,
      number: number,
      type: type.isEmpty ? 'INDIVIDUAL' : type,
      name1: (json['name1'] ?? json['lastName'] ?? '').toString().trim(),
      name2: (json['name2'] ?? json['firstName'] ?? '').toString().trim(),
      name3: (json['name3'] ?? json['middleName'] ?? '').toString().trim(),
      name4: json['name4']?.toString(),
      identityNumber: (identityObj?['number'] ?? json['identityNumber'] ?? '').toString(),
      idType: getStringFromObj(identityObj?['type'], key: 'description') != ''
                ? getStringFromObj(identityObj?['type'], key: 'description')
                : (json['identityType'] ?? 'ID').toString(),
      validFrom: parseToDateTime(identityObj?['validFrom'] ?? identityObj?['valid_from'] ?? json['validFrom'] ?? json['valid_from'] ?? json['startDate'] ?? json['effectiveDate']),
      validTo: parseToDateTime(identityObj?['validTo'] ?? identityObj?['valid_to'] ?? json['validTo'] ?? json['valid_to'] ?? json['expiryDate'] ?? json['expiry_date'] ?? json['endDate'] ?? json['validUntil'] ?? json['valid_until'] ?? json['expiredAt']),
      status: status.isEmpty ? 'ACTIVE' : status,
      title: title,
      birthDate: parseToIsoString(json['birthDate']),
      gender: gender,
      maritalStatus: maritalStatus,
      language: language,
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? json['contactNumber'] ?? json['cellphone'] ?? '').toString(),
      addresses: (json['addresses'] as List? ?? [])
          .map((a) => PartnerAddress.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      identities: (json['identities'] as List? ?? [])
          .map((i) => PartnerIdentity.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'type': type,
      'name1': name1,
      'name2': name2,
      'name3': name3,
      if (name4 != null) 'name4': name4,
      'identityNumber': identityNumber,
      'title': title,
      'birthDate': birthDate,
      'maritalStatus': maritalStatus,
      'gender': gender,
      'language': language,
      'email': email,
      'phone': phone,
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'identities': identities.map((i) => i.toJson()).toList(),
      'roles': roles,
      'status': status,
    };
  }
}

class PartnerAddress {
  final String id;
  final String? objectId;
  final String type; 
  final String line1;
  final String line2;
  final String line3;
  final String line4;
  final String suburb;
  final String town;
  final String city;
  final String state;
  final String province;
  final String postalCode;
  final String country;

  PartnerAddress({
    this.id = '',
    this.objectId,
    required this.type,
    required this.line1,
    this.line2 = '',
    this.line3 = '',
    this.line4 = '',
    this.suburb = '',
    this.town = '',
    required this.city,
    this.state = '',
    this.province = '',
    required this.postalCode,
    this.country = 'South Africa',
  });

  factory PartnerAddress.fromJson(Map<String, dynamic> json) {
    return PartnerAddress(
      id: (json['id'] ?? '').toString(),
      objectId: json['objectId']?.toString(),
      type: (json['type'] ?? 'RESIDENTIAL').toString(),
      line1: (json['line1'] ?? '').toString(),
      line2: (json['line2'] ?? '').toString(),
      line3: (json['line3'] ?? '').toString(),
      line4: (json['line4'] ?? '').toString(),
      suburb: (json['suburb'] ?? '').toString(),
      town: (json['town'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? json['province'] ?? '').toString(),
      province: (json['province'] ?? json['state'] ?? '').toString(),
      postalCode: (json['postalCode'] ?? '').toString(),
      country: (json['country'] ?? 'South Africa').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (objectId != null) 'objectId': objectId,
      'type': type,
      'line1': line1,
      'line2': line2,
      'line3': line3,
      'line4': line4,
      'suburb': suburb,
      'town': town,
      'city': city,
      'province': province.isNotEmpty ? province : state,
      'postalCode': postalCode,
      'country': country,
    };
  }
}

class PartnerRole {
  final String id;
  final String description;
  final String? validFrom;
  final String? validTo;

  PartnerRole({
    required this.id,
    required this.description,
    this.validFrom,
    this.validTo,
  });

  factory PartnerRole.fromJson(Map<String, dynamic> json) {
    return PartnerRole(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
    );
  }
}

class PartnerContact {
  final String? partner;
  final String type; 
  final String value;
  final String? description;
  final String? validFrom;
  final String? validTo;

  PartnerContact({
    this.partner,
    required this.type,
    required this.value,
    this.description,
    this.validFrom,
    this.validTo,
  });

  factory PartnerContact.fromJson(Map<String, dynamic> json) {
    return PartnerContact(
      partner: json['partner']?.toString(),
      type: (json['type'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      description: json['description']?.toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (partner != null) 'partner': partner,
      'type': type,
      'value': value,
      if (validFrom != null) 'validFrom': validFrom,
      if (validTo != null) 'validTo': validTo,
    };
  }
}

class PartnerAttribute {
  final String? partner;
  final String attribute;
  final String value;
  final String? validFrom;
  final String? validTo;

  PartnerAttribute({
    this.partner,
    required this.attribute,
    required this.value,
    this.validFrom,
    this.validTo,
  });

  factory PartnerAttribute.fromJson(Map<String, dynamic> json) {
    return PartnerAttribute(
      partner: json['partner']?.toString(),
      attribute: (json['attribute'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (partner != null) 'partner': partner,
      'attribute': attribute,
      'value': value,
      if (validFrom != null) 'validFrom': validFrom,
      if (validTo != null) 'validTo': validTo,
    };
  }
}
