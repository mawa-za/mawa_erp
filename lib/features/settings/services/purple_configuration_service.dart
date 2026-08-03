import 'dart:convert';

import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/purple_configuration.dart';

class PurpleConfigurationService {
  static const _base = '/v2/purple/provider-enrolment';

  Future<PurpleConfiguration> load() async {
    final response = await ApiClient().get(_base);
    _ensureSuccess(response.statusCode, response.body, 'Unable to load Purple configuration');
    return PurpleConfiguration.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<List<Map<String, dynamic>>> products() async {
    final response = await ApiClient().get('$_base/products');
    _ensureSuccess(response.statusCode, response.body, 'Unable to load products and services');
    return (jsonDecode(response.body) as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveProvider(Map<String, dynamic> value) async {
    final response = await ApiClient().put('$_base/provider', body: value);
    _ensureSuccess(response.statusCode, response.body, 'Unable to save Purple provider profile');
  }

  Future<void> saveService(Map<String, dynamic> value) async {
    final response = await ApiClient().put('$_base/services', body: value);
    _ensureSuccess(response.statusCode, response.body, 'Unable to save Purple service');
  }

  Future<void> deleteService(String id) async {
    final response = await ApiClient().delete('$_base/services/$id');
    _ensureSuccess(response.statusCode, response.body, 'Unable to remove Purple service');
  }

  Future<void> saveAvailabilityRule(Map<String, dynamic> value) async {
    final response = await ApiClient().put('$_base/availability-rules', body: value);
    _ensureSuccess(response.statusCode, response.body, 'Unable to save availability');
  }

  Future<void> deleteAvailabilityRule(String id) async {
    final response = await ApiClient().delete('$_base/availability-rules/$id');
    _ensureSuccess(response.statusCode, response.body, 'Unable to remove availability');
  }

  void _ensureSuccess(int status, String body, String fallback) {
    if (status >= 200 && status < 300) return;
    try {
      final value = jsonDecode(body);
      if (value is Map) throw AppException((value['message'] ?? value['error'] ?? fallback).toString());
    } catch (error) {
      if (error is AppException) rethrow;
    }
    throw AppException(body.trim().isEmpty ? fallback : body);
  }
}
