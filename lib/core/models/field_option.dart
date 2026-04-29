class FieldOption {
  final String field;
  final String code;
  final String type;
  final String description;
  final String validFrom;
  final String validTo;

  FieldOption({
    required this.field,
    required this.code,
    required this.type,
    required this.description,
    required this.validFrom,
    required this.validTo,
  });

  factory FieldOption.fromJson(Map<String, dynamic> json) {
    return FieldOption(
      field: json['field'] ?? '',
      code: json['code'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      validFrom: json['validFrom'] ?? '',
      validTo: json['validTo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'code': code,
      'type': type,
      'description': description,
      'validFrom': validFrom,
      'validTo': validTo,
    };
  }
}
