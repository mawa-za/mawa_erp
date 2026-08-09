import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/payroll_batch.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PayrollService {
  static final PayrollService _instance = PayrollService._internal();
  factory PayrollService() => _instance;
  PayrollService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<List<PayrollBatchSummary>> getPayrollBatches({String? payPeriod}) async {
    try {
      final response = await _apiClient.get(
        '/v2/payroll-payment-batch',
        queryParameters: payPeriod != null ? {'payPeriod': payPeriod} : null,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PayrollBatchSummary.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load payroll batches: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PayrollBatchDetail> getPayrollBatch(String id) async {
    try {
      final response = await _apiClient.get('/v2/payroll-payment-batch/$id');
      if (response.statusCode == 200) {
        return PayrollBatchDetail.fromJson(jsonDecode(response.body));
      } else {
        throw AppException('Failed to load payroll batch details');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createPayrollBatch(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/v2/payroll-payment-batch',
        body: data,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to create payroll batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePayrollBatch(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '/v2/payroll-payment-batch/$id',
        body: data,
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw AppException('Failed to update payroll batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> copyPayrollBatch(String sourceId, Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.post(
        '/v2/payroll-payment-batch/$sourceId/copy',
        body: payload,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to copy payroll batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approveBatch(String batchId) async {
    try {
      final response = await _apiClient.post('/v2/payroll-payment-batch/$batchId/approve');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to approve batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> getVerificationPrintout(String batchId) async {
    final response = await _apiClient.get(
      '/v2/payroll-payment-batch/$batchId/verification-printout',
      accept: 'application/pdf',
    );
    if (response.statusCode != 200) {
      throw AppException('Failed to generate payroll verification printout: ${response.body}');
    }
    return response.bodyBytes;
  }

  Future<PayrollBatchDetail> refreshBankReport(String batchId) async {
    final response = await _apiClient.post(
      '/v2/payroll-payment-batch/$batchId/bank-report/refresh',
    );
    if (response.statusCode != 200) {
      throw AppException('Failed to retrieve payroll bank report: ${response.body}');
    }
    return PayrollBatchDetail.fromJson(jsonDecode(response.body));
  }

  Future<void> cancelBatch(String batchId) async {
    try {
      final response = await _apiClient.post('/v2/payroll-payment-batch/$batchId/cancel');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to cancel batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addItem(String batchId, Map<String, dynamic> itemData) async {
    try {
      final response = await _apiClient.post(
        '/v2/payroll-payment-batch/$batchId/items',
        body: itemData,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to add item to batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
