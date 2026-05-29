import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';

class CaseManagementService {
  static final CaseManagementService _instance = CaseManagementService._internal();
  factory CaseManagementService() => _instance;
  CaseManagementService._internal();

  Future<List<LegalCase>> getCases({String? clientPartnerId, String? assignedTo, String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (clientPartnerId != null) queryParams['clientPartnerId'] = clientPartnerId;
      if (assignedTo != null) queryParams['assignedTo'] = assignedTo;
      if (status != null) queryParams['status'] = status;

      final response = await ApiClient().get('/v2/cases', queryParameters: queryParams);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LegalCase.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load cases: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LegalCase> getCaseById(String caseId) async {
    try {
      final response = await ApiClient().get('/v2/cases/$caseId');
      if (response.statusCode == 200) {
        return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to load case detail: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LegalCase> createCase(CreateLegalCaseRequest request) async {
    try {
      final response = await ApiClient().post('/v2/cases', body: request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to create case: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseTask>> getTasks(String caseId) async {
    try {
      final response = await ApiClient().get('/v2/cases/$caseId/tasks');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CaseTask.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTask> createTask(String caseId, CreateCaseTaskRequest request) async {
    try {
      final response = await ApiClient().post('/v2/cases/$caseId/tasks', body: request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseTask.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to create task: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTask> updateTaskStatus(String taskId, UpdateCaseTaskStatusRequest request) async {
    try {
      final response = await ApiClient().patch('/v2/cases/tasks/$taskId/status', body: request.toJson());
      if (response.statusCode == 200) {
        return CaseTask.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to update task status: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseTimeEntry>> getTimeEntries(String caseId) async {
    try {
      final response = await ApiClient().get('/v2/cases/$caseId/time-entries');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CaseTimeEntry.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load time entries: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseTimeEntry> createTimeEntry(String caseId, CreateCaseTimeEntryRequest request) async {
    try {
      final response = await ApiClient().post('/v2/cases/$caseId/time-entries', body: request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseTimeEntry.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to create time entry: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CaseDisbursement>> getDisbursements(String caseId) async {
    try {
      final response = await ApiClient().get('/v2/cases/$caseId/disbursements');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CaseDisbursement.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load disbursements: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<CaseDisbursement> createDisbursement(String caseId, CreateCaseDisbursementRequest request) async {
    try {
      final response = await ApiClient().post('/v2/cases/$caseId/disbursements', body: request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseDisbursement.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
      } else {
        throw Exception('Failed to create disbursement: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBillingSummary(String caseId) async {
    try {
      final response = await ApiClient().get('/v2/cases/$caseId/billing-summary');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load billing summary: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recalculateBilling(String caseId) async {
    try {
      final response = await ApiClient().post('/v2/cases/$caseId/recalculate-billing');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to recalculate billing: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
