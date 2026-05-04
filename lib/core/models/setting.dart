class Setting {
  final String type;
  final String attribute;
  final String value;

  Setting({
    required this.type,
    required this.attribute,
    required this.value,
  });

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      type: json['type'] ?? '',
      attribute: json['attribute'] ?? '',
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'attribute': attribute,
      'value': value,
    };
  }
}
