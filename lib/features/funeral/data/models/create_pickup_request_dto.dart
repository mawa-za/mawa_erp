class CreatePickupRequestDto {
  final String deceasedName;
  final String pickupLocationCode;
  final bool corpseInjured;
  final String? injuryDetails;
  final String contactPerson;
  final String contactNumber;

  CreatePickupRequestDto({
    required this.deceasedName,
    required this.pickupLocationCode,
    required this.corpseInjured,
    this.injuryDetails,
    required this.contactPerson,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() => {
        'deceasedName': deceasedName,
        'pickupLocationCode': pickupLocationCode,
        'pickupLocation': pickupLocationCode,
        'corpseInjured': corpseInjured,
        'injuryDetails': corpseInjured ? injuryDetails : null,
        'contactPerson': contactPerson,
        'contactNumber': contactNumber,
      };
}
