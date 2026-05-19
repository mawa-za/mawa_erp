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
    String parseDate(dynamic date) {
      if (date == null) return '';
      if (date is String) return date;
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

    return GroupSocietyContact(
      id: (json['id'] ?? '').toString(),
      groupSocietyId: (json['groupSocietyId'] ?? '').toString(),
      contactName: (json['contactName'] ?? '').toString(),
      role: json['role']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      email: json['email']?.toString(),
      primaryContact: json['primaryContact'] == true,
      createdAt: parseDate(json['createdAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: parseDate(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}
