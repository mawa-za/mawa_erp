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
    return [name2, name3, name1].where((s) => s.isNotEmpty).join(' ');
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      return value is Map<String, dynamic> ? value : null;
    }

    final typeObj = asMap(json['type']);
    final identityObj = asMap(json['identity']);
    final statusObj = asMap(json['status']);
    final titleObj = asMap(json['title']);
    final genderObj = asMap(json['gender']);
    final maritalStatusObj = asMap(json['maritalStatus']);
    final languageObj = asMap(json['language']);

    final id = json['id'] ?? json['partnerId'] ?? '';
    final number = json['number'] ?? json['partnerNo'] ?? '';
    
    String type = typeObj?['code'] ?? json['partnerType'] ?? '';
    if (type.isEmpty && json['type'] != null && json['type'] is String) {
      type = json['type'];
    }
    if (type.isEmpty) type = 'INDIVIDUAL';

    List<String> roles = [];
    if (json['roles'] is List) {
      roles = (json['roles'] as List).map((r) => r.toString()).toList();
    }
    if (roles.isEmpty && json['partnerRole'] != null) {
      roles = [json['partnerRole'].toString()];
    }

    String? rawBirthDate = json['birthDate'];
    String? formattedBirthDate = rawBirthDate;
    if (rawBirthDate != null && rawBirthDate.contains(',')) {
      try {
        // Try short format first (e.g., Jan 23, 1995)
        final format = DateFormat("MMM d, yyyy");
        final date = format.parse(rawBirthDate);
        formattedBirthDate = date.toIso8601String();
      } catch (_) {
        try {
          // Try long format (e.g., Sep 5, 2024, 12:00:00 AM)
          final format = DateFormat("MMM d, yyyy, hh:mm:ss a");
          final date = format.parse(rawBirthDate);
          formattedBirthDate = date.toIso8601String();
        } catch (_) {}
      }
    }

    return Partner(
      id: id,
      number: number,
      type: type,
      name1: (json['name1'] ?? '').toString().trim(),
      name2: (json['name2'] ?? '').toString().trim(),
      name3: (json['name3'] ?? '').toString().trim(),
      name4: json['name4'],
      identityNumber: identityObj?['number'] ?? json['identityNumber'] ?? '',
      idType: (identityObj?['type'] as Map?)?['description'] ?? json['identityType'] ?? '',
      status: statusObj?['code'] ?? statusObj?['description'] ?? (json['status'] is String ? json['status'] : 'ACTIVE'),
      title: titleObj?['code'] ?? titleObj?['description'] ?? (json['title'] is String ? json['title'] : ''),
      birthDate: formattedBirthDate,
      gender: genderObj?['code'] ?? genderObj?['description'] ?? (json['gender'] is String ? json['gender'] : ''),
      maritalStatus: maritalStatusObj?['code'] ?? maritalStatusObj?['description'] ?? (json['maritalStatus'] is String ? json['maritalStatus'] : ''),
      language: languageObj?['description'] ?? (json['language'] is String ? json['language'] : ''),
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      addresses: (json['addresses'] as List? ?? [])
          .map((a) => PartnerAddress.fromJson(a))
          .toList(),
      identities: (json['identities'] as List? ?? [])
          .map((i) => PartnerIdentity.fromJson(i))
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
  final String type; // POSTAL, RESIDENTIAL, OFFICE
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
      id: json['id'] ?? '',
      objectId: json['objectId'],
      type: json['type'] ?? 'RESIDENTIAL',
      line1: json['line1'] ?? '',
      line2: json['line2'] ?? '',
      line3: json['line3'] ?? '',
      line4: json['line4'] ?? '',
      suburb: json['suburb'] ?? '',
      town: json['town'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? json['province'] ?? '',
      province: json['province'] ?? json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      country: json['country'] ?? 'South Africa',
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
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      validFrom: json['validFrom'],
      validTo: json['validTo'],
    );
  }
}

class PartnerContact {
  final String? partner;
  final String type; // TELEPHONE, EMAIL-ADDRESS
  final String value;
  final String? validFrom;
  final String? validTo;

  PartnerContact({
    this.partner,
    required this.type,
    required this.value,
    this.validFrom,
    this.validTo,
  });

  factory PartnerContact.fromJson(Map<String, dynamic> json) {
    return PartnerContact(
      partner: json['partner'],
      type: json['type'] ?? '',
      value: json['value'] ?? '',
      validFrom: json['validFrom'],
      validTo: json['validTo'],
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
