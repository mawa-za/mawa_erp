import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/pdf/company_pdf_branding.dart';
import 'package:mawa_erp/features/membership/models/dependent.dart';
import 'package:mawa_erp/features/membership/models/membership_detail.dart';
import 'package:mawa_erp/features/membership/models/membership_plan.dart';
import 'package:mawa_erp/features/membership/services/membership_details_pdf_service.dart';
import 'package:mawa_erp/features/partners/models/partner.dart';

void main() {
  const branding = CompanyPdfBranding(
    name: 'Sample Funeral Services',
    registrationNumber: '',
    vatNumber: '',
    fspNumber: '',
    address: '1 Test Road, Johannesburg',
    phone: '',
    email: '',
    website: '',
    logo: null,
  );
  final membership = MembershipDetail(
    id: 'm-1',
    memberId: 'p-1',
    membershipNo: 'MEM-10004',
    planId: 'plan-1',
    premiumCents: 22500,
    joinDate: '2024-03-01',
    startDate: '2024-04-01',
    effectiveDate: '2024-07-01',
    paidUpToPeriod: '202610',
    status: 'LAPSED',
    memberStatus: 'ACTIVE',
    createdBy: 'test',
  );
  final holder = Partner(
    id: 'p-1',
    number: '00001',
    type: 'INDIVIDUAL',
    name1: 'Molefe',
    name2: 'Mpho',
    name3: '',
    identityNumber: '8001015009087',
    status: 'ACTIVE',
  );
  final plan = MembershipPlan(
    id: 'plan-1',
    planCode: 'FAMILY',
    name: 'Family Cover',
    description: '',
    premiumCents: 22500,
    currency: 'ZAR',
    maxDependents: 50,
    active: true,
  );

  test('generates a printable PDF with active, deceased and removed relationships', () async {
    final dependents = <Dependent>[
      Dependent(
        id: 'dep-1', membershipId: 'm-1', dependentPartnerId: 'p-2',
        dependentType: 'SPOUSE', active: true, membershipStatus: 'ACTIVE',
        firstName: 'Lerato', lastName: 'Molefe',
        effectiveFrom: '2024-07-01', createdBy: 'test',
      ),
      Dependent(
        id: 'dep-2', membershipId: 'm-1', dependentPartnerId: 'p-3',
        dependentType: 'PARENT', active: false, membershipStatus: 'DECEASED',
        deceasedDate: '2025-09-13', firstName: 'Kagiso', lastName: 'Molefe',
        createdBy: 'test',
      ),
      Dependent(
        id: 'dep-3', membershipId: 'm-1', dependentPartnerId: 'p-4',
        dependentType: 'CHILD', active: false, membershipStatus: 'REMOVED',
        effectiveTo: '2025-12-31', firstName: 'Neo', lastName: 'Molefe',
        createdBy: 'test',
      ),
    ];
    final pdf = await MembershipDetailsPdfService().buildPdf(
      membership: membership,
      holder: holder,
      plan: plan,
      dependents: dependents,
      dependentPartners: const {},
      branding: branding,
      generatedAt: DateTime.utc(2026, 11, 9, 12),
    );
    expect(pdf.take(5).toList(), [37, 80, 68, 70, 45]); // %PDF-
    expect(pdf.length, greaterThan(2000));
  });

  test('generates a PDF when no dependants are linked', () async {
    final pdf = await MembershipDetailsPdfService().buildPdf(
      membership: membership,
      holder: holder,
      plan: plan,
      dependents: const [],
      dependentPartners: const {},
      branding: branding,
    );
    expect(pdf.take(5).toList(), [37, 80, 68, 70, 45]);
  });

  test('paginates a long list of dependants', () async {
    final dependents = List.generate(35, (index) => Dependent(
      id: 'dep-$index',
      membershipId: 'm-1',
      dependentPartnerId: 'partner-$index',
      dependentType: 'CHILD',
      active: true,
      membershipStatus: 'ACTIVE',
      firstName: 'Child',
      lastName: '$index',
      createdBy: 'test',
    ));
    final pdf = await MembershipDetailsPdfService().buildPdf(
      membership: membership,
      holder: holder,
      plan: plan,
      dependents: dependents,
      dependentPartners: const {},
      branding: branding,
    );
    expect(pdf.length, greaterThan(2000));
  });
}
