import 'dart:convert';
import '../api_client.dart';
import '../models/field_option.dart';

class FieldService {
  static final FieldService _instance = FieldService._internal();
  factory FieldService() => _instance;
  FieldService._internal();

  List<FieldOption>? _cachedOptions;
  List<Map<String, dynamic>>? _cachedFields;

  Future<List<Map<String, dynamic>>> getFields() async {
    try {
      if (_cachedFields != null) return _cachedFields!;
      final response = await ApiClient().get('/v2/field');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data = decoded is List ? decoded : [];
        _cachedFields = data.cast<Map<String, dynamic>>();
        return _cachedFields!;
      } else {
        throw Exception('Failed to load fields: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addField(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().post('/v2/field', body: data);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add field: ${response.body.isNotEmpty ? response.body : response.statusCode}');
      }
      _cachedFields = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }

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
    try {
      final response = await ApiClient().get('/v2/field/$fieldName/option');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data = decoded is List ? decoded : [];
        return data.map((json) => FieldOption.fromDynamic(json)).toList();
      } else {
        throw Exception('Failed to load options for field $fieldName: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveOption(String fieldName, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().post('/v2/field/$fieldName/option', body: data);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save field option: ${response.body.isNotEmpty ? response.body : response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOption(String fieldName, String code, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().put('/v2/field/$fieldName/option', queryParameters: {'fieldOption': code}, body: data);
      if (response.statusCode != 200) {
        throw Exception('Failed to update field option: ${response.body.isNotEmpty ? response.body : response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOption(String fieldName, String code) async {
    try {
      final response = await ApiClient().delete('/v2/field/$fieldName/option', queryParameters: {'fieldOption': code});
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete field option: ${response.body.isNotEmpty ? response.body : response.statusCode}');
      }
      _cachedOptions = null; // Clear cache
    } catch (e) {
      rethrow;
    }
  }
}
