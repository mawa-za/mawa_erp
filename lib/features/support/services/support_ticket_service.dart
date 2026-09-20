import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class SupportTicketService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _api.get('/v2/support-tickets');
    if (response.statusCode != 200) throw AppException(response.body);
    return (jsonDecode(response.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> create(Map<String, dynamic> body) async {
    final response = await _api.post('/v2/support-tickets', body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw AppException(response.body);
  }
}
