import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/survey.dart';

class SurveyService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Survey>> getSurveys() async {
    try {
      final response = await _apiClient.get('/v2/surveys');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Survey.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> createSurvey(Map<String, dynamic> data) async {
    await _apiClient.post('/v2/surveys', body: data);
  }

  Future<void> submitSurveyResponse(String surveyId, Map<String, dynamic> response) async {
    await _apiClient.post('/v2/surveys/$surveyId/responses', body: response);
  }
}
