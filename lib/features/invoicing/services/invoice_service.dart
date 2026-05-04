import 'dart:convert';
import 'dart:typed_data';
import '../../../core/api_client.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  Future<void> sendInvoiceEmail(String invoiceId, {String? email}) async {
    try {
      final response = await ApiClient().post(
        '/v2/invoice/$invoiceId/send-email',
        body: email != null ? {'email': email} : null,
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send invoice email');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> getInvoicePdf(String invoiceId) async {
    try {
      final response = await ApiClient().post('/v2/invoice/$invoiceId/pdf/base64');
      
      if (response.statusCode == 200) {
        // Backend returns a base64 string (sometimes wrapped in quotes if it's a plain JSON string response)
        String base64String = response.body;
        if (base64String.startsWith('"') && base64String.endsWith('"')) {
          base64String = base64String.substring(1, base64String.length - 1);
        }
        return base64Decode(base64String);
      } else {
        throw Exception('Failed to download invoice PDF: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
