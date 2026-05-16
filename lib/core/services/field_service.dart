import 'dart:convert';
import '../api_client.dart';
import '../models/field_option.dart';

class FieldService {
  static final FieldService _instance = FieldService._internal();
  factory FieldService() => _instance;
  FieldService._internal();

  List<FieldOption>? _cachedOptions;

  Future<List<FieldOption>> getOptions() async {
    try {
      final response = await ApiClient().get('/v2/field/option');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'];
        } else {
          data = [];
        }

        _cachedOptions = data.map((json) => FieldOption.fromDynamic(json)).toList();
        return _cachedOptions!;
      } else {
        throw Exception('Failed to load field options: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FieldOption>> getOptionsByField(String fieldName) async {
    final options = await getOptions();
    return options.where((opt) => opt.field == fieldName).toList();
  }

  Future<void> saveOption(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().post('/v2/field/option', body: data);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save field option: ${response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOption(String field, String code, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().put('/v2/field/option/$field/$code', body: data);
      if (response.statusCode != 200) {
        throw Exception('Failed to update field option: ${response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOption(String field, String code) async {
    try {
      final response = await ApiClient().delete('/v2/field/option/$field/$code');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete field option: ${response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }
}
