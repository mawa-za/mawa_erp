import 'dart:convert';

import '../../../core/errors/app_error.dart';
import '../../../core/api_client.dart';

class ReceiptCancellationService {
  Future<void> requestCancellation({
    required String paymentBatchId,
    required String requesterId,
    required String reason,
  }) async {
    if (paymentBatchId.trim().isEmpty) throw ArgumentError('Payment batch is required.');
    if (requesterId.trim().isEmpty) throw ArgumentError('Requester is required.');
    if (reason.trim().isEmpty) throw ArgumentError('Cancellation reason is required.');
    final response = await ApiClient().post(
      '/v2/payment-batches/${paymentBatchId.trim()}/cancellation-request',
      body: {'requesterId': requesterId.trim(), 'reason': reason.trim()},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException.fromHttp(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallback: _message(response.body),
      );
    }
  }

  String _message(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map) return '${value['message'] ?? value['error'] ?? 'Receipt cancellation could not be submitted.'}';
    } catch (_) {}
    return 'Receipt cancellation could not be submitted.';
  }
}
