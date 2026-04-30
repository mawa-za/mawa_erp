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
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      cellphone: json['cellphone'],
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      partner: json['partner'] != null ? Partner.fromJson(json['partner']) : null,
      passwordStatus: json['passwordStatus'],
      validFrom: json['validFrom'],
      validTo: json['validTo'],
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
