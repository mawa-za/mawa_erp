import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_party.dart';
import '../models/case_note.dart';
import '../models/case_event.dart';
import '../models/case_billing_summary.dart';
import '../models/case_dashboard_summary.dart';
import '../models/case_invoice_preview.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CaseManagementService {
  static final CaseManagementService _instance = CaseManagementService._internal();
  factory CaseManagementService() => _instance;
  CaseManagementService._internal();

  // --- Case Endpoints ---

  Future<List<LegalCase>> getCases({String? clientPartnerId, String? assignedTo, String? status, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (clientPartnerId != null) queryParams['clientPartnerId'] = clientPartnerId;
    if (assignedTo != null) queryParams['assignedTo'] = assignedTo;
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;

    final response = await ApiClient().get('/v2/cases', queryParameters: queryParams);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => LegalCase.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load cases: ${response.statusCode}');
  }

  Future<LegalCase> getCaseById(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId');
    if (response.statusCode == 200) {
      return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to load case detail: ${response.statusCode}');
  }

  Future<LegalCase> createCase(CreateLegalCaseRequest request) async {
    final response = await ApiClient().post('/v2/cases', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create case: ${response.body}');
  }

  Future<LegalCase> updateCase(String caseId, Map<String, dynamic> request) async {
    final response = await ApiClient().put('/v2/cases/$caseId', body: request);
    if (response.statusCode == 200) {
      return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to update case: ${response.body}');
  }

  Future<LegalCase> closeCase(String caseId) async {
    final response = await ApiClient().post('/v2/cases/$caseId/close');
    if (response.statusCode == 200) {
      return LegalCase.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to close case: ${response.body}');
  }

  // --- Task Endpoints ---

  Future<List<CaseTask>> getTasks(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/tasks');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTask.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load tasks: ${response.statusCode}');
  }

  Future<List<CaseTask>> getMyTasks(String userId) async {
    final response = await ApiClient().get('/v2/cases/tasks/my', queryParameters: {'userId': userId});
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTask.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load my tasks');
  }

  Future<CaseTask> createTask(String caseId, CreateCaseTaskRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/tasks', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseTask.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create task: ${response.body}');
  }

  Future<CaseTask> updateTaskStatus(String taskId, String status, {String? completedBy}) async {
    final response = await ApiClient().patch(
      '/v2/cases/tasks/$taskId/status', 
      body: {
        'status': status,
        if (completedBy != null) 'completedBy': completedBy,
      },
    );
    if (response.statusCode == 200) {
      return CaseTask.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to update task status');
  }

  // --- Time Entry Endpoints ---

  Future<List<CaseTimeEntry>> getTimeEntries(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/time-entries');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTimeEntry.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load time entries: ${response.statusCode}');
  }

  Future<CaseTimeEntry> createTimeEntry(String caseId, CreateCaseTimeEntryRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/time-entries', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseTimeEntry.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create time entry: ${response.body}');
  }

  // --- Disbursement Endpoints ---

  Future<List<CaseDisbursement>> getDisbursements(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/disbursements');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseDisbursement.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load disbursements: ${response.statusCode}');
  }

  Future<CaseDisbursement> createDisbursement(String caseId, CreateCaseDisbursementRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/disbursements', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseDisbursement.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create disbursement: ${response.body}');
  }

  // --- Billing Endpoints ---

  Future<CaseBillingSummary> getBillingSummary(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/billing-summary');
    if (response.statusCode == 200) {
      return CaseBillingSummary.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to load billing summary: ${response.statusCode}');
  }

  Future<void> recalculateBilling(String caseId) async {
    final response = await ApiClient().post('/v2/cases/$caseId/recalculate-billing');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to recalculate billing: ${response.body}');
    }
  }

  // --- Party Endpoints ---

  Future<List<CaseParty>> getParties(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/parties');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseParty.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load parties: ${response.statusCode}');
  }

  Future<CaseParty> createParty(String caseId, CreateCasePartyRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/parties', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseParty.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create party: ${response.body}');
  }

  Future<void> deleteParty(String partyId) async {
    final response = await ApiClient().delete('/v2/cases/parties/$partyId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to delete party: ${response.body}');
    }
  }

  // --- Note Endpoints ---

  Future<List<CaseNote>> getNotes(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/notes');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseNote.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load notes: ${response.statusCode}');
  }

  Future<CaseNote> createNote(String caseId, CreateCaseNoteRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/notes', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseNote.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create note: ${response.body}');
  }

  // --- Event Endpoints ---

  Future<List<CaseEvent>> getEvents(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/events');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseEvent.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load events: ${response.statusCode}');
  }

  Future<CaseEvent> createEvent(String caseId, CreateCaseEventRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/events', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseEvent.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to create event: ${response.body}');
  }

  Future<CaseEvent> updateEventStatus(String eventId, String status, {String? updatedBy}) async {
    final response = await ApiClient().patch(
      '/v2/cases/events/$eventId/status', 
      body: {
        'status': status,
        if (updatedBy != null) 'updatedBy': updatedBy,
      },
    );
    if (response.statusCode == 200) {
      return CaseEvent.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to update event status');
  }

  // --- Dashboard and Reporting Endpoints ---

  Future<CaseDashboardSummary> getDashboardSummary() async {
    final response = await ApiClient().get('/v2/cases/dashboard');
    if (response.statusCode == 200) {
      return CaseDashboardSummary.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to load dashboard summary: ${response.statusCode}');
  }

  Future<List<CaseTask>> getOverdueTasks() async {
    final response = await ApiClient().get('/v2/cases/tasks/overdue');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTask.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load overdue tasks: ${response.statusCode}');
  }

  Future<List<CaseEvent>> getUpcomingEvents({String? from, String? to}) async {
    final response = await ApiClient().get(
      '/v2/cases/events/upcoming',
      queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseEvent.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load upcoming events');
  }

  Future<List<CaseTimeEntry>> getUnbilledTimeEntries({String? caseId}) async {
    final response = await ApiClient().get(
      '/v2/cases/billing/unbilled/time-entries',
      queryParameters: {if (caseId != null) 'caseId': caseId},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTimeEntry.fromJson(json)).toList();
    }
    throw AppException('Failed to load unbilled time entries');
  }

  Future<List<CaseDisbursement>> getUnbilledDisbursements({String? caseId}) async {
    final response = await ApiClient().get(
      '/v2/cases/billing/unbilled/disbursements',
      queryParameters: {if (caseId != null) 'caseId': caseId},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseDisbursement.fromJson(json)).toList();
    }
    throw AppException('Failed to load unbilled disbursements');
  }

  Future<CaseInvoicePreview> getInvoicePreview(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/invoice-preview');
    if (response.statusCode == 200) {
      return CaseInvoicePreview.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body)),
      );
    }
    throw AppException('Failed to load invoice preview: ${response.statusCode}');
  }

  Future<dynamic> generateInvoice(String caseId, {Map<String, dynamic>? options}) async {
    final response = await ApiClient().post('/v2/cases/$caseId/generate-invoice', body: options);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw AppException('Failed to generate invoice');
  }
}
