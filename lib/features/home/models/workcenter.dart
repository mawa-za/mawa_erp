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
    );
  }
}
