import 'package:dio/dio.dart';
import '../../../core/dio_client.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_billing_summary.dart';

class CaseManagementService {
  final Dio _dio = DioClient().dio;

  Future<List<LegalCase>> getCases({
    String? clientPartnerId,
    String? assignedTo,
    String? status,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (clientPartnerId != null) queryParameters['clientPartnerId'] = clientPartnerId;
      if (assignedTo != null) queryParameters['assignedTo'] = assignedTo;
      if (status != null && status != 'ALL') queryParameters['status'] = status;
      if (search != null) queryParameters['search'] = search;

      final response = await _dio.get('/v2/cases', queryParameters: queryParameters);
      
      // Handle both direct list or paginated response
      final dynamic data = response.data;
      if (data is List) {
        return data.map((json) => LegalCase.fromJson(json)).toList();
      } else if (data is Map && data['content'] is List) {
        return (data['content'] as List).map((json) => LegalCase.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<LegalCase> getCaseById(String caseId) async {
    try {
      final response = await _dio.get('/v2/cases/$caseId');
      return LegalCase.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<LegalCase> createCase(CreateLegalCaseRequest request) async {
    try {
      final response = await _dio.post('/v2/cases', data: request.toJson());
      return LegalCase.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<LegalCase> updateCase(String caseId, Map<String, dynamic> request) async {
    try {
      final response = await _dio.put('/v2/cases/$caseId', data: request);
      return LegalCase.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeCase(String caseId) async {
    try {
      await _dio.post('/v2/cases/$caseId/close');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseTask>> getTasks(String caseId) async {
    try {
      final response = await _dio.get('/v2/cases/$caseId/tasks');
      final List<dynamic> data = response.data;
      return data.map((json) => CaseTask.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTask> createTask(String caseId, CreateCaseTaskRequest request) async {
    try {
      final response = await _dio.post('/v2/cases/$caseId/tasks', data: request.toJson());
      return CaseTask.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTask> updateTaskStatus(String taskId, UpdateCaseTaskStatusRequest request) async {
    try {
      final response = await _dio.patch('/v2/cases/tasks/$taskId/status', data: request.toJson());
      return CaseTask.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseTimeEntry>> getTimeEntries(String caseId) async {
    try {
      final response = await _dio.get('/v2/cases/$caseId/time-entries');
      final List<dynamic> data = response.data;
      return data.map((json) => CaseTimeEntry.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTimeEntry> createTimeEntry(String caseId, CreateCaseTimeEntryRequest request) async {
    try {
      final response = await _dio.post('/v2/cases/$caseId/time-entries', data: request.toJson());
      return CaseTimeEntry.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseDisbursement>> getDisbursements(String caseId) async {
    try {
      final response = await _dio.get('/v2/cases/$caseId/disbursements');
      final List<dynamic> data = response.data;
      return data.map((json) => CaseDisbursement.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseDisbursement> createDisbursement(String caseId, CreateCaseDisbursementRequest request) async {
    try {
      final response = await _dio.post('/v2/cases/$caseId/disbursements', data: request.toJson());
      return CaseDisbursement.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseBillingSummary> getBillingSummary(String caseId) async {
    try {
      final response = await _dio.get('/v2/cases/$caseId/billing-summary');
      return CaseBillingSummary.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recalculateBilling(String caseId) async {
    try {
      await _dio.post('/v2/cases/$caseId/recalculate-billing');
    } catch (e) {
      rethrow;
    }
  }
}
