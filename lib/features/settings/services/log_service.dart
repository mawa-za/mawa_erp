import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/models/api_endpoint_log.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<PaginatedResponse<ApiEndpointLog>> getApiEndpointLogs({
    int page = 0,
    int size = 20,
    List<String>? sort,
  }) async {
    try {
      String path = '/v2/api-endpoint-logs?page=$page&size=$size';
      
      if (sort != null && sort.isNotEmpty) {
        for (var s in sort) {
          path += '&sort=$s';
        }
      }

      final response = await _apiClient.get(path);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return PaginatedResponse<ApiEndpointLog>.fromJson(
          decoded,
          (json) => ApiEndpointLog.fromJson(json),
        );
      } else {
        throw Exception('Failed to load API logs: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
