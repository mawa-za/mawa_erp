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
      field: (json['field'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      validFrom: (json['validFrom'] ?? '').toString(),
      validTo: (json['validTo'] ?? '').toString(),
    );
  }

  factory FieldOption.fromDynamic(dynamic json) {
    if (json is Map) {
      return FieldOption.fromJson(Map<String, dynamic>.from(json));
    }
    return FieldOption(
      field: '',
      code: '',
      type: '',
      description: '',
      validFrom: '',
      validTo: '',
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
