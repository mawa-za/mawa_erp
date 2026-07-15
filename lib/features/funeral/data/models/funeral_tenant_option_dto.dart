class FuneralTenantOptionDto {
  final String id;
  final String name;
  final String? host;
  final String? status;

  const FuneralTenantOptionDto({
    required this.id,
    required this.name,
    this.host,
    this.status,
  });

  factory FuneralTenantOptionDto.fromJson(Map<String, dynamic> json) {
    return FuneralTenantOptionDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      host: json['host']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
