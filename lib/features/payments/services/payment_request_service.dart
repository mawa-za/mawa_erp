import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/payment_request.dart';

class PaymentRequestService {
  static final PaymentRequestService _instance = PaymentRequestService._internal();
  factory PaymentRequestService() => _instance;
  PaymentRequestService._internal();

  Future<void> createPaymentRequest(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().post(
        '/v2/payment-request',
        body: data,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create payment request: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PaymentRequestSummary>> getPaymentRequests({String? status}) async {
    try {
      String path = '/v2/payment-request';
      if (status != null && status != 'ALL') {
        path += '?status=$status';
      }
      final response = await ApiClient().get(path);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PaymentRequestSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load payment requests');
      }
    } catch (e) {
      rethrow;
    }
  }
}
