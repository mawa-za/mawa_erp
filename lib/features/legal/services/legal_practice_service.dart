import 'dart:convert';
import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LegalPracticeService {
  Future<Map<String, dynamic>> dashboard() async {
    final response = await ApiClient().get('/v2/legal/dashboard');
    if (response.statusCode == 200) return Map<String,dynamic>.from(jsonDecode(response.body));
    throw AppException('Failed to load legal dashboard');
  }
  Future<List<Map<String,dynamic>>> list(String resource, {String? caseId}) async {
    final response = await ApiClient().get('/v2/legal/$resource', queryParameters: {if(caseId != null) 'caseId': caseId});
    if (response.statusCode == 200) return (jsonDecode(response.body) as List).map((e)=>Map<String,dynamic>.from(e)).toList();
    throw AppException('Failed to load legal $resource');
  }
  Future<Map<String,dynamic>> create(String resource, Map<String,dynamic> body) async {
    final response = await ApiClient().post('/v2/legal/$resource', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) return Map<String,dynamic>.from(jsonDecode(response.body));
    throw AppException('Failed to create legal record: ${response.body}');
  }
}
