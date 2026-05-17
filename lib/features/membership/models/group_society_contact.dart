class GroupSocietyContact {
  final String id;
  final String groupSocietyId;
  final String contactName;
  final String? role;
  final String? mobileNo;
  final String? email;
  final bool primaryContact;
  final String createdAt;
  final String createdBy;
  final String updatedAt;
  final String? updatedBy;

  GroupSocietyContact({
    required this.id,
    required this.groupSocietyId,
    required this.contactName,
    this.role,
    this.mobileNo,
    this.email,
    required this.primaryContact,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  factory GroupSocietyContact.fromJson(Map<String, dynamic> json) {
    return GroupSocietyContact(
      id: json['id'] ?? '',
      groupSocietyId: json['groupSocietyId'] ?? '',
      contactName: json['contactName'] ?? '',
      role: json['role'],
      mobileNo: json['mobileNo'],
      email: json['email'],
      primaryContact: json['primaryContact'] ?? false,
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      updatedBy: json['updatedBy'],
    );
  }
}
