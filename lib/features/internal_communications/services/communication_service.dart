import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/communication.dart';

class CommunicationService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Communication>> getCommunications() async {
    // Note: Assuming endpoint exists or using mock data for now as per "Implement a simple CRM solution"
    // In a real scenario, we'd use /v2/communications
    try {
      final response = await _apiClient.get('/v2/communications');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Communication.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> createCommunication(Map<String, dynamic> data) async {
    await _apiClient.post('/v2/communications', body: data);
  }

  Future<void> sendCommunication(String id) async {
    await _apiClient.post('/v2/communications/$id/send');
  }
}
