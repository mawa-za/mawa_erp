import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/company_pdf_branding.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../partners/models/partner.dart';
import '../models/dependent.dart';
import '../models/membership_detail.dart';
import '../models/membership_plan.dart' hide DependentType;

/// Printable snapshot of the details already visible on Membership Detail.
/// Does not include financial transactions, claims or internal approval history.
class MembershipDetailsPdfService {
  Future<Uint8List> buildPdf({
    required MembershipDetail membership,
    required Partner holder,
    required MembershipPlan plan,
    required List<Dependent> dependents,
    required Map<String, Partner> dependentPartners,
    CompanyPdfBranding? branding,
    DateTime? generatedAt,
  }) async {
    final company = branding ?? await CompanyPdfBranding.load();
    final generated = AppDateUtils.inSelectedTimeZone(
      (generatedAt ?? DateTime.now()).toUtc(),
    );
    final generatedLabel =
        '${DateFormat('dd MMM yyyy HH:mm').format(generated)} (${AppDateUtils.timeZone})';
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 42),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Membership ${membership.membershipNo} | Generated $generatedLabel',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        build: (_) => [
          company.header(documentTitle: 'MEMBERSHIP DETAILS'),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: PdfColors.grey100,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MEMBERSHIP NUMBER',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(_value(membership.membershipNo),
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STATUS',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text(_value(membership.status).replaceAll('_', ' ').toUpperCase(),
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _section('Membership & Cover', [
            _row('Plan', '${_value(plan.name)} (${_value(plan.planCode)})'),
            _row('Monthly Premium',
                '${_value(plan.currency, fallback: 'ZAR')} ${NumberFormat('#,##0.00').format(membership.premium)}'),
            _row('Plan Waiting Period', '${plan.waitingPeriodMonths} months'),
            _row('Plan Dependant Limit', plan.maxDependents > 0 ? '${plan.maxDependents}' : 'Unlimited'),
            _row('Join Date', _date(membership.joinDate)),
            _row('Start Date', _date(membership.startDate)),
            _row('Effective / Eligible From', _date(membership.effectiveDate)),
            _row('End Date', _date(membership.endDate)),
            _row('Premium Paid Up To', _period(membership.paidUpToPeriod)),
            _row('Member Status', _value(membership.memberStatus)),
            if (_hasValue(membership.memberDeceasedDate))
              _row('Member Date of Death', _date(membership.memberDeceasedDate)),
          ]),
          _section('Main Member / Policy Holder', [
            _row('Full Name', _value(holder.fullName)),
            _row('Member Number', _value(holder.number)),
            _row('Identity', _identity(holder.idType, holder.identityNumber)),
            _row('Date of Birth', _date(holder.birthDate)),
            _row('Gender', _value(holder.gender)),
            _row('Contact Number', _value(holder.phone)),
            _row('Email', _value(holder.email)),
          ]),
          pw.SizedBox(height: 2),
          pw.Text('DEPENDANTS (${dependents.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Dependants linked to this membership are listed with their recorded status, including deceased dependants.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          if (dependents.isEmpty)
            pw.Text('No dependants are recorded on this membership.',
                style: const pw.TextStyle(fontSize: 10))
          else
            ...dependents.asMap().entries.map((entry) {
              final dependent = entry.value;
              final partner = dependentPartners[dependent.dependentPartnerId];
              final partnerId = partner?.identityNumber.trim() ?? '';
              final identityNumber = partnerId.isNotEmpty
                  ? partnerId
                  : (dependent.identity?.number ?? '');
              final identityType = partnerId.isNotEmpty
                  ? partner?.idType
                  : dependent.identity?.type.description;
              final name = partner?.fullName.trim().isNotEmpty == true
                  ? partner!.fullName
                  : dependent.fullName;
              final partnerNumber = partner?.number.trim().isNotEmpty == true
                  ? partner!.number
                  : dependent.number;
              final dob = partner?.birthDate ?? dependent.birthDate;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      color: PdfColors.grey100,
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text('${entry.key + 1}. ${_value(name)}',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Text(_value(dependent.membershipStatus).toUpperCase(),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: pw.Column(
                        children: [
                          _row('Relationship',
                              DependentType.fromString(dependent.dependentType).label),
                          _row('Dependant Number', _value(partnerNumber)),
                          _row('Identity', _identity(identityType, identityNumber)),
                          _row('Date of Birth', _date(dob)),
                          _row('Date Added', _date(dependent.createdAt)),
                          _row('Effective From', _date(dependent.effectiveFrom)),
                          if (_hasValue(dependent.effectiveTo))
                            _row('Effective To', _date(dependent.effectiveTo)),
                          if (_hasValue(dependent.deceasedDate))
                            _row('Date of Death', _date(dependent.deceasedDate)),
                          if (_hasValue(dependent.statusReason))
                            _row('Status Reason', _value(dependent.statusReason)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 12),
          pw.Text(
            'This document reflects membership records at the time of printing. '
            'Claim eligibility and benefits remain subject to the applicable policy rules and approvals.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _section(String title, List<pw.Widget> content) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(children: content),
            ),
          ],
        ),
      );

  pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 142,
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  String _value(String? value, {String fallback = 'N/A'}) =>
      _hasValue(value) ? value!.trim() : fallback;

  String _date(String? value) => AppDateUtils.displayDate(value);

  String _identity(String? type, String? number) =>
      _hasValue(number) ? '${_value(type, fallback: 'ID')}: ${number!.trim()}' : 'N/A';

  String _period(String? period) {
    if (!_hasValue(period)) return 'N/A';
    final normalized = period!.trim().replaceAll('-', '');
    if (RegExp(r'^\d{6}$').hasMatch(normalized)) {
      final year = int.parse(normalized.substring(0, 4));
      final month = int.parse(normalized.substring(4, 6));
      if (month >= 1 && month <= 12) return DateFormat('MMM yyyy').format(DateTime(year, month));
    }
    return period;
  }
}
