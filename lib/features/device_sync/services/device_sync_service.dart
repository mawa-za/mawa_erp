import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/device_sync_submission.dart';

class DeviceSyncService {
  final ApiClient _api = ApiClient();

  Future<List<DeviceSyncSubmission>> list({String status = 'ALL', String search = ''}) async {
    final response = await _api.get('/v2/device-sync/submissions', queryParameters: {
      if (status != 'ALL') 'status': status,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': 0,
      'size': 100,
    });
    if (response.statusCode != 200) throw AppException(response.body);
    final decoded = jsonDecode(response.body);
    final content = decoded is Map ? (decoded['content'] as List? ?? const []) : const [];
    return content.map((e) => DeviceSyncSubmission.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<DeviceSyncSubmission> get(String id) async {
    final response = await _api.get('/v2/device-sync/submissions/$id');
    if (response.statusCode != 200) throw AppException(response.body);
    return DeviceSyncSubmission.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<DeviceSyncSubmission> correct(String id, dynamic payload) async {
    final response = await _api.put('/v2/device-sync/submissions/$id/correction', body: {'payload': payload});
    if (response.statusCode != 200) throw AppException(response.body);
    return DeviceSyncSubmission.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<DeviceSyncSubmission> reprocess(String id) async {
    final response = await _api.post('/v2/device-sync/submissions/$id/reprocess');
    if (response.statusCode != 200) throw AppException(response.body);
    return DeviceSyncSubmission.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }
}
