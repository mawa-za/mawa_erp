class NumberSequenceConfiguration {
  final int id;
  final String seqType;
  final String description;
  final int startNo;
  final int nextNo;
  final int endNo;
  final int remainingNumbers;
  final int defaultAllocationSize;
  final int warningThreshold;
  final bool active;
  final bool exhausted;
  final bool lowRange;
  final int lockVersion;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  const NumberSequenceConfiguration({
    required this.id,
    required this.seqType,
    required this.description,
    required this.startNo,
    required this.nextNo,
    required this.endNo,
    required this.remainingNumbers,
    required this.defaultAllocationSize,
    required this.warningThreshold,
    required this.active,
    required this.exhausted,
    required this.lowRange,
    required this.lockVersion,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory NumberSequenceConfiguration.fromJson(Map<String, dynamic> json) {
    return NumberSequenceConfiguration(
      id: _asInt(json['id']),
      seqType: json['seqType']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startNo: _asInt(json['startNo']),
      nextNo: _asInt(json['nextNo']),
      endNo: _asInt(json['endNo']),
      remainingNumbers: _asInt(json['remainingNumbers']),
      defaultAllocationSize: _asInt(json['defaultAllocationSize']),
      warningThreshold: _asInt(json['warningThreshold']),
      active: json['active'] == true,
      exhausted: json['exhausted'] == true,
      lowRange: json['lowRange'] == true,
      lockVersion: _asInt(json['lockVersion']),
      createdAt: _asDateTime(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _asDateTime(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toUpdateJson({
    required String description,
    required int nextNo,
    required int endNo,
    required int defaultAllocationSize,
    required int warningThreshold,
    required bool active,
  }) {
    return {
      'id': id,
      'seqType': seqType,
      'description': description,
      'startNo': startNo,
      'nextNo': nextNo,
      'endNo': endNo,
      'defaultAllocationSize': defaultAllocationSize,
      'warningThreshold': warningThreshold,
      'active': active,
      'lockVersion': lockVersion,
    };
  }
}

class DocumentNumberRangeConfiguration {
  final int id;
  final String object;
  final String? prefix;
  final String start;
  final String current;
  final String end;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;

  const DocumentNumberRangeConfiguration({
    required this.id,
    required this.object,
    required this.prefix,
    required this.start,
    required this.current,
    required this.end,
    required this.validFrom,
    required this.validTo,
    required this.active,
  });

  factory DocumentNumberRangeConfiguration.fromJson(Map<String, dynamic> json) {
    return DocumentNumberRangeConfiguration(
      id: _asInt(json['id']),
      object: json['object']?.toString() ?? '',
      prefix: json['prefix']?.toString(),
      start: json['start']?.toString() ?? '',
      current: json['current']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      validFrom: _asDateTime(json['validFrom']),
      validTo: _asDateTime(json['validTo']),
      active: json['active'] == true,
    );
  }
}

class NumberRangeAllocationRecord {
  final int id;
  final String seqType;
  final String deviceId;
  final int fromNo;
  final int toNo;
  final int nextLocalNo;
  final int allocationSize;
  final String status;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  const NumberRangeAllocationRecord({
    required this.id,
    required this.seqType,
    required this.deviceId,
    required this.fromNo,
    required this.toNo,
    required this.nextLocalNo,
    required this.allocationSize,
    required this.status,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory NumberRangeAllocationRecord.fromJson(Map<String, dynamic> json) {
    return NumberRangeAllocationRecord(
      id: _asInt(json['id']),
      seqType: json['seqType']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? '',
      fromNo: _asInt(json['fromNo']),
      toNo: _asInt(json['toNo']),
      nextLocalNo: _asInt(json['nextLocalNo']),
      allocationSize: _asInt(json['allocationSize']),
      status: json['status']?.toString() ?? '',
      createdAt: _asDateTime(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _asDateTime(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}

class NumberRangeAuditRecord {
  final int id;
  final String sourceType;
  final String configurationId;
  final String rangeKey;
  final String action;
  final dynamic previousValue;
  final dynamic newValue;
  final DateTime? changedAt;
  final String? changedBy;

  const NumberRangeAuditRecord({
    required this.id,
    required this.sourceType,
    required this.configurationId,
    required this.rangeKey,
    required this.action,
    required this.previousValue,
    required this.newValue,
    required this.changedAt,
    required this.changedBy,
  });

  factory NumberRangeAuditRecord.fromJson(Map<String, dynamic> json) {
    return NumberRangeAuditRecord(
      id: _asInt(json['id']),
      sourceType: json['source_type']?.toString() ?? json['sourceType']?.toString() ?? '',
      configurationId: json['configuration_id']?.toString() ?? json['configurationId']?.toString() ?? '',
      rangeKey: json['range_key']?.toString() ?? json['rangeKey']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      previousValue: json['previous_value'] ?? json['previousValue'],
      newValue: json['new_value'] ?? json['newValue'],
      changedAt: _asDateTime(json['changed_at'] ?? json['changedAt']),
      changedBy: json['changed_by']?.toString() ?? json['changedBy']?.toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
