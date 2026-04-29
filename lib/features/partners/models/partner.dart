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
  });

  String get fullName {
    if (type == 'ORGANISATION' || type == 'GROUP') {
      return name1;
    }
    return [name2, name3, name1].where((s) => s.isNotEmpty).join(' ');
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    final typeObj = json['type'] as Map<String, dynamic>?;
    final identityObj = json['identity'] as Map<String, dynamic>?;
    final statusObj = json['status'] as Map<String, dynamic>?;
    final titleObj = json['title'] as Map<String, dynamic>?;
    final genderObj = json['gender'] as Map<String, dynamic>?;
    final maritalStatusObj = json['maritalStatus'] as Map<String, dynamic>?;
    final languageObj = json['language'] as Map<String, dynamic>?;

    return Partner(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      type: typeObj?['code'] ?? json['type']?.toString() ?? 'INDIVIDUAL',
      name1: json['name1'] ?? '',
      name2: json['name2'] ?? '',
      name3: json['name3'] ?? '',
      name4: json['name4'],
      identityNumber: identityObj?['number'] ?? json['identityNumber'] ?? '',
      idType: (identityObj?['type'] as Map?)?['description'] ?? '',
      status: statusObj?['description'] ?? json['status']?.toString() ?? 'Active',
      title: titleObj?['description'] ?? json['title'] ?? '',
      birthDate: json['birthDate'],
      gender: genderObj?['description'] ?? json['gender'] ?? '',
      maritalStatus: maritalStatusObj?['description'] ?? json['maritalStatus'] ?? '',
      language: languageObj?['description'] ?? json['language'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      addresses: (json['addresses'] as List? ?? [])
          .map((a) => PartnerAddress.fromJson(a))
          .toList(),
      identities: (json['identities'] as List? ?? [])
          .map((i) => PartnerIdentity.fromJson(i))
          .toList(),
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
