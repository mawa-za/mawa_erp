import 'dart:convert';
import '../../core/api_client.dart';
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
    date: json['date']?.toString() ?? '',
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
