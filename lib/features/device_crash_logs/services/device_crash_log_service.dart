import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/device_crash_log.dart';

class DeviceCrashLogService {
  final ApiClient _api = ApiClient();

  Future<List<DeviceCrashLog>> list({String search = ''}) async {
    final response = await _api.get('/v2/device-crash-logs', queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': 0,
      'size': 200,
    });
    if (response.statusCode != 200) throw AppException(response.body);
    final decoded = jsonDecode(response.body);
    final content = decoded is Map ? (decoded['content'] as List? ?? const []) : const [];
    return content
        .whereType<Map>()
        .map((entry) => DeviceCrashLog.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<DeviceCrashLog> get(String logId) async {
    final response = await _api.get('/v2/device-crash-logs/$logId');
    if (response.statusCode != 200) throw AppException(response.body);
    return DeviceCrashLog.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
}
