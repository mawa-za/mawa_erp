import '../../features/partners/models/partner.dart';

class User {
  final String id;
  final String username;
  final String? email;
  final String? cellphone;
  final String type;
  final String status;
  final Partner? partner;
  final String? passwordStatus;
  final String? validFrom;
  final String? validTo;

  User({
    required this.id,
    required this.username,
    this.email,
    this.cellphone,
    required this.type,
    required this.status,
    this.partner,
    this.passwordStatus,
    this.validFrom,
    this.validTo,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: json['email']?.toString(),
      cellphone: json['cellphone']?.toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      partner: json['partner'] != null && json['partner'] is Map
          ? Partner.fromJson(Map<String, dynamic>.from(json['partner']))
          : null,
      passwordStatus: json['passwordStatus']?.toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'cellphone': cellphone,
      'type': type,
      'status': status,
      'partner': partner?.toJson(),
      'passwordStatus': passwordStatus,
      'validFrom': validFrom,
      'validTo': validTo,
    };
  }
}
