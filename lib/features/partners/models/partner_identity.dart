class PartnerIdentity {
  final String? partner;
  final String type;
  final String number;
  final DateTime? validFrom;
  final DateTime? validTo;

  PartnerIdentity({
    this.partner,
    required this.type,
    required this.number,
    this.validFrom,
    this.validTo,
  });

  factory PartnerIdentity.fromJson(Map<String, dynamic> json) {
    return PartnerIdentity(
      partner: json['partner'],
      type: json['type'] ?? '',
      number: json['number'] ?? '',
      validFrom: json['validFrom'] != null ? DateTime.parse(json['validFrom']) : null,
      validTo: json['validTo'] != null ? DateTime.parse(json['validTo']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (partner != null) 'partner': partner,
      'type': type,
      'number': number,
      if (validFrom != null) 'validFrom': validFrom?.toIso8601String(),
      if (validTo != null) 'validTo': validTo?.toIso8601String(),
    };
  }
}
