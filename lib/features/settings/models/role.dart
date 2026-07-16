class Role {
  final String id;
  final String description;
  final bool systemRole;
  final bool protectedRole;
  final bool accessAllWorkcentres;

  const Role({
    required this.id,
    required this.description,
    this.systemRole = false,
    this.protectedRole = false,
    this.accessAllWorkcentres = false,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: (json['id'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        systemRole: json['systemRole'] == true,
        protectedRole: json['protectedRole'] == true,
        accessAllWorkcentres: json['accessAllWorkcentres'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'systemRole': systemRole,
        'protectedRole': protectedRole,
        'accessAllWorkcentres': accessAllWorkcentres,
      };
}
