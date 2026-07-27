class ArrivePickupRequestDto {
  final DateTime arrivalTime;
  final bool corpseInjured;
  final String? injuryDetails;

  ArrivePickupRequestDto({
    required this.arrivalTime,
    required this.corpseInjured,
    this.injuryDetails,
  });

  Map<String, dynamic> toJson() => {
        'arrivalTime': arrivalTime.toIso8601String(),
        'corpseInjured': corpseInjured,
        'injuryDetails': corpseInjured ? injuryDetails : null,
      };
}
