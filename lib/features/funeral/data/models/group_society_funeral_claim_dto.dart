import '../../../../core/utils/app_date_utils.dart';

class GroupSocietyFuneralClaimDto {
  final String id;
  final String claimNo;
  final String funeralServiceId;
  final String groupSocietyId;
  final String groupNo;
  final String societyName;
  final String deceasedFirstNames;
  final String deceasedLastName;
  final String identityType;
  final String identityNumber;
  final int requestedCoverCents;
  final int approvedCoverCents;
  final String status;
  final String? approvalRequestId;
  final String? notes;
  final String? createdAt;

  const GroupSocietyFuneralClaimDto({
    required this.id,
    required this.claimNo,
    required this.funeralServiceId,
    required this.groupSocietyId,
    required this.groupNo,
    required this.societyName,
    required this.deceasedFirstNames,
    required this.deceasedLastName,
    required this.identityType,
    required this.identityNumber,
    required this.requestedCoverCents,
    required this.approvedCoverCents,
    required this.status,
    this.approvalRequestId,
    this.notes,
    this.createdAt,
  });

  bool get isPending => const {'PENDING_APPROVAL', 'SUBMITTED', 'PENDING'}.contains(status.toUpperCase());
  bool get isApproved => status.toUpperCase() == 'APPROVED';

  factory GroupSocietyFuneralClaimDto.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? 0}') ?? 0;
    return GroupSocietyFuneralClaimDto(
      id: '${json['id'] ?? ''}',
      claimNo: '${json['claimNo'] ?? ''}',
      funeralServiceId: '${json['funeralServiceId'] ?? ''}',
      groupSocietyId: '${json['groupSocietyId'] ?? ''}',
      groupNo: '${json['groupNo'] ?? ''}',
      societyName: '${json['societyName'] ?? json['groupNo'] ?? ''}',
      deceasedFirstNames: '${json['deceasedFirstNames'] ?? ''}',
      deceasedLastName: '${json['deceasedLastName'] ?? ''}',
      identityType: '${json['identityType'] ?? ''}',
      identityNumber: '${json['identityNumber'] ?? ''}',
      requestedCoverCents: cents(json['requestedCoverCents']),
      approvedCoverCents: cents(json['approvedCoverCents']),
      status: '${json['status'] ?? ''}',
      approvalRequestId: json['approvalRequestId']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] == null ? null : AppDateUtils.normalizeDateTime(json['createdAt']),
    );
  }
}
