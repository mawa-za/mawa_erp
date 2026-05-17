class ModuleUsage {
  final String? id;
  final String? userId;
  final String moduleCode;
  final String? moduleName;
  final String? modulePath;
  final String? workcenterId;
  final int? usageCount;
  final DateTime? firstUsedAt;
  final DateTime? lastUsedAt;

  ModuleUsage({
    this.id,
    this.userId,
    required this.moduleCode,
    this.moduleName,
    this.modulePath,
    this.workcenterId,
    this.usageCount,
    this.firstUsedAt,
    this.lastUsedAt,
  });

  factory ModuleUsage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        if (raw.isEmpty) return null;
        return DateTime.tryParse(raw);
      }
      if (raw is List) {
        if (raw.length < 3) return null;
        try {
          return DateTime(
            raw[0] as int,
            raw[1] as int,
            raw[2] as int,
            raw.length > 3 ? raw[3] as int : 0,
            raw.length > 4 ? raw[4] as int : 0,
            raw.length > 5 ? raw[5] as int : 0,
          );
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return ModuleUsage(
      id: json['id']?.toString(),
      userId: json['userId']?.toString(),
      moduleCode: json['moduleCode']?.toString() ?? '',
      moduleName: json['moduleName']?.toString(),
      modulePath: json['modulePath']?.toString(),
      workcenterId: json['workcenterId']?.toString(),
      usageCount: json['usageCount'] is int 
          ? json['usageCount'] 
          : int.tryParse(json['usageCount']?.toString() ?? ''),
      firstUsedAt: parseDateTime(json['firstUsedAt']),
      lastUsedAt: parseDateTime(json['lastUsedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'moduleCode': moduleCode,
      if (moduleName != null) 'moduleName': moduleName,
      if (modulePath != null) 'modulePath': modulePath,
      if (workcenterId != null) 'workcenterId': workcenterId,
      if (usageCount != null) 'usageCount': usageCount,
      if (firstUsedAt != null) 'firstUsedAt': firstUsedAt!.toIso8601String(),
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
    };
  }
}

class TrackModuleUsageRequest {
  final String? userId;
  final String moduleCode;
  final String? moduleName;
  final String? modulePath;
  final String? workcenterId;

  TrackModuleUsageRequest({
    this.userId,
    required this.moduleCode,
    this.moduleName,
    this.modulePath,
    this.workcenterId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'userId': userId,
      'moduleCode': moduleCode,
      if (moduleName != null) 'moduleName': moduleName,
      if (modulePath != null) 'modulePath': modulePath,
      if (workcenterId != null) 'workcenterId': workcenterId,
    };
  }
}
