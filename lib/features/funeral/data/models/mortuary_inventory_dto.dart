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
      deceasedName: (json['deceasedName'] ?? json['name'] ?? '').toString(),
      identityNumber: json['identityNumber']?.toString(),
      tagNumber: json['tagNumber']?.toString(),
      checkInDate: _parseBackendDateTime(json['checkInDate'] ?? json['createdAt']),
      status: MortuaryStatus.parse(json['status']?.toString()),
    );
  }

  static DateTime _parseBackendDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;

    // Spring/Jackson may serialize LocalDateTime as an array:
    // [yyyy, MM, dd, HH, mm, ss, nanos]
    if (value is List && value.length >= 3) {
      final year = _toInt(value[0], DateTime.now().year);
      final month = _toInt(value[1], 1);
      final day = _toInt(value[2], 1);
      final hour = value.length > 3 ? _toInt(value[3], 0) : 0;
      final minute = value.length > 4 ? _toInt(value[4], 0) : 0;
      final second = value.length > 5 ? _toInt(value[5], 0) : 0;
      final millisecond = value.length > 6 ? (_toInt(value[6], 0) ~/ 1000000) : 0;
      return DateTime(year, month, day, hour, minute, second, millisecond);
    }

    final text = value.toString();
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
