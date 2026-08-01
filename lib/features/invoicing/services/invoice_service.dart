import 'dart:convert';
import 'dart:typed_data';
import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
    throw AppException('Failed to load invoices');
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> invoice) async {
    final response = await _apiClient.post('/v2/invoice', body: invoice);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw AppException('Failed to create invoice');
  }

  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> invoice) async {
    final response = await _apiClient.put('/v2/invoice/$id', body: invoice);
    if (response.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    throw AppException('Failed to update invoice: ${response.body}');
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw AppException('Failed to load invoice');
  }

  Future<void> deleteInvoice(String id) async {
    final response = await _apiClient.delete('/v2/invoice/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to delete invoice');
    }
  }

  Future<Uint8List> getInvoicePdf(String invoiceId) async {
    try {
      final response = await _apiClient.get('/v2/invoice/$invoiceId/pdf');
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw AppException('Failed to download invoice PDF: ${response.statusCode}');
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
      throw AppException('Failed to send invoice email');
    }
  }

  Future<Map<String, dynamic>> getInvoicePayments(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id/payments');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw AppException('Failed to load invoice payments');
  }

  Future<Map<String, dynamic>> getInvoiceLines(String id) async {
    final response = await _apiClient.get('/v2/invoice/$id/lines');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw AppException('Failed to load invoice lines');
  }

  Future<Map<String, dynamic>> issueCreditNote(
      String invoiceId, int amountCents, String reason) async {
    final response = await _apiClient.post(
      '/v2/invoice/$invoiceId/credit-note',
      body: {'amountCents': amountCents, 'reason': reason},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw AppException('Failed to issue credit note: ${response.body}');
  }

  Future<Uint8List> getCreditNotePdf(String creditNoteId) async {
    final response = await _apiClient.get('/v2/credit-note/$creditNoteId/pdf');
    if (response.statusCode == 200) return response.bodyBytes;
    throw AppException('Failed to download credit note: ${response.body}');
  }

  Future<Map<String, dynamic>> getCustomerStatement(
      String partnerId, DateTime fromDate, DateTime toDate) async {
    final response = await _apiClient.get(
      '/v2/customer-statement/$partnerId',
      queryParameters: {
        'fromDate': fromDate.toIso8601String().substring(0, 10),
        'toDate': toDate.toIso8601String().substring(0, 10),
      },
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw AppException('Failed to generate customer statement: ${response.body}');
  }

  Future<Uint8List> getCustomerStatementPdf(
      String partnerId, DateTime fromDate, DateTime toDate) async {
    final response = await _apiClient.get(
      '/v2/customer-statement/$partnerId/pdf',
      queryParameters: {
        'fromDate': fromDate.toIso8601String().substring(0, 10),
        'toDate': toDate.toIso8601String().substring(0, 10),
      },
      accept: 'application/pdf',
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw AppException('Failed to download customer statement: ${response.body}');
  }

  Future<void> capturePayment(String invoiceId, Map<String, dynamic> payment) async {
    final response = await _apiClient.post('/v2/invoice/$invoiceId/payment', body: payment);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to capture payment');
    }
  }
}
