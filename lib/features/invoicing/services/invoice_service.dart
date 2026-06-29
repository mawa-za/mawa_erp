import 'dart:convert';
import 'dart:typed_data';
import '../../../core/api_client.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> getInvoices({
    String? status,
    String? partnerId,
    String? invoiceDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (partnerId != null) queryParams['partnerId'] = partnerId;
    if (invoiceDate != null) queryParams['invoiceDate'] = invoiceDate;

    final response = await _apiClient.get('/v2/invoice', queryParameters: queryParams);
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    }
    throw Exception('Failed to load invoices');
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> invoice) async {
    final response = await _apiClient.post('/v2/invoice', body: invoice);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create invoice');
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load invoice');
  }

  Future<void> deleteInvoice(String id) async {
    final response = await _apiClient.delete('/v2/invoice/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete invoice');
    }
  }

  Future<Uint8List> getInvoicePdf(String invoiceId) async {
    try {
      final response = await _apiClient.get('/v2/invoice/$invoiceId/pdf');
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download invoice PDF: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendInvoiceEmail(String invoiceId, {String? email}) async {
    final response = await _apiClient.post(
      '/v2/invoice/$invoiceId/send-email',
      body: email != null ? {'email': email} : null,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send invoice email');
    }
  }

  Future<Map<String, dynamic>> getInvoicePayments(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id/payments');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load invoice payments');
  }

  Future<Map<String, dynamic>> getInvoiceLines(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id/lines');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load invoice lines');
  }

  Future<void> capturePayment(String invoiceId, Map<String, dynamic> payment) async {
    final response = await _apiClient.post('/v2/invoice/$invoiceId/payment', body: payment);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to capture payment');
    }
  }
}
