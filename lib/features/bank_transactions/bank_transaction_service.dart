import 'dart:convert';
import '../../core/api_client.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/errors/app_error.dart';

class BankTransaction {
  final String depositId;
  final String date;
  final int amountCents;
  final int availableCents;
  final String reference;
  final String accountNumber;
  final String status;

  const BankTransaction({required this.depositId, required this.date,
    required this.amountCents, required this.availableCents,
    required this.reference, required this.accountNumber, required this.status});

  factory BankTransaction.fromJson(Map<String, dynamic> json) => BankTransaction(
    depositId: json['depositId']?.toString() ?? '',
    date: AppDateUtils.normalizeDate(json['date']),
    amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
    availableCents: (json['availableCents'] as num?)?.toInt() ?? 0,
    reference: json['reference']?.toString() ?? '',
    accountNumber: json['accountNumber']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
  );
}

class BankTransactionsPage {
  final List<BankTransaction> content;
  final bool last;
  const BankTransactionsPage(this.content, this.last);
}

class BankTransactionService {
  /// Empty IDs are allowed only while tenant enforcement is not active.
  /// Non-empty IDs must always be syntactically valid, even during transition.
  static bool depositIdAccepted(String? value, {required bool isRequired}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return !isRequired;
    return RegExp(r'^DEP-\d{1,18}$', caseSensitive: false).hasMatch(text);
  }

  Future<BankTransactionsPage> search({String search = '', bool creditsOnly = false,
    DateTime? fromDate, DateTime? toDate, int? amountCents, int page = 0}) async {
    final response = await ApiClient().get('/v2/bank-transactions', queryParameters: {
      'search': search, 'creditsOnly': creditsOnly, 'page': page, 'size': 30,
      if (fromDate != null) 'fromDate': _date(fromDate),
      if (toDate != null) 'toDate': _date(toDate),
      if (amountCents != null) 'amountCents': amountCents,
    });
    if (response.statusCode != 200) throw AppException.fromHttp(
      statusCode: response.statusCode, responseBody: response.body,
      fallback: 'Could not retrieve bank transactions');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return BankTransactionsPage((json['content'] as List? ?? [])
      .whereType<Map>().map((e) => BankTransaction.fromJson(Map<String, dynamic>.from(e))).toList(),
      json['last'] == true);
  }

  /// Readable by signed-in cashiers; bank statement settings are separately restricted.
  Future<Map<String, dynamic>> getDepositPolicy() async {
    final response = await ApiClient().get('/v2/bank-transactions/deposit-policy');
    if (response.statusCode != 200) throw AppException('Could not load bank deposit policy: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<bool> requireDepositIdNow() async => (await getDepositPolicy())['requiredNow'] == true;

  Future<void> saveDepositPolicy({required bool requireDepositId, String? effectiveFrom}) async {
    final response = await ApiClient().put('/v2/bank-transactions/deposit-policy', body: {
      'requireDepositId': requireDepositId, 'effectiveFrom': effectiveFrom,
    });
    if (response.statusCode != 200) throw AppException('Could not update deposit enforcement: ${response.body}');
  }

  Future<Map<String, dynamic>> pendingVerification({required String type, String search = '', int page = 0}) async {
    final response = await ApiClient().get('/v2/bank-transactions/pending-verification',
      queryParameters: {'type': type, 'search': search, 'page': page, 'size': 30});
    if (response.statusCode != 200) throw AppException('Could not load pending bank verifications: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<bool> canReconcile() async {
    final response = await ApiClient().get('/v2/bank-transactions/reconcile-permission');
    if (response.statusCode != 200) throw AppException('Could not load reconciliation permission: ${response.body}');
    return (jsonDecode(response.body) as Map)['allowed'] == true;
  }

  Future<void> reconcile({required String type, required String objectId, required String depositId}) async {
    final response = await ApiClient().post('/v2/bank-transactions/reconcile',
      body: {'type': type, 'objectId': objectId, 'depositId': depositId});
    if (response.statusCode != 200) throw AppException('Could not reconcile bank transaction: ${response.body}');
  }

  Future<Map<String, dynamic>> getConfiguration() async {
    final response = await ApiClient().get('/v2/bank-transactions/config');
    if (response.statusCode != 200) throw AppException('Could not load bank mailbox configuration: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> allocations(String depositId) async {
    final response = await ApiClient().get('/v2/bank-transactions/$depositId/allocations');
    if (response.statusCode != 200) throw AppException('Could not load deposit allocations');
    return (jsonDecode(response.body) as List)
      .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveConfiguration(Map<String, dynamic> config) async {
    final response = await ApiClient().put('/v2/bank-transactions/config', body: config);
    if (response.statusCode != 200) throw AppException('Could not save bank mailbox configuration: ${response.body}');
  }

  Future<Map<String, dynamic>> getMicrosoftAppInfo() async {
    final response = await ApiClient().get('/v2/bank-transactions/microsoft/info');
    if (response.statusCode != 200) throw AppException('MAWA Microsoft 365 application is not configured: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<String> connectMicrosoft() async {
    final response = await ApiClient().post('/v2/bank-transactions/microsoft/connect', body: {});
    if (response.statusCode != 200) throw AppException('Could not start Microsoft sign-in: ${response.body}');
    return (jsonDecode(response.body) as Map)['authorizationUrl']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> verifyMicrosoft() async {
    final response = await ApiClient().post('/v2/bank-transactions/microsoft/verify', body: {});
    if (response.statusCode != 200) throw AppException('Microsoft mailbox verification failed: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> disconnectMicrosoft() async {
    final response = await ApiClient().post('/v2/bank-transactions/microsoft/disconnect', body: {});
    if (response.statusCode != 200) throw AppException('Could not disconnect Microsoft 365: ${response.body}');
  }

  Future<Map<String, dynamic>> syncNow() async {
    final response = await ApiClient().post('/v2/bank-transactions/sync', body: {});
    if (response.statusCode != 200) throw AppException('Bank statement sync failed: ${response.body}');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
