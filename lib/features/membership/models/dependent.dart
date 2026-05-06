class Dependent {
  final String id;
  final String membershipId;
  final String dependentPartnerId;
  final String relationship;
  final bool active;
  final String? createdAt;
  final String createdBy;
  final String? updatedAt;
  final String? updatedBy;

  Dependent({
    required this.id,
    required this.membershipId,
    required this.dependentPartnerId,
    required this.relationship,
    required this.active,
    this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: (json['id'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      dependentPartnerId: (json['dependentPartnerId'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      active: json['active'] ?? true,
      createdAt: json['createdAt']?.toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      updatedAt: json['updatedAt']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membershipId': membershipId,
      'dependentPartnerId': dependentPartnerId,
      'relationship': relationship,
      'active': active,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }
}
