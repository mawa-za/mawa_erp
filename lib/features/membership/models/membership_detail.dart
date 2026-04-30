import '../../../core/models/field_option.dart';

class MembershipDetail {
  final String id;
  final FieldOption type;
  final String number;
  final Member member;
  final SalesRepresentative salesRepresentative;
  final Product product;
  final double premium;
  final String dateJoined;
  final String? dateEffective;
  final FieldOption status;
  final List<MembershipProduct> products;

  MembershipDetail({
    required this.id,
    required this.type,
    required this.number,
    required this.member,
    required this.salesRepresentative,
    required this.product,
    required this.premium,
    required this.dateJoined,
    this.dateEffective,
    required this.status,
    required this.products,
  });

  factory MembershipDetail.fromJson(Map<String, dynamic> json) {
    return MembershipDetail(
      id: json['id'] ?? '',
      type: FieldOption.fromJson(json['type'] ?? {}),
      number: json['number'] ?? '',
      member: Member.fromJson(json['member'] ?? {}),
      salesRepresentative: SalesRepresentative.fromJson(json['salesRepresentative'] ?? {}),
      product: Product.fromJson(json['product'] ?? {}),
      premium: (json['premium'] ?? 0.0).toDouble(),
      dateJoined: json['dateJoined'] ?? '',
      dateEffective: json['dateEffective'],
      status: FieldOption.fromJson(json['status'] ?? {}),
      products: (json['products'] as List? ?? [])
          .map((p) => MembershipProduct.fromJson(p))
          .toList(),
    );
  }
}

class Member {
  final String id;
  final String number;
  final String firstName;
  final String lastName;
  final FieldOption? title;
  final FieldOption type;
  final Identity? identity;
  final String? birthDate;
  final FieldOption? gender;
  final FieldOption? status;

  Member({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    this.title,
    required this.type,
    this.identity,
    this.birthDate,
    this.gender,
    this.status,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      firstName: json['name2'] ?? '',
      lastName: json['name1'] ?? '',
      title: json['title'] != null ? FieldOption.fromJson(json['title']) : null,
      type: FieldOption.fromJson(json['type'] ?? {}),
      identity: json['identity'] != null ? Identity.fromJson(json['identity']) : null,
      birthDate: json['birthDate'],
      gender: json['gender'] != null ? FieldOption.fromJson(json['gender']) : null,
      status: json['status'] != null ? FieldOption.fromJson(json['status']) : null,
    );
  }
}

class Identity {
  final FieldOption type;
  final String number;

  Identity({required this.type, required this.number});

  factory Identity.fromJson(Map<String, dynamic> json) {
    return Identity(
      type: FieldOption.fromJson(json['type'] ?? {}),
      number: json['number'] ?? '',
    );
  }
}

class SalesRepresentative {
  final String id;
  final String number;
  final String firstName;
  final String lastName;
  final FieldOption? title;

  SalesRepresentative({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    this.title,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory SalesRepresentative.fromJson(Map<String, dynamic> json) {
    return SalesRepresentative(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      firstName: json['name2'] ?? '',
      lastName: json['name1'] ?? '',
      title: json['title'] != null ? FieldOption.fromJson(json['title']) : null,
    );
  }
}

class Product {
  final String id;
  final String code;
  final String description;
  final FieldOption? type;

  Product({
    required this.id,
    required this.code,
    required this.description,
    this.type,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] != null ? FieldOption.fromJson(json['type']) : null,
    );
  }
}

class MembershipProduct {
  final String item;
  final String product;
  final double unitPrice;
  final double quantity;
  final String validFrom;
  final String validTo;
  final String status;

  MembershipProduct({
    required this.item,
    required this.product,
    required this.unitPrice,
    required this.quantity,
    required this.validFrom,
    required this.validTo,
    required this.status,
  });

  factory MembershipProduct.fromJson(Map<String, dynamic> json) {
    return MembershipProduct(
      item: json['item'] ?? '',
      product: json['product'] ?? '',
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      validFrom: json['validFrom'] ?? '',
      validTo: json['validTo'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
