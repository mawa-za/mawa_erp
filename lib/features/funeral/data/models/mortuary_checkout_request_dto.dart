import '../../../../core/utils/app_date_utils.dart';

class MortuaryCheckoutRequestDto {
  final String releaseTo;
  final String identityNumber;
  final DateTime checkoutDate;

  MortuaryCheckoutRequestDto({
    required this.releaseTo,
    required this.identityNumber,
    required this.checkoutDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'releaseTo': releaseTo,
      'identityNumber': identityNumber,
      'checkoutDate': checkoutDate.toIso8601String(),
    };
  }

  factory MortuaryCheckoutRequestDto.fromJson(Map<String, dynamic> json) {
    return MortuaryCheckoutRequestDto(
      releaseTo: json['releaseTo']?.toString() ?? '',
      identityNumber: json['identityNumber']?.toString() ?? '',
      checkoutDate: AppDateUtils.parse(json['checkoutDate']) ?? DateTime.now(),
    );
  }
}
