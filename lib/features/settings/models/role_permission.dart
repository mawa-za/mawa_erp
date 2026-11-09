class RolePermission {
  final String code;
  final String description;
  final String details;
  final String groupTitle;
  final int displayOrder;
  final bool sensitive;

  const RolePermission({
    required this.code,
    required this.description,
    required this.details,
    required this.groupTitle,
    required this.displayOrder,
    required this.sensitive,
  });

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    final order = json['displayOrder'];
    return RolePermission(
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      groupTitle: json['groupTitle']?.toString() ?? 'Other permissions',
      displayOrder: order is int ? order : int.tryParse('$order') ?? 100,
      sensitive: json['sensitive'] == true || json['sensitive'] == 1,
    );
  }
}
