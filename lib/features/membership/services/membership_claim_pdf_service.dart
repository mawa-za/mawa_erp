import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/membership_claim.dart';
import '../models/membership_detail.dart';
import '../../partners/models/partner.dart';
import '../../../core/pdf/company_pdf_branding.dart';

class MembershipClaimPdfService {
  Future<Uint8List> buildClaimForm({
    required MembershipClaim claim,
    Partner? deceasedPartner,
    Partner? claimantPartner,
    MembershipDetail? membership,
  }) async {
    final doc = pw.Document();
    final branding = await CompanyPdfBranding.load();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          branding.header(documentTitle: 'MEMBERSHIP CLAIM FORM'),
          pw.SizedBox(height: 18),
          pw.Text('Claim No: ${claim.claimNo}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 24),
          _section('Claim Details', [
            _row('Claim Type', claim.claimType),
            _row('Status', claim.status),
            _row('Date of Death', claim.dateOfDeath),
            _row('Coverage Plan', claim.coveragePlanName),
            _row('Coverage Effective Date', claim.coverageEventDate),
            _row('Claim Date', claim.claimDate),
            _row('Death Certificate No', claim.deathCertificateNo ?? ''),
            _row('Cause of Death', claim.causeOfDeath ?? ''),
            _row('Claim Amount', _money(claim.claimAmountCents)),
          ]),
          _section('Membership', [
            _row('Membership No', membership?.membershipNo ?? claim.membershipId),
            _row('Membership Status', membership?.status ?? ''),
            _row('Premium', membership == null ? '' : _money(membership.premiumCents)),
          ]),
          _section('Deceased', [
            _row('Name', deceasedPartner?.fullName ?? claim.deceasedPartnerId),
            _row('Identity Number', deceasedPartner?.identityNumber ?? ''),
            _row('Deceased Type', claim.deceasedType),
          ]),
          _section('Claimant', [
            _row('Name', claimantPartner?.fullName ?? claim.claimantPartnerId),
            _row('Identity Number', claimantPartner?.identityNumber ?? ''),
            _row('Contact Number', claimantPartner?.phone ?? ''),
            _row('Email', claimantPartner?.email ?? ''),
          ]),
          if (claim.notes != null && claim.notes!.isNotEmpty)
            _section('Notes', [_row('Notes', claim.notes!)]),
          pw.SizedBox(height: 32),
          pw.Row(
            children: [
              pw.Expanded(child: _signatureBox('Claimant Signature')),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _signatureBox('Mawa Representative Signature')),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(children: children),
          ),
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 150, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 48, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
        pw.SizedBox(height: 6),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 18),
        pw.Container(height: 24, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
        pw.SizedBox(height: 6),
        pw.Text('Date', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  String _money(int cents) => 'R ${(cents / 100).toStringAsFixed(2)}';
}
