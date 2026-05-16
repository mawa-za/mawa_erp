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
    return ModuleUsage(
      id: json['id'],
      userId: json['userId'],
      moduleCode: json['moduleCode'] ?? '',
      moduleName: json['moduleName'],
      modulePath: json['modulePath'],
      workcenterId: json['workcenterId'],
      usageCount: json['usageCount'],
      firstUsedAt: json['firstUsedAt'] != null ? DateTime.parse(json['firstUsedAt']) : null,
      lastUsedAt: json['lastUsedAt'] != null ? DateTime.parse(json['lastUsedAt']) : null,
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
