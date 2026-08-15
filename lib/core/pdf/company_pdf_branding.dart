import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../api_client.dart';
import '../models/setting.dart';
import '../services/setting_service.dart';

class CompanyPdfBranding {
  final String name;
  final String registrationNumber;
  final String vatNumber;
  final String fspNumber;
  final String address;
  final String phone;
  final String email;
  final String website;
  final pw.MemoryImage? logo;

  const CompanyPdfBranding({
    required this.name,
    required this.registrationNumber,
    required this.vatNumber,
    required this.fspNumber,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.logo,
  });

  static Future<CompanyPdfBranding> load() async {
    List<Setting> settings = const [];
    try {
      settings = await SettingService().getSettings();
    } catch (_) {
      // PDF generation should still work when company settings are temporarily unavailable.
    }

    String value(String attribute, [String fallback = '']) {
      for (final setting in settings) {
        if (setting.type == 'TENANT' && setting.attribute == attribute) {
          final result = setting.value.trim();
          if (result.isNotEmpty) return result;
        }
      }
      return fallback;
    }

    String firstOf(List<String> attributes, [String fallback = '']) {
      for (final attribute in attributes) {
        final result = value(attribute);
        if (result.isNotEmpty) return result;
      }
      return fallback;
    }

    final address = [
      value('ADDRESS-LINE-1'),
      value('ADDRESS-LINE-2'),
      value('SUBURB'),
      value('CITY'),
      value('POSTAL-CODE'),
    ].where((part) => part.isNotEmpty).join(', ');

    pw.MemoryImage? logo;
    try {
      final response = await ApiClient().get(
        '/v2/company-logo/content',
        accept: 'image/*',
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        logo = pw.MemoryImage(Uint8List.fromList(response.bodyBytes));
      }
    } catch (_) {
      // A missing logo must not stop the document from being generated.
    }

    return CompanyPdfBranding(
      name: firstOf(const ['NAME', 'COMPANY-NAME'], 'mawa'),
      registrationNumber: firstOf(
        const ['REGISTRATION-NUMBER', 'COMPANY-REGISTRATION-NUMBER'],
      ),
      vatNumber: value('VAT-NUMBER'),
      fspNumber: value('FSP-NUMBER'),
      address: address.isEmpty ? value('COMPANY-ADDRESS') : address,
      phone: firstOf(const ['PHONE', 'COMPANY-TELEPHONE-NUMBER']),
      email: value('EMAIL'),
      website: value('WEBSITE'),
      logo: logo,
    );
  }

  pw.Widget header({String? documentTitle}) {
    final identifiers = <String>[
      if (registrationNumber.isNotEmpty) 'Reg No: $registrationNumber',
      if (vatNumber.isNotEmpty) 'VAT No: $vatNumber',
      if (fspNumber.isNotEmpty) 'FSP No: $fspNumber',
    ];
    final contacts = <String>[
      if (phone.isNotEmpty) phone,
      if (email.isNotEmpty) email,
      if (website.isNotEmpty) website,
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 4,
              child: logo != null
                  ? pw.Align(
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        width: 72,
                        height: 72,
                        child: pw.Image(logo!, fit: pw.BoxFit.contain),
                      ),
                    )
                  : pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    name,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  if (address.isNotEmpty)
                    pw.Text(address, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                  if (identifiers.isNotEmpty)
                    pw.Text(identifiers.join(' | '), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                  if (contacts.isNotEmpty)
                    pw.Text(contacts.join(' | '), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, height: 1),
        if (documentTitle != null && documentTitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            documentTitle.trim(),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );
  }
}
