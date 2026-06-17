import 'funeral_enums.dart';

class ApproveFuneralClaimRequestDto {
  final int approvedAmountCents;
  final ClaimStatus status;
  final String? note;

  ApproveFuneralClaimRequestDto({
    required this.approvedAmountCents,
    required this.status,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'approvedAmountCents': approvedAmountCents,
      'status': status.name,
      if (note != null) 'note': note,
    };
  }

  factory ApproveFuneralClaimRequestDto.fromJson(Map<String, dynamic> json) {
    return ApproveFuneralClaimRequestDto(
      approvedAmountCents: json['approvedAmountCents'] as int? ?? 0,
      status: ClaimStatus.parse(json['status']?.toString()),
      note: json['note']?.toString(),
    );
  }
}
