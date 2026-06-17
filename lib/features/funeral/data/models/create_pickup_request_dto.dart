class CreatePickupRequestDto {
  final String deceasedName;
  final String pickupLocation;
  final String contactPerson;
  final String contactNumber;

  CreatePickupRequestDto({
    required this.deceasedName,
    required this.pickupLocation,
    required this.contactPerson,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'deceasedName': deceasedName,
      'pickupLocation': pickupLocation,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
    };
  }

  factory CreatePickupRequestDto.fromJson(Map<String, dynamic> json) {
    return CreatePickupRequestDto(
      deceasedName: json['deceasedName']?.toString() ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      contactPerson: json['contactPerson'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
    );
  }
}
