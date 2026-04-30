import '../../../core/models/field_option.dart';
import 'membership_detail.dart';

class Dependent {
  final String id;
  final String number;
  final String firstName;
  final String lastName;
  final String? middleName;
  final FieldOption? type;
  final Identity? identity;
  final FieldOption? title;
  final String? birthDate;
  final FieldOption? maritalStatus;
  final FieldOption? gender;
  final FieldOption? language;
  final FieldOption? status;
  final String? validFrom;
  final String? validTo;

  Dependent({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.type,
    this.identity,
    this.title,
    this.birthDate,
    this.maritalStatus,
    this.gender,
    this.language,
    this.status,
    this.validFrom,
    this.validTo,
  });

  String get fullName => '$firstName ${middleName != null && middleName!.isNotEmpty ? '$middleName ' : ''}$lastName'.trim();

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      firstName: json['name2'] ?? '',
      lastName: json['name1'] ?? '',
      middleName: json['name3'],
      type: json['type'] != null ? FieldOption.fromJson(json['type']) : null,
      identity: json['identity'] != null ? Identity.fromJson(json['identity']) : null,
      title: json['title'] != null ? FieldOption.fromJson(json['title']) : null,
      birthDate: json['birthDate'],
      maritalStatus: json['maritalStatus'] != null ? FieldOption.fromJson(json['maritalStatus']) : null,
      gender: json['gender'] != null ? FieldOption.fromJson(json['gender']) : null,
      language: json['language'] != null ? FieldOption.fromJson(json['language']) : null,
      status: json['status'] != null ? FieldOption.fromJson(json['status']) : null,
      validFrom: json['validFrom'],
      validTo: json['validTo'],
    );
  }
}
