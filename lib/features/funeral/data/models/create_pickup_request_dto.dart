class CreatePickupRequestDto {
  final String deceasedName;
  final String pickupLocationCode;
  final String contactPerson;
  final String contactNumber;

  CreatePickupRequestDto({
    required this.deceasedName,
    required this.pickupLocationCode,
    required this.contactPerson,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() => {
        'deceasedName': deceasedName,
        'pickupLocationCode': pickupLocationCode,
        'pickupLocation': pickupLocationCode,
        'contactPerson': contactPerson,
        'contactNumber': contactNumber,
      };
}
