import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class RouteGuards {
  static Future<bool> isConfigured() async {
    if (kIsWeb) return true;
    final prefs = await SharedPreferences.getInstance();
    final tenant = prefs.getString('tenant');
    final apiHost = prefs.getString('api_host');
    return (tenant != null && tenant.isNotEmpty) && (apiHost != null && apiHost.isNotEmpty);
  }

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return token != null && token.isNotEmpty;
  }
}
