import 'feature_group_registry.dart';

/// Provides user-facing purpose text for group and function cards.
/// Workcenter identifiers remain routing concerns and are deliberately not
/// exposed in the UI.
class WorkcenterCardDescriptions {
  static const Map<String, String> _groupDescriptions = {
    'APPROVALS':
        'Review every approval type from one central workspace while keeping the originating business record linked.',
    'MEMBERSHIP_MANAGEMENT':
        'Run the complete member lifecycle, from plan enrolment and premiums to dependants, claims and group societies.',
    'TOMBSTONE_MANAGEMENT':
        'Coordinate tombstone sales, laybys, design approval, production, installation and after-sales rework.',
    'FUNERAL_MANAGEMENT':
        'Coordinate every funeral service stage, from collection and mortuary care to arrangements, claims, invoicing and payment.',
    'FINANCE_MANAGEMENT':
        'Control invoicing, payment requests, cashier reconciliation and financial approvals from one workcenter.',
    'SALES_MANAGEMENT':
        'Turn customer enquiries into quotations, confirmed sales orders and fulfilled commitments.',
    'PROCUREMENT_MANAGEMENT':
        'Govern supplier onboarding and purchasing from approved orders through goods receipt and supplier invoicing.',
    'INVENTORY':
        'Maintain product master data and control stock availability, receiving, putaway, movement and audit history.',
    'SCHEDULING':
        'Plan appointments, bookings and operational commitments in a shared business calendar.',
    'PARTNER_MANAGEMENT':
        'Maintain trusted partner and workforce records, including employment actions and employee leave.',
    'ADMINISTRATION':
        'Control MAWA configuration, access roles, integrations, processing schedules and operational settings.',
    'LEGAL_MANAGEMENT':
        'Manage legal matters with structured case activity, parties, documents, time, billing and disbursements.',
    'COMMUNICATIONS':
        'Publish internal communication and coordinate employee engagement across the organisation.',
  };

  static String forGroup(String id, String title) {
    return _groupDescriptions[FeatureGroupRegistry.normalize(id)] ??
        'Open $title to manage its related business processes and records.';
  }

