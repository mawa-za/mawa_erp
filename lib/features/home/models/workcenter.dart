class Workcenter {
  final String id;
  final String description;
  final String defaultFunction;
  final String path;
  final int position;
  final String routeKey;
  final String? routePath;
  final String? iconKey;
  final String? displayLabel;
  final String? cardDescription;
  final String? groupCode;
  final String? groupTitle;
  final String? groupDescription;
  final String? sectionCode;
  final String? sectionTitle;
  final int sectionDisplayOrder;
  final int groupDisplayOrder;
  final int displayOrder;
  final String? permissionCode;

  Workcenter({
    required this.id,
    required this.description,
    required this.defaultFunction,
    required this.path,
    required this.position,
    required this.routeKey,
    this.routePath,
    this.iconKey,
    this.displayLabel,
    this.cardDescription,
    this.groupCode,
    this.groupTitle,
    this.groupDescription,
    this.sectionCode,
    this.sectionTitle,
    this.sectionDisplayOrder = 0,
    this.groupDisplayOrder = 0,
    this.displayOrder = 0,
    this.permissionCode,
  });

  String get presentationTitle =>
      displayLabel?.trim().isNotEmpty == true ? displayLabel!.trim() : description;

  Workcenter copyWith({
    String? id,
    String? description,
    String? defaultFunction,
    String? path,
    int? position,
    String? routeKey,
    String? routePath,
    String? iconKey,
    String? displayLabel,
    String? cardDescription,
    String? groupCode,
    String? groupTitle,
    String? groupDescription,
    String? sectionCode,
    String? sectionTitle,
    int? sectionDisplayOrder,
    int? groupDisplayOrder,
    int? displayOrder,
    String? permissionCode,
  }) {
    return Workcenter(
      id: id ?? this.id,
      description: description ?? this.description,
      defaultFunction: defaultFunction ?? this.defaultFunction,
      path: path ?? this.path,
      position: position ?? this.position,
      routeKey: routeKey ?? this.routeKey,
      routePath: routePath ?? this.routePath,
      iconKey: iconKey ?? this.iconKey,
      displayLabel: displayLabel ?? this.displayLabel,
      cardDescription: cardDescription ?? this.cardDescription,
      groupCode: groupCode ?? this.groupCode,
      groupTitle: groupTitle ?? this.groupTitle,
      groupDescription: groupDescription ?? this.groupDescription,
      sectionCode: sectionCode ?? this.sectionCode,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      sectionDisplayOrder: sectionDisplayOrder ?? this.sectionDisplayOrder,
      groupDisplayOrder: groupDisplayOrder ?? this.groupDisplayOrder,
      displayOrder: displayOrder ?? this.displayOrder,
      permissionCode: permissionCode ?? this.permissionCode,
    );
  }

  factory Workcenter.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> wc = json['workcenter'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['workcenter'] as Map)
        : json;

    final String id = wc['id']?.toString() ?? '';
    final String defaultFunction = wc['defaultFunction']?.toString() ?? '';
    final dynamic rawPosition = json['position'] ?? wc['position'] ?? 0;
    final int position = rawPosition is int
        ? rawPosition
        : int.tryParse(rawPosition.toString()) ?? 0;
    final configuredPath = wc['path']?.toString();

    return Workcenter(
      id: id,
      description:
          wc['description']?.toString() ?? wc['name']?.toString() ?? 'Unnamed Workcenter',
      defaultFunction: defaultFunction,
      path: configuredPath ?? '',
      position: position,
      routeKey: wc['routeKey']?.toString() ??
          (defaultFunction.isNotEmpty ? defaultFunction : id),
      routePath: wc['routePath']?.toString() ??
          (configuredPath != null && configuredPath.isNotEmpty
              ? configuredPath
              : null),
      iconKey: wc['iconKey']?.toString(),
      displayLabel: wc['displayLabel']?.toString(),
      cardDescription: wc['cardDescription']?.toString(),
      groupCode: wc['groupCode']?.toString(),
      groupTitle: wc['groupTitle']?.toString(),
      groupDescription: wc['groupDescription']?.toString(),
      sectionCode: wc['sectionCode']?.toString(),
      sectionTitle: wc['sectionTitle']?.toString(),
      sectionDisplayOrder: _asInt(wc['sectionDisplayOrder']),
      groupDisplayOrder: _asInt(wc['groupDisplayOrder']),
      displayOrder: _asInt(wc['displayOrder']),
      permissionCode: wc['permissionCode']?.toString(),
    );
  }

  static int _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
