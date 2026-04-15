class Member {
  final String id;
  final String firstName;
  final String lastName;
  final String memberNumber;
  final String status;
  final String email;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.memberNumber,
    required this.status,
    required this.email,
  });

  String get fullName => '$firstName $lastName';

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      memberNumber: json['memberNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      email: json['email']?.toString() ?? '',
    );
  }
}
