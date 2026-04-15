class Workcenter {
  final String id;
  final String description;
  final String defaultFunction;
  final String path;
  final int position;

  Workcenter({
    required this.id,
    required this.description,
    required this.defaultFunction,
    required this.path,
    required this.position,
  });

  factory Workcenter.fromJson(Map<String, dynamic> json) {
    // Handling dynamic response structure where 'workcenter' might be a key or the object itself
    final Map<String, dynamic> wc = json['workcenter'] is Map<String, dynamic> 
        ? json['workcenter'] 
        : json;
    
    return Workcenter(
      id: wc['id']?.toString() ?? '',
      description: wc['description']?.toString() ?? wc['name']?.toString() ?? 'Unnamed Workcenter',
      defaultFunction: wc['defaultFunction']?.toString() ?? '',
      path: wc['path']?.toString() ?? '',
      position: (json['position'] ?? 0) as int,
    );
  }
}
