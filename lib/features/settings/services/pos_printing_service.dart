import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../models/pos_printing_models.dart';
import '../../membership/models/receipt_print_data.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PosPrintingService {
  static const _terminalKeyPreference = 'mawa_pos_terminal_key';
  static const _terminalNamePreference = 'mawa_pos_terminal_name';
  static const _terminalLocationPreference = 'mawa_pos_terminal_location';

  Future<String> terminalKey() async {
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString(_terminalKeyPreference);
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(18, (_) => random.nextInt(256));
      key = base64UrlEncode(bytes).replaceAll('=', '');
      await prefs.setString(_terminalKeyPreference, key);
    }
    return key;
  }

  Future<PosTerminal> ensureTerminal({String? displayName, String? location}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await terminalKey();
    final name = (displayName ?? prefs.getString(_terminalNamePreference) ?? 'MAWA ERP Terminal').trim();
    final terminalLocation = (location ?? prefs.getString(_terminalLocationPreference) ?? '').trim();
    final response = await ApiClient().post('/v2/pos-printing/terminals/register', body: {
      'terminalKey': key,
      'displayName': name,
      'location': terminalLocation,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to register this terminal'));
    }
    await prefs.setString(_terminalNamePreference, name);
    await prefs.setString(_terminalLocationPreference, terminalLocation);
    return PosTerminal.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<List<PosPrintAgent>> getAgents() async {
    final response = await ApiClient().get('/v2/pos-printing/agents');
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Unable to load print agents'));
    }
    final decoded = jsonDecode(response.body);
    return (decoded as List)
        .whereType<Map>()
        .map((e) => PosPrintAgent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PosPrinter> configurePrinter({
    required String printerId,
    required bool supportsCut,
    required int paperWidthChars,
  }) async {
    final response = await ApiClient().put('/v2/pos-printing/printers/$printerId', body: {
      'supportsCut': supportsCut,
      'paperWidthChars': paperWidthChars,
      'printerRole': 'RECEIPT',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to configure receipt printer'));
    }
    return PosPrinter.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<PosTerminal> assignTerminal({
    required String terminalId,
    required String agentId,
    required String receiptPrinterId,
    String? documentPrinterId,
  }) async {
    final response = await ApiClient().put('/v2/pos-printing/terminals/$terminalId/assignment', body: {
      'agentId': agentId,
      'defaultReceiptPrinterId': receiptPrinterId,
      'defaultDocumentPrinterId': documentPrinterId,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to assign terminal printer'));
    }
    return PosTerminal.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<PosEnrollmentCode> createEnrollment({
    required String agentName,
    String? location,
    int validMinutes = 30,
  }) async {
    final response = await ApiClient().post('/v2/pos-printing/enrollments', body: {
      'agentName': agentName,
      'location': location,
      'validMinutes': validMinutes,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to create enrollment code'));
    }
    return PosEnrollmentCode.fromJson(Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<ReceiptPrintData> getReceiptPrintData(String receiptId) async {
    final response = await ApiClient().get('/v2/receipts/$receiptId/print');
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Unable to load receipt print data'));
    }
    return ReceiptPrintData.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<String> queueReceipt(String receiptId, {bool reprint = false, String? printerId}) async {
    final terminal = await ensureTerminal();
    if (!terminal.configured && (printerId == null || printerId.isEmpty)) {
      throw AppException('This terminal is not linked to a Windows print agent and receipt printer. Configure POS Printing under System Configuration.');
    }
    final requestId = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final response = await ApiClient().post('/v2/receipts/$receiptId/print-jobs', body: {
      'terminalId': terminal.id,
      'printerId': printerId,
      'requestId': requestId,
      'reprint': reprint,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to queue receipt for printing'));
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(response.body));
    return (decoded['id'] ?? '').toString();
  }

  Future<String> queueTestPrint({required String terminalId, String? printerId}) async {
    final requestId = 'test-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final response = await ApiClient().post('/v2/pos-printing/terminals/$terminalId/test-print', body: {
      'printerId': printerId,
      'requestId': requestId,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Unable to queue test print'));
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(response.body));
    return (decoded['id'] ?? '').toString();
  }

  Future<void> confirmDirectPrint(String receiptId) async {
    final response = await ApiClient().post('/v2/receipts/$receiptId/direct-print-spooled', body: const {});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_message(response.body, 'Receipt printed, but MAWA could not record the print'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return (decoded['message'] ?? decoded['error'] ?? fallback).toString();
    } catch (_) {}
    return body.trim().isEmpty ? fallback : body;
  }
}
