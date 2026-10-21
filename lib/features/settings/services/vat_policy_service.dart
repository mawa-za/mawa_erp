import 'dart:convert';

import '../../../core/api_client.dart';

class VatPolicy {
  final bool vatRegistered;
  final String defaultPricingMethod;
  final String standardRatePercent;
  final String effectiveFrom;
  final String? effectiveTo;

  const VatPolicy({required this.vatRegistered, required this.defaultPricingMethod, required this.standardRatePercent, required this.effectiveFrom, this.effectiveTo});

  factory VatPolicy.fromJson(Map<String, dynamic> data) => VatPolicy(
    vatRegistered: data['vat_registered'] == true || data['vat_registered'] == 1,
    defaultPricingMethod: data['default_pricing_method']?.toString() ?? 'EXCLUSIVE',
    standardRatePercent: data['standard_rate_percent']?.toString() ?? '0',
    effectiveFrom: data['effective_from']?.toString() ?? '',
    effectiveTo: data['effective_to']?.toString(),
  );
}

class VatPolicyService {
  static const _path = '/v2/integrations/xero/vat-policy';

  Future<List<VatPolicy>> load() async {
    final response = await ApiClient().get(_path);
    if (response.statusCode != 200) throw Exception(_message(response.body, 'Unable to load VAT policies (${response.statusCode}).'));
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['policies'] is! List) throw const FormatException('Unexpected VAT policy response');
    return (payload['policies'] as List).map((item) => VatPolicy.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> create({required bool vatRegistered, String? vatRegistrationNumber, required String defaultPricingMethod, required num standardRatePercent, required String effectiveFrom}) async {
    final response = await ApiClient().post(_path, body: {
      'vatRegistered': vatRegistered,
      'vatRegistrationNumber': vatRegistrationNumber,
      'defaultPricingMethod': defaultPricingMethod,
      'standardRatePercent': standardRatePercent,
      'effectiveFrom': effectiveFrom,
      'effectiveTo': null,
    });
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception(_message(response.body, 'Unable to create VAT policy (${response.statusCode}).'));
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) return decoded['message'].toString();
    } catch (_) { /* Unexpected response */ }
    return fallback;
  }
}
