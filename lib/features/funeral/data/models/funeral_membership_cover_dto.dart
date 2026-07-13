import 'funeral_enums.dart';

class FuneralMembershipCoverDto {
  final String? membershipId;
  final String burialSocietyName;
  final int coverAmountCents;
  final String membershipNumber;
  final CoverSource coverSource;
  final String? sourceTenantId;
  final String? sourceTenantName;
  final String? sourceMembershipId;
  final String? sourceReference;
  final String? burialSocietyPartnerId;

  FuneralMembershipCoverDto({
    this.membershipId,
    required this.burialSocietyName,
    required this.coverAmountCents,
    required this.membershipNumber,
    required this.coverSource,
    this.sourceTenantId,
    this.sourceTenantName,
    this.sourceMembershipId,
    this.sourceReference,
    this.burialSocietyPartnerId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (membershipId != null) 'membershipId': membershipId,
      'burialSocietyName': burialSocietyName,
      'coverAmountCents': coverAmountCents,
      'membershipNumber': membershipNumber,
      'coverSource': coverSource.name,
      if (sourceTenantId != null) 'sourceTenantId': sourceTenantId,
      if (sourceTenantName != null) 'sourceTenantName': sourceTenantName,
      if (sourceMembershipId != null) 'sourceMembershipId': sourceMembershipId,
      if (sourceReference != null) 'sourceReference': sourceReference,
      if (burialSocietyPartnerId != null) 'burialSocietyPartnerId': burialSocietyPartnerId,
    };
  }

  factory FuneralMembershipCoverDto.fromJson(Map<String, dynamic> json) {
    return FuneralMembershipCoverDto(
      membershipId: json['membershipId']?.toString(),
      burialSocietyName: json['burialSocietyName']?.toString() ?? '',
      coverAmountCents: json['coverAmountCents'] as int? ?? 0,
      membershipNumber: json['membershipNumber']?.toString() ?? '',
      coverSource: CoverSource.parse(json['coverSource']),
      sourceTenantId: json['sourceTenantId']?.toString(),
      sourceTenantName: json['sourceTenantName']?.toString(),
      sourceMembershipId: json['sourceMembershipId']?.toString(),
      sourceReference: json['sourceReference']?.toString(),
      burialSocietyPartnerId: json['burialSocietyPartnerId']?.toString(),
    );
  }
}
