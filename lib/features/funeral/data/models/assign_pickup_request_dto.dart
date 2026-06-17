class AssignPickupRequestDto {
  final String staffId;

  AssignPickupRequestDto({required this.staffId});

  Map<String, dynamic> toJson() => {'staffId': staffId};

  factory AssignPickupRequestDto.fromJson(Map<String, dynamic> json) {
    return AssignPickupRequestDto(
      staffId: json['staffId']?.toString() ?? '',
    );
  }
}
