import '../../../core/utils/app_date_utils.dart';

class DeviceSyncSubmission {
  final String submissionId;
  final String idempotencyKey;
  final String? deviceId;
  final String? deviceSerialNumber;
  final DateTime? syncTime;
  final String? submittedBy;
  final String method;
  final String path;
  final dynamic requestPayload;
  final dynamic responsePayload;
  final int? responseStatus;
  final String status;
  final int attemptCount;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;

  const DeviceSyncSubmission({
    required this.submissionId,
    required this.idempotencyKey,
    this.deviceId,
    this.deviceSerialNumber,
    this.syncTime,
    this.submittedBy,
    required this.method,
    required this.path,
    this.requestPayload,
    this.responsePayload,
    this.responseStatus,
    required this.status,
    required this.attemptCount,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
    this.processedAt,
  });

  factory DeviceSyncSubmission.fromJson(Map<String, dynamic> json) => DeviceSyncSubmission(
        submissionId: json['submissionId']?.toString() ?? '',
        idempotencyKey: json['idempotencyKey']?.toString() ?? '',
        deviceId: json['deviceId']?.toString(),
        deviceSerialNumber: json['deviceSerialNumber']?.toString(),
        syncTime: AppDateUtils.parse(json['syncTime']),
        submittedBy: json['submittedBy']?.toString(),
        method: json['method']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
        requestPayload: json['requestPayload'],
        responsePayload: json['responsePayload'],
        responseStatus: (json['responseStatus'] as num?)?.toInt(),
        status: json['status']?.toString() ?? 'UNKNOWN',
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        errorMessage: json['errorMessage']?.toString(),
        createdAt: AppDateUtils.parse(json['createdAt']),
        updatedAt: AppDateUtils.parse(json['updatedAt']),
        processedAt: AppDateUtils.parse(json['processedAt']),
      );
}