  static String forWorkcenter(String id, String title) {
    final identity = FeatureGroupRegistry.normalize('$id $title');

    if (identity.contains('MEMBERSHIP_CLAIM')) {
      return 'Search, review and track membership claims through approval and settlement.';
    }
    if (identity.contains('MEMBERSHIP_PLAN')) {
      return 'Configure membership plans, premiums, cover rules and claim benefits.';
    }
    if (identity.contains('GROUP') || identity.contains('SOCIET')) {
      return 'Manage group societies, participating members and group balances.';
    }
    if (identity == 'MEMBER' || identity == 'MEMBERS' ||
        identity.endsWith('_MEMBER') || identity.endsWith('_MEMBERS')) {
      return 'Find and maintain people registered as members.';
    }
    if (identity.contains('MEMBERSHIP')) {
      return 'Manage active memberships, dependants, payments and membership changes.';
    }
    if (identity.contains('SUPPLIER') && !identity.contains('INVOICE')) {
      return 'Onboard suppliers for approval and maintain approved supplier records.';
    }
    if (identity.contains('SUPPLIER') && identity.contains('INVOICE')) {
      return 'Capture and process supplier invoices for payment.';
    }
    if (identity.contains('PURCHASE') && identity.contains('ORDER')) {
      return 'Create and track purchase orders issued to approved suppliers.';
    }
    if (identity.contains('GOODS') && identity.contains('RECEIPT')) {
      return 'Record goods received against purchase orders and update stock.';
    }
    if (identity.contains('QUOT')) {
      return 'Prepare and manage customer quotations before sales orders are created.';
    }
    if (identity.contains('SALES') && identity.contains('ORDER')) {
      return 'Create and track customer sales orders through fulfilment.';
    }
    if (identity.contains('CUSTOMER') || identity.contains('CLIENT')) {
      return 'Find, onboard and maintain customer or client records.';
    }
    if (identity.contains('PRODUCT')) {
      return 'Maintain products, pricing, categories, barcodes and stock attributes.';
    }
    if (identity.contains('STOCK') && identity.contains('HAND')) {
      return 'View current stock quantities and availability by location.';
    }
    if (identity.contains('PUTAWAY')) {
      return 'Move received stock into its assigned storage locations.';
    }
    if (identity.contains('MOVEMENT')) {
      return 'Review stock movements and inventory adjustments.';
    }
    if (identity.contains('INVENTORY') && identity.contains('AUDIT')) {
      return 'Review inventory transactions and stock-control audit history.';
    }
    if (identity.contains('ASSET')) {
      return 'Register, assign, track and maintain organisational assets.';
    }
    if (identity.contains('PICKUP')) {
      return 'Create, assign and complete deceased collection requests.';
    }
    if (identity.contains('MORTUARY') || identity.contains('CORPSE')) {
      return 'Manage mortuary check-in, inventory and release of deceased persons.';
    }
    if (identity.contains('FUNERAL') && identity.contains('PACKAGE')) {
      return 'Configure funeral packages and the products included in each package.';
    }
    if (identity.contains('FUNERAL') &&
        (identity.contains('SERVICE') || identity.contains('ARRANGEMENT') || identity.contains('REQUEST'))) {
      return 'Create and manage funeral arrangements from membership check to invoicing.';
    }
    if (identity.contains('FUNERAL') && identity.contains('CLAIM')) {
      return 'Review claims linked to funeral arrangements and their approval status.';
    }
    if (identity.contains('FUNERAL') && identity.contains('PAYMENT')) {
      return 'Track funeral invoices, cover allocations, shortfalls and payments.';
    }
    if (identity.contains('PAYMENT') && identity.contains('REQUEST')) {
      return 'Create permitted manual requests and track system-generated payment requests.';
    }
    if (identity.contains('CASHUP')) {
      return 'Reconcile cashier collections, manual receipts, deposits and approvals.';
    }
    if (identity.contains('INVOICE')) {
      return 'Create, review and track invoices and their payment status.';
    }
    if (identity.contains('APPROVAL')) {
      return 'Review submitted requests and complete the configured approval workflow.';
    }
    if (identity.contains('EMPLOYMENT')) {
      return 'Maintain employment records and process hire, rehire and termination actions.';
    }
    if (identity.contains('LEAVE')) {
      return 'Capture, review and track employee leave requests.';
    }
    if (identity.contains('EMPLOYEE')) {
      return 'Find and maintain employee and workforce records.';
    }
    if (identity.contains('APPOINT') || identity.contains('CALENDAR') || identity.contains('BOOKING')) {
      return 'Schedule and manage appointments, bookings and calendar availability.';
    }
    if (identity.contains('TOMBSTONE')) {
      return 'Manage the selected stage of the tombstone order and installation lifecycle.';
    }
    if (identity.contains('SETTING') || identity.contains('CONFIG')) {
      return 'Maintain configuration that controls how this part of the system operates.';
    }
    if (identity.contains('API') || identity.contains('INTEGRATION')) {
      return 'Configure integrations and review external service activity.';
    }
    if (identity.contains('DEVICE') && identity.contains('SYNC')) {
      return 'Review MawaPay submissions, correct validation errors and safely reprocess failed transactions.';
    }
    if (identity.contains('QUEUE') || identity.contains('SCHEDUL')) {
      return 'Control scheduled processing and monitor queued work.';
    }
    if (identity.contains('MANAGEMENT_MEMBERSHIP_OVERVIEW_REPORT')) {
      return 'Review current membership population and status across the organisation.';
    }
    if (identity.contains('MANAGEMENT_MEMBERSHIPS_BY_PLAN_REPORT')) {
      return 'Compare membership volumes and active memberships across configured plans.';
    }
    if (identity.contains('OPERATIONAL_PREMIUM_PERFORMANCE_REPORT')) {
      return 'Monitor paid, unpaid and partially paid premiums by reporting period.';
    }
    if (identity.contains('OPERATIONAL_CLAIMS_ACTIVITY_REPORT')) {
      return 'Track monthly claim volumes and the mix of claim types being processed.';
    }
    if (identity.contains('REPORT')) {
      return 'View operational and management information for this business area.';
    }

    return 'Open $title to view and manage the related records and activities.';
  }
}
