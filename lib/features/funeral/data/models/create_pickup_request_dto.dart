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

  Map<String, dynamic> toJson() => {
        'deceasedName': deceasedName,
        'pickupLocation': pickupLocation,
        'contactPerson': contactPerson,
        'contactNumber': contactNumber,
      };
}
