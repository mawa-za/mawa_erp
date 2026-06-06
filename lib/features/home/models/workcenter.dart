class Workcenter {
  final String id;
  final String description;
  final String defaultFunction;
  final String path;
  final int position;
  final String routeKey;
  final String? routePath;
  final String? iconKey;

  Workcenter({
    required this.id,
    required this.description,
    required this.defaultFunction,
    required this.path,
    required this.position,
    required this.routeKey,
    this.routePath,
    this.iconKey,
  });

  factory Workcenter.fromJson(Map<String, dynamic> json) {
    // Handling dynamic response structure where 'workcenter' might be a key or the object itself
    final Map<String, dynamic> wc = json['workcenter'] is Map<String, dynamic> 
        ? json['workcenter'] 
        : json;
    
    final String id = wc['id']?.toString() ?? '';
    final String defaultFunction = wc['defaultFunction']?.toString() ?? '';
    
    return Workcenter(
      id: id,
      description: wc['description']?.toString() ?? wc['name']?.toString() ?? 'Unnamed Workcenter',
      defaultFunction: defaultFunction,
      path: wc['path']?.toString() ?? '',
      position: (json['position'] ?? 0) as int,
      routeKey: wc['routeKey']?.toString() ?? (defaultFunction.isNotEmpty ? defaultFunction : id),
      routePath: wc['routePath']?.toString() ?? (wc['path']?.toString() != null && wc['path'].toString().isNotEmpty ? wc['path'].toString() : null),
      iconKey: wc['iconKey']?.toString(),
    );
  }
}
