import 'dart:convert';
import '../api_client.dart';
import '../models/setting.dart';

class SettingService {
  static final SettingService _instance = SettingService._internal();
  factory SettingService() => _instance;
  SettingService._internal();

  Future<List<Setting>> getSettings() async {
    try {
      final response = await ApiClient().get('/setting', logoutOnUnauthorized: false);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Setting.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load settings');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addSetting(Setting setting) async {
    try {
      final response = await ApiClient().post(
        '/setting',
        body: setting.toJson(),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add setting');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSetting(String type, String attribute, String value) async {
    try {
      final response = await ApiClient().post(
        '/setting',
        body: {
          'type': type,
          'attribute': attribute,
          'value': value,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to update setting');
      }
    } catch (e) {
      rethrow;
    }
  }
}
