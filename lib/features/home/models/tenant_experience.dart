class TenantExperienceWorkcenter {
  final String id;
  final String displayLabel;
  final String description;
  final int displayOrder;
  final bool active;

  const TenantExperienceWorkcenter({
    required this.id,
    required this.displayLabel,
    required this.description,
    required this.displayOrder,
    required this.active,
  });

  factory TenantExperienceWorkcenter.fromJson(Map<String, dynamic> json) {
    return TenantExperienceWorkcenter(
      id: (json['id'] ?? '').toString(),
      displayLabel: (json['displayLabel'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      displayOrder: _asInt(json['displayOrder']),
      active: json['active'] != false,
    );
  }
}

class TenantExperienceGroup {
  final String code;
  final String title;
  final String description;
  final String sectionCode;
  final String iconKey;
  final int displayOrder;
  final bool active;
  final List<TenantExperienceWorkcenter> workcenters;

  const TenantExperienceGroup({
    required this.code,
    required this.title,
    required this.description,
    required this.sectionCode,
    required this.iconKey,
    required this.displayOrder,
    required this.active,
    required this.workcenters,
  });

  factory TenantExperienceGroup.fromJson(Map<String, dynamic> json) {
    return TenantExperienceGroup(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sectionCode: (json['sectionCode'] ?? 'YOUR_BUSINESS').toString(),
      iconKey: (json['iconKey'] ?? '').toString(),
      displayOrder: _asInt(json['displayOrder']),
      active: json['active'] != false,
      workcenters: (json['workcenters'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => TenantExperienceWorkcenter.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class TenantExperienceSection {
  final String code;
  final String title;
  final String description;
  final int displayOrder;
  final List<TenantExperienceGroup> groups;

  const TenantExperienceSection({
    required this.code,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.groups,
  });

  factory TenantExperienceSection.fromJson(Map<String, dynamic> json) {
    return TenantExperienceSection(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      displayOrder: _asInt(json['displayOrder']),
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => TenantExperienceGroup.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class TenantExperienceIndustry {
  final String code;
  final String name;

  const TenantExperienceIndustry({required this.code, required this.name});

  factory TenantExperienceIndustry.fromJson(Map<String, dynamic> json) {
    return TenantExperienceIndustry(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class TenantExperience {
  final String tenantId;
  final String primaryIndustryCode;
  final String primaryIndustryName;
  final List<TenantExperienceIndustry> additionalIndustries;
  final List<TenantExperienceSection> sections;

  const TenantExperience({
    required this.tenantId,
    required this.primaryIndustryCode,
    required this.primaryIndustryName,
    required this.additionalIndustries,
    required this.sections,
  });

  factory TenantExperience.fromJson(Map<String, dynamic> json) {
    final sections = (json['sections'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => TenantExperienceSection.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((section) => section.groups.isNotEmpty)
        .toList()
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
    return TenantExperience(
      tenantId: (json['tenantId'] ?? '').toString(),
      primaryIndustryCode:
          (json['primaryIndustryCode'] ?? 'GENERAL_CUSTOM').toString(),
      primaryIndustryName:
          (json['primaryIndustryName'] ?? 'General / Custom').toString(),
      additionalIndustries:
          (json['additionalIndustries'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => TenantExperienceIndustry.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(),
      sections: sections,
    );
  }

  TenantExperienceGroup? groupByCode(String code) {
    final target = normalizeExperienceKey(code);
    for (final section in sections) {
      for (final group in section.groups) {
        if (normalizeExperienceKey(group.code) == target) return group;
      }
    }
    return null;
  }
}

String normalizeExperienceKey(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
