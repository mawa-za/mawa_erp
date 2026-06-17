import 'funeral_enums.dart';

class MortuaryInventoryDto {
  final String id;
  final String deceasedName;
  final String? identityNumber;
  final String? tagNumber;
  final DateTime checkInDate;
  final MortuaryStatus status;

  MortuaryInventoryDto({
    required this.id,
    required this.deceasedName,
    this.identityNumber,
    this.tagNumber,
    required this.checkInDate,
    this.status = MortuaryStatus.IN_STORAGE,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deceasedName': deceasedName,
      if (identityNumber != null) 'identityNumber': identityNumber,
      if (tagNumber != null) 'tagNumber': tagNumber,
      'checkInDate': checkInDate.toIso8601String(),
      'status': status.name,
    };
  }

  factory MortuaryInventoryDto.fromJson(Map<String, dynamic> json) {
    return MortuaryInventoryDto(
      id: json['id']?.toString() ?? '',
      deceasedName: json['deceasedName'] ?? '',
      identityNumber: json['identityNumber']?.toString(),
      tagNumber: json['tagNumber']?.toString(),
      checkInDate: DateTime.parse(json['checkInDate'].toString()),
      status: MortuaryStatus.parse(json['status']),
    );
  }
}
