import '../../../core/utils/app_date_utils.dart';

class DeviceCrashLog {
  final String logId;
  final String? deviceId;
  final String? deviceSerialNumber;
  final String? userId;
  final String source;
  final String? errorType;
  final String? errorMessage;
  final String? stackTrace;
  final dynamic details;
  final String? appVersion;
  final String? platform;
  final String? deviceModel;
  final String? osVersion;
  final DateTime? occurredAt;
  final DateTime? receivedAt;

  const DeviceCrashLog({
    required this.logId,
    this.deviceId,
    this.deviceSerialNumber,
    this.userId,
    required this.source,
    this.errorType,
    this.errorMessage,
    this.stackTrace,
    this.details,
    this.appVersion,
    this.platform,
    this.deviceModel,
    this.osVersion,
    this.occurredAt,
    this.receivedAt,
  });

  factory DeviceCrashLog.fromJson(Map<String, dynamic> json) => DeviceCrashLog(
        logId: json['logId']?.toString() ?? '',
        deviceId: json['deviceId']?.toString(),
        deviceSerialNumber: json['deviceSerialNumber']?.toString(),
        userId: json['userId']?.toString(),
        source: json['source']?.toString() ?? 'UNKNOWN',
        errorType: json['errorType']?.toString(),
        errorMessage: json['errorMessage']?.toString(),
        stackTrace: json['stackTrace']?.toString(),
        details: json['details'],
        appVersion: json['appVersion']?.toString(),
        platform: json['platform']?.toString(),
        deviceModel: json['deviceModel']?.toString(),
        osVersion: json['osVersion']?.toString(),
        occurredAt: AppDateUtils.parse(json['occurredAt']),
        receivedAt: AppDateUtils.parse(json['receivedAt']),
      );
}
