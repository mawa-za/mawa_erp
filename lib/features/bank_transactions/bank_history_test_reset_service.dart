import 'dart:convert';
import '../../core/api_client.dart';
import '../../core/errors/app_error.dart';

/// Separate from the normal BankTransactionService to avoid altering deposit flows.
/// Only available when backend's disabled-by-default, tenant-specific test feature is on.
class BankHistoryTestResetService {
  static String confirmationFor(String tenantId) => 'RESET BANK HISTORY: $tenantId';

  static bool canConfirm(Map<String, dynamic>? preview) =>
      preview != null && preview['canReset'] == true;

  Future<Map<String, dynamic>?> preview() async {
    final response = await ApiClient().get('/v2/bank-transactions/test-reset/preview');
    if (response.statusCode == 403 || response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppException.fromHttp(statusCode: response.statusCode,
        responseBody: response.body, fallback: 'Could not check test bank history reset');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> reset({
    required String tenantId, required String confirmation,
    required int expectedTransactions, required int expectedImports,
    required int expectedFilesToRearm,
  }) async {
    final response = await ApiClient().post('/v2/bank-transactions/test-reset', body: {
      'tenantId': tenantId, 'confirmation': confirmation,
      'expectedTransactions': expectedTransactions, 'expectedImports': expectedImports,
      'expectedFilesToRearm': expectedFilesToRearm,
    });
    if (response.statusCode != 200) {
      throw AppException.fromHttp(statusCode: response.statusCode,
        responseBody: response.body, fallback: 'Could not reset test bank history');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
