import 'dart:convert';

class FuneralPackageDto {
  final String id;
  final String name;
  final int basePriceCents;
  final List<String> inclusions;
  final String inclusionsJson;
  final bool active;

  FuneralPackageDto({
    required this.id,
    required this.name,
    required this.basePriceCents,
    required this.inclusions,
    this.inclusionsJson = '[]',
    this.active = true,
  });

  Map<String, dynamic> toJson() {
    final encodedInclusions = inclusionsJson.isNotEmpty ? inclusionsJson : jsonEncode(inclusions);
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'basePriceCents': basePriceCents,
      'inclusions': inclusions,
      'inclusionsJson': encodedInclusions,
      'active': active,
    };
  }

  factory FuneralPackageDto.fromJson(Map<String, dynamic> json) {
    final rawInclusions = json['inclusions'];
    final rawInclusionsJson = json['inclusionsJson']?.toString() ?? '';
    final parsedInclusions = _parseInclusions(rawInclusions, rawInclusionsJson);

    return FuneralPackageDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      basePriceCents: _parseInt(json['basePriceCents']),
      inclusions: parsedInclusions,
      inclusionsJson: rawInclusionsJson.isNotEmpty ? rawInclusionsJson : jsonEncode(parsedInclusions),
      active: json['active'] is bool ? json['active'] as bool : json['active']?.toString().toLowerCase() != 'false',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _parseInclusions(dynamic rawInclusions, String rawInclusionsJson) {
    if (rawInclusions is List) {
      return rawInclusions.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }

    if (rawInclusionsJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInclusionsJson);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        }
        if (decoded is Map) {
          final items = decoded['items'] ?? decoded['inclusions'];
          if (items is List) {
            return items.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          }
        }
      } catch (_) {
        return rawInclusionsJson
            .split(RegExp(r'[\n,;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    return [];
  }
}
