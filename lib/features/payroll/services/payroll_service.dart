import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/payroll_batch.dart';

class PayrollService {
  static final PayrollService _instance = PayrollService._internal();
  factory PayrollService() => _instance;
  PayrollService._internal();

  Future<List<PayrollBatchSummary>> getPayrollBatches() async {
    try {
      final response = await ApiClient().get('/v2/payroll/batch');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PayrollBatchSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load payroll batches: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PayrollBatchDetail> getPayrollBatch(String id) async {
    try {
      final response = await ApiClient().get('/v2/payroll/batch/$id');
      if (response.statusCode == 200) {
        return PayrollBatchDetail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load payroll batch details');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createPayrollBatch(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().post(
        '/v2/payroll/batch',
        body: data,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create payroll batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> copyPayrollBatch(String sourceId, String newReference) async {
    try {
      final response = await ApiClient().post(
        '/v2/payroll/batch/$sourceId/copy',
        body: {'reference': newReference},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to copy payroll batch: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
