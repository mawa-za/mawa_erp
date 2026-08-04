import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../features/membership/models/receipt_print_data.dart';
import '../errors/app_error.dart';
import 'setting_service.dart';

class BluetoothPrintService {
  static final BluetoothPrintService _instance =
      BluetoothPrintService._internal();
  factory BluetoothPrintService() => _instance;
  BluetoothPrintService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() => bluetooth.getBondedDevices();

  Future<void> printMembershipReceipt(
    ReceiptPrintData receipt, {
    BluetoothDevice? device,
  }) async {
    final connected = await bluetooth.isConnected;
    if (connected != true) {
      if (device == null) {
        throw AppException('No printer connected. Please select a printer.');
      }
      await bluetooth.connect(device);
    }

    final settings = await SettingService().getSettings();
    final companyName = _getAny(settings, const ['NAME', 'COMPANY-NAME'], 'MawaPay');
    final registration = _getAny(
      settings,
      const ['REGISTRATION-NUMBER', 'COMPANY-REGISTRATION-NUMBER'],
      '',
    );
    final vat = _getAny(settings, const ['VAT-NUMBER'], '');
    final fsp = _getAny(settings, const ['FSP-NUMBER'], '');
    final address = _join(
      const [
        'ADDRESS-LINE-1',
        'ADDRESS-LINE-2',
        'SUBURB',
        'CITY',
        'POSTAL-CODE',
      ].map((key) => _getAny(settings, [key], '')),
      ', ',
    );
    final contact = _join([
      _getAny(settings, const ['PHONE', 'COMPANY-TELEPHONE-NUMBER'], ''),
      _getAny(settings, const ['EMAIL'], ''),
      _getAny(settings, const ['WEBSITE'], ''),
    ], ' | ');

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(generator.text(
      companyName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    _centerDetail(bytes, generator, registration, prefix: 'Reg: ', bold: true);
    _centerDetail(bytes, generator, vat, prefix: 'VAT: ', bold: true);
    _centerDetail(bytes, generator, fsp, prefix: 'FSP: ', bold: true);
    _centerDetail(bytes, generator, address, bold: true);
    _centerDetail(bytes, generator, contact, bold: true);
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'OFFICIAL RECEIPT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(
      'Receipt No: ${receipt.receiptNo}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Trace ID: ${receipt.traceId}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Date: ${receipt.formattedReceiptDate}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Member: ${receipt.memberName}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Membership No: ${receipt.membershipNo}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'ID Number: ${receipt.identityNumber.isEmpty ? '-' : receipt.identityNumber}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Plan: ${receipt.planName}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Period: ${receipt.periodDescription}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'Payment: ${receipt.paymentMethod}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Amount: R ${(receipt.amountCents / 100).toStringAsFixed(2)}',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Cashier: ${receipt.employeeResponsible}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'Thank you',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'MawaPay',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    await bluetooth.writeBytes(Uint8List.fromList(bytes));
  }

  void _centerDetail(
    List<int> bytes,
    Generator generator,
    String value, {
    String prefix = '',
    bool bold = false,
  }) {
    if (value.trim().isEmpty) return;
    bytes.addAll(generator.text(
      '$prefix${value.trim()}',
      styles: PosStyles(align: PosAlign.center, bold: bold),
    ));
  }

  String _getAny(
    List<dynamic> settings,
    List<String> attributes,
    String fallback,
  ) {
    for (final attribute in attributes) {
      for (final setting in settings) {
        if (setting.attribute == attribute && setting.value.toString().trim().isNotEmpty) {
          return setting.value.toString().trim();
        }
      }
    }
    return fallback;
  }

  String _join(Iterable<String> values, String separator) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(separator);
}
