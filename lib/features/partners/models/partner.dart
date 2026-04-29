class Partner {
  final String id;
  final String number;
  final String type; // INDIVIDUAL, ORGANISATION, GROUP
  final String name1; // Last Name / Organisation Name
  final String name2; // First Name
  final String name3; // Middle Name
  final String identityNumber;
  final String email;
  final String phone;
  final List<PartnerAddress> addresses;

  Partner({
    required this.id,
    required this.number,
    required this.type,
    required this.name1,
    required this.name2,
    required this.name3,
    required this.identityNumber,
    this.email = '',
    this.phone = '',
    this.addresses = const [],
  });

  String get fullName {
    if (type == 'ORGANISATION' || type == 'GROUP') {
      return name1;
    }
    return [name2, name3, name1].where((s) => s.isNotEmpty).join(' ');
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] ?? json['partnerId'] ?? '',
      number: json['number'] ?? json['partnerNo'] ?? '',
      type: json['type'] ?? 'INDIVIDUAL',
      name1: json['name1'] ?? '',
      name2: json['name2'] ?? '',
      name3: json['name3'] ?? '',
      identityNumber: json['identityNumber'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      addresses: (json['addresses'] as List? ?? [])
          .map((a) => PartnerAddress.fromJson(a))
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
      'identityNumber': identityNumber,
      'email': email,
      'phone': phone,
      'addresses': addresses.map((a) => a.toJson()).toList(),
    };
  }
}

class PartnerAddress {
  final String id;
  final String type; // POSTAL, RESIDENTIAL, OFFICE
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  PartnerAddress({
    this.id = '',
    required this.type,
    required this.line1,
    this.line2 = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'South Africa',
  });

  factory PartnerAddress.fromJson(Map<String, dynamic> json) {
    return PartnerAddress(
      id: json['id'] ?? '',
      type: json['type'] ?? 'RESIDENTIAL',
      line1: json['line1'] ?? '',
      line2: json['line2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      country: json['country'] ?? 'South Africa',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'type': type,
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
    };
  }
}
