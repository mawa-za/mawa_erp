class GroupSocietyCoverOptionDto {
  final String id;
  final String partnerId;
  final String groupNo;
  final String name;
  final String societyType;
  final String status;
  final int availableBalanceCents;

  const GroupSocietyCoverOptionDto({
    required this.id,
    required this.partnerId,
    required this.groupNo,
    required this.name,
    required this.societyType,
    required this.status,
    required this.availableBalanceCents,
  });

  double get availableBalance => availableBalanceCents / 100.0;

  factory GroupSocietyCoverOptionDto.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? 0}') ?? 0;
    return GroupSocietyCoverOptionDto(
      id: '${json['id'] ?? ''}',
      partnerId: '${json['partnerId'] ?? ''}',
      groupNo: '${json['groupNo'] ?? ''}',
      name: '${json['name'] ?? json['groupNo'] ?? ''}',
      societyType: '${json['societyType'] ?? ''}',
      status: '${json['status'] ?? ''}',
      availableBalanceCents: cents(json['availableBalanceCents']),
    );
  }
}
