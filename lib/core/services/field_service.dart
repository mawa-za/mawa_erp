import 'dart:convert';
import '../api_client.dart';
import '../models/field_option.dart';

class FieldService {
  static final FieldService _instance = FieldService._internal();
  factory FieldService() => _instance;
  FieldService._internal();

  List<FieldOption>? _cachedOptions;

  Future<List<FieldOption>> getOptions() async {
    if (_cachedOptions != null) return _cachedOptions!;

    try {
      final response = await ApiClient().get('/v2/field/option');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cachedOptions = data.map((json) => FieldOption.fromJson(json)).toList();
        return _cachedOptions!;
      } else {
        throw Exception('Failed to load field options');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<FieldOption>> getOptionsByField(String fieldName) async {
    final options = await getOptions();
    return options.where((opt) => opt.field == fieldName).toList();
  }
}
