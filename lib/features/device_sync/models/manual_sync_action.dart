import '../../../core/utils/app_date_utils.dart';

class ManualSyncAction {
  final String id, deviceId, entityType, localRecordId, endpoint, method, status;
  final String? idempotencyKey, failureResponse, responseBody, lastError, actionNotes;
  final dynamic payload, originalPayload;
  final int attemptCount;
  final int? responseStatus;
  final DateTime? requestedAt, completedAt;
  final List<dynamic> attempts;

  const ManualSyncAction({required this.id, required this.deviceId, required this.entityType,
    required this.localRecordId, required this.endpoint, required this.method, required this.status,
    this.idempotencyKey, this.failureResponse, this.responseBody, this.lastError, this.actionNotes,
    this.payload, this.originalPayload, this.attemptCount=0, this.responseStatus,
    this.requestedAt, this.completedAt, this.attempts=const []});

  factory ManualSyncAction.fromJson(Map<String,dynamic> j) => ManualSyncAction(
    id: '${j['id'] ?? ''}', deviceId: '${j['device_id'] ?? ''}', entityType: '${j['entity_type'] ?? ''}',
    localRecordId: '${j['local_record_id'] ?? ''}', endpoint: '${j['endpoint'] ?? ''}',
    method: '${j['http_method'] ?? ''}', status: '${j['status'] ?? 'UNKNOWN'}',
    idempotencyKey: j['idempotency_key']?.toString(), failureResponse: j['failure_response']?.toString(),
    responseBody: j['response_body']?.toString(), lastError: j['last_error']?.toString(),
    actionNotes: j['action_notes']?.toString(), payload: j['payload_json'], originalPayload: j['original_payload_json'],
    attemptCount: (j['attempt_count'] as num?)?.toInt() ?? 0, responseStatus: (j['response_status'] as num?)?.toInt(),
    requestedAt: AppDateUtils.parse(j['requested_at']), completedAt: AppDateUtils.parse(j['completed_at']),
    attempts: j['attempts'] as List? ?? const []);
}
