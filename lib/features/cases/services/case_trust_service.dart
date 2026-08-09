import 'dart:convert';
import '../../../core/api_client.dart';
import '../models/case_trust.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CaseTrustService {
  static final CaseTrustService _instance = CaseTrustService._internal();
  factory CaseTrustService() => _instance;
  CaseTrustService._internal();

  Future<CaseTrustBalance> getTrustBalance(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/trust/balance');
    if (response.statusCode == 200) {
      return CaseTrustBalance.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
    }
    throw AppException('Failed to load trust balance: ${response.statusCode}');
  }

  Future<List<CaseTrustTransaction>> getTrustTransactions(String caseId) async {
    final response = await ApiClient().get('/v2/cases/$caseId/trust/transactions');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CaseTrustTransaction.fromJson(Map<String, dynamic>.from(json))).toList();
    }
    throw AppException('Failed to load trust transactions: ${response.statusCode}');
  }

  Future<CaseTrustTransaction> receiveTrustFunds(String caseId, CaseTrustReceiptRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/trust/receipts', body: request.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CaseTrustTransaction.fromJson(jsonDecode(response.body));
    }
    throw AppException('Failed to receive trust funds: ${response.body}');
  }

  Future<void> transferToBusiness(String caseId, CaseTrustBusinessTransferRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/trust/transfers/business', body: request.toJson());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to transfer to business: ${response.body}');
    }
  }

  Future<void> refundClient(String caseId, CaseTrustRefundRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/trust/refunds', body: request.toJson());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to refund client: ${response.body}');
    }
  }

  Future<void> payThirdParty(String caseId, CaseTrustThirdPartyPaymentRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/trust/third-party-payments', body: request.toJson());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to pay third party: ${response.body}');
    }
  }

  Future<void> reverseTransaction(String caseId, String transactionId, CaseTrustReverseTransactionRequest request) async {
    final response = await ApiClient().post('/v2/cases/$caseId/trust/transactions/$transactionId/reverse', body: request.toJson());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to reverse transaction: ${response.body}');
    }
  }
}
