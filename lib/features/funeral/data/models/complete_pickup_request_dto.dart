class CompletePickupRequestDto {
  final DateTime completionTime;

  CompletePickupRequestDto({required this.completionTime});

  Map<String, dynamic> toJson() => {
    'completionTime': completionTime.toIso8601String(),
  };

  factory CompletePickupRequestDto.fromJson(Map<String, dynamic> json) {
    return CompletePickupRequestDto(
      completionTime: DateTime.parse(json['completionTime'].toString()),
    );
  }
}
