import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../models/payment_request.dart';

class PaymentRequestService {
  static final PaymentRequestService _instance = PaymentRequestService._internal();
  factory PaymentRequestService() => _instance;
  PaymentRequestService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<PaymentRequestResponse>> getPaymentRequests({String? status}) async {
    try {
      String path;
      if (status != null && status != 'ALL') {
        path = '/v2/payment-request/status/$status';
      } else {
        path = '/v2/payment-request';
      }
      
      final response = await _apiClient.get(path);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data;
        
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'] ?? [];
        } else if (decoded is Map) {
          data = [];
          debugPrint('PaymentRequestService: Unexpected Map response format: $decoded');
        } else {
          data = [];
        }
        
        return data.map((json) => PaymentRequestResponse.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load payment requests: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('PaymentRequestService Error: $e');
      rethrow;
    }
  }

  Future<PaymentRequestResponse> createPaymentRequest(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/v2/payment-request',
        body: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentRequestResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create payment request: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestResponse> getPaymentRequestById(String id) async {
    final response = await _apiClient.get('/v2/payment-request/$id');
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load payment request');
  }

  Future<PaymentRequestResponse> updatePaymentRequest(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/v2/payment-request/$id', body: data);
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update payment request');
  }

  Future<PaymentRequestResponse> submitPaymentRequest(String id) async {
    final response = await _apiClient.post('/v2/payment-request/$id/submit');
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to submit payment request');
  }

  Future<PaymentRequestResponse> updatePaymentRequestStatus(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.post('/v2/payment-request/$id/status', body: data);
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update status');
  }

  Future<PaymentRequestResponse> markAsPaid(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.post('/v2/payment-request/$id/paid', body: data);
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to mark as paid');
  }

  Future<PaymentRequestResponse> cancelPaymentRequest(String id, {String? comment}) async {
    final response = await _apiClient.post('/v2/payment-request/$id/cancel', queryParameters: {
      if (comment != null) 'comment': comment,
    });
    if (response.statusCode == 200) {
      return PaymentRequestResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to cancel payment request');
  }

  Future<List<PaymentRequestStatusHistoryEntity>> getPaymentRequestHistory(String id) async {
    final response = await _apiClient.get('/v2/payment-request/$id/history');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaymentRequestStatusHistoryEntity.fromJson(json)).toList();
    }
    throw Exception('Failed to load history');
  }

  Future<List<PaymentRequestResponse>> getPaymentRequestsByType(String type) async {
    final response = await _apiClient.get('/v2/payment-request/type/$type');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaymentRequestResponse.fromJson(json)).toList();
    }
    throw Exception('Failed to load payment requests by type');
  }

  Future<List<PaymentRequestResponse>> getPaymentRequestsByPayee(String partnerId) async {
    final response = await _apiClient.get('/v2/payment-request/payee/$partnerId');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaymentRequestResponse.fromJson(json)).toList();
    }
    throw Exception('Failed to load payment requests for payee');
  }

  Future<Map<String, dynamic>?> getBankReport(String id) async {
    final response = await _apiClient.get(
      '/v2/payment-request/$id/bank-report',
      logoutOnUnauthorized: false,
    );
    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return null;
    }
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    }
    return null;
  }

  Future<PaymentRequestResponse> approvePaymentRequest(String id, {String? comment}) {
    return updatePaymentRequestStatus(id, {
      'status': 'APPROVED',
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<PaymentRequestResponse> rejectPaymentRequest(String id, {String? comment}) {
    return updatePaymentRequestStatus(id, {
      'status': 'REJECTED',
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<PaymentRequestResponse> queueForPayment(String id, {String? comment}) {
    return updatePaymentRequestStatus(id, {
      'status': 'QUEUED_FOR_PAYMENT',
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<PaymentRequestResponse> markProcessed(String id, {String? comment}) {
    return updatePaymentRequestStatus(id, {
      'status': 'PROCESSED',
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<PaymentRequestResponse> markFailed(String id, {String? comment}) {
    return updatePaymentRequestStatus(id, {
      'status': 'FAILED',
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<BankReport?> getTypedBankReport(String id) async {
    final data = await getBankReport(id);
    if (data == null) return null;
    return BankReport.fromJson(data);
  }

  Future<List<PaymentRequestResponse>> searchPaymentRequests({
    String? status,
    String? type,
    String? payeePartnerId,
  }) async {
    if (payeePartnerId != null && payeePartnerId.isNotEmpty) {
      return getPaymentRequestsByPayee(payeePartnerId);
    }
    if (type != null && type.isNotEmpty && type != 'ALL') {
      return getPaymentRequestsByType(type);
    }
    return getPaymentRequests(status: status);
  }

}
