import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_detail.dart';
import '../../partners/models/partner.dart';
import '../../../core/services/setting_service.dart';
import '../../../core/api_client.dart';

class InvoicePdfService {
  Future<Uint8List> generatePdf(InvoiceDetail invoice, Partner? partner) async {
    final doc = pw.Document();

    // Load company info
    List<dynamic> settings = [];
    try {
      settings = await SettingService().getSettings();
    } catch (e) {
      print('Error loading settings for PDF: $e');
    }

    final companyName = _getSetting(settings, 'NAME', 'mawa');
    final companyAddress1 = _getSetting(settings, 'ADDRESS-LINE-1', '');
    final companyAddress2 = _getSetting(settings, 'ADDRESS-LINE-2', '');
    final companyCity = _getSetting(settings, 'CITY', '');
    final companyPostalCode = _getSetting(settings, 'POSTAL-CODE', '');
    final companyEmail = _getSetting(settings, 'EMAIL', '');
    final companyPhone = _getSetting(settings, 'PHONE', '');
    final companyVat = _getSetting(settings, 'VAT-NUMBER', '');
    final companyReg = _getSetting(settings, 'REGISTRATION-NUMBER', '');

    // Load Logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoBase64 = await _loadLogoBase64();
      if (logoBase64 != null) {
        logoImage = pw.MemoryImage(base64Decode(logoBase64));
      }
    } catch (e) {
      print('Error loading logo for PDF: $e');
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildHeader(companyName, companyAddress1, companyAddress2, companyCity, companyPostalCode, companyEmail, companyPhone, companyVat, companyReg, logoImage),
          pw.SizedBox(height: 20),
          _buildInvoiceInfo(invoice),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(invoice, partner),
          pw.SizedBox(height: 20),
          _buildItemsTable(invoice),
          pw.SizedBox(height: 20),
          _buildTotals(invoice),
          if (invoice.payments.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildPaymentHistory(invoice),
          ],
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10, color: PdfColors.grey700)),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> printInvoice(InvoiceDetail invoice, Partner? partner) async {
    final pdfBytes = await generatePdf(invoice, partner);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.number}.pdf',
    );
  }

  String _getSetting(List<dynamic> settings, String attribute, String defaultValue) {
    try {
      return settings.firstWhere((s) => s.type == 'TENANT' && s.attribute == attribute).value;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<String?> _loadLogoBase64() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant');
      if (tenantId == null) return null;

      final response = await ApiClient().get('/attachment?objectId=$tenantId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final logoAttachment = data.firstWhere(
          (a) => a['documentType']?['id'] == 'LOGO',
          orElse: () => null,
        );

        if (logoAttachment != null) {
          final res = await ApiClient().get('/attachment/${logoAttachment['id']}');
          if (res.statusCode == 200) {
            return res.body.replaceAll('"', '');
          }
        }
      }
    } catch (e) {
      print('Error fetching logo: $e');
    }
    return null;
  }

  pw.Widget _buildHeader(String name, String a1, String a2, String city, String pc, String email, String phone, String vat, String reg, pw.MemoryImage? logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(height: 60, width: 60, child: pw.Image(logo))
            else
              pw.Text(name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Text(a1, style: const pw.TextStyle(fontSize: 9)),
            if (a2.isNotEmpty) pw.Text(a2, style: const pw.TextStyle(fontSize: 9)),
            pw.Text('$city, $pc', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 9)),
            if (reg.isNotEmpty) pw.Text('Reg No: $reg', style: const pw.TextStyle(fontSize: 9)),
            if (vat.isNotEmpty) pw.Text('VAT No: $vat', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('INVOICE', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceInfo(InvoiceDetail invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _infoRow('Invoice Number:', invoice.number),
            _infoRow('Invoice Date:', DateFormat('yyyy-MM-dd').format(invoice.invoiceDate)),
            if (invoice.dueDate != null) _infoRow('Due Date:', DateFormat('yyyy-MM-dd').format(invoice.dueDate!)),
            if (invoice.reference.isNotEmpty) _infoRow('Reference:', invoice.reference),
            _infoRow('Status:', invoice.status.toUpperCase()),
          ],
        ),
      ],
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerInfo(InvoiceDetail invoice, Partner? partner) {
    final address = partner?.addresses.isNotEmpty == true ? partner!.addresses.first : null;
    return pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(partner?.fullName ?? invoice.customerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          if (address != null) ...[
            pw.Text(address.line1, style: const pw.TextStyle(fontSize: 9)),
            if (address.line2.isNotEmpty) pw.Text(address.line2, style: const pw.TextStyle(fontSize: 9)),
            pw.Text('${address.city}, ${address.postalCode}', style: const pw.TextStyle(fontSize: 9)),
          ],
          if (partner?.email != null && partner!.email.isNotEmpty) pw.Text(partner.email, style: const pw.TextStyle(fontSize: 9)),
          if (partner?.phone != null && partner!.phone.isNotEmpty) pw.Text(partner.phone, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(InvoiceDetail invoice) {
    final headers = ['#', 'Product', 'Description', 'Qty', 'Unit Price', 'Total'];
    final data = invoice.items.asMap().entries.map((entry) {
      final i = entry.value;
      return [
        '${entry.key + 1}',
        i.productCode,
        i.productName,
        i.quantity.toStringAsFixed(0),
        'R ${i.unitPrice.toStringAsFixed(2)}',
        'R ${i.lineTotal.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(4),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(70),
      },
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildTotals(InvoiceDetail invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 180,
          child: pw.Column(
            children: [
              _totalRow('Subtotal', invoice.subtotalAmount),
              _totalRow('VAT', invoice.vatAmount),
              if (invoice.discountAmount > 0) _totalRow('Discount', -invoice.discountAmount),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R ${invoice.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (invoice.paidAmount > 0) ...[
                pw.SizedBox(height: 2),
                _totalRow('Paid', invoice.paidAmount),
                pw.Divider(color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance Due', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('R ${invoice.balanceAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('R ${value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentHistory(InvoiceDetail invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PAYMENT HISTORY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Method', 'Reference', 'Amount'],
          data: invoice.payments.map((p) => [
            DateFormat('yyyy-MM-dd').format(p.paymentDate),
            p.paymentMethod,
            p.referenceNo,
            'R ${p.amount.toStringAsFixed(2)}',
          ]).toList(),
          border: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            3: pw.Alignment.centerRight,
          },
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by mawa', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }
}
