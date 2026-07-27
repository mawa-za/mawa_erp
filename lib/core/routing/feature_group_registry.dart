import 'app_routes.dart';

class FeatureGroupDefinition {
  final String id;
  final String title;
  final String description;
  final String routePath;
  final String sectionCode;
  final String iconKey;
  final int displayOrder;
  final List<String> childWorkcenterIds;
  final List<String> aliases;

  const FeatureGroupDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.routePath,
    required this.sectionCode,
    required this.iconKey,
    required this.displayOrder,
    required this.childWorkcenterIds,
    this.aliases = const [],
  });

  bool matches(String workcenterId, [String? description]) {
    final candidates = <String>{
      FeatureGroupRegistry.normalize(workcenterId),
      if (description != null && description.trim().isNotEmpty)
        FeatureGroupRegistry.normalize(description),
    };
    final accepted = <String>{
      ...childWorkcenterIds.map(FeatureGroupRegistry.normalize),
      ...aliases.map(FeatureGroupRegistry.normalize),
      FeatureGroupRegistry.normalize(id),
    };
    return candidates.any(accepted.contains);
  }
}

/// Cross-industry fallback catalogue.
///
/// Tenant industry profiles supplied by `/tenant-experience` take precedence.
/// This registry remains available for tenants that have not yet run the
/// industry-profile migration and for legacy deep links.
class FeatureGroupRegistry {
  static const List<FeatureGroupDefinition> groups = [
    FeatureGroupDefinition(
      id: 'membership-cover',
      title: 'Membership & Cover',
      description:
          'Enrol members, manage plans and dependants, collect premiums, assess cover and process membership claims.',
      routePath: '/feature-groups/membership-cover',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'membership',
      displayOrder: 10,
      childWorkcenterIds: [
        'member', 'members', 'membership', 'memberships',
        'membership-plan', 'membership-plans', 'membership-claim',
        'membership-claims', 'group-society', 'group-societies',
        'cover-underwriting', 'funeral-cover-underwriting',
        'third-party-cover-underwriting',
      ],
      aliases: ['membership-management', 'memberships'],
    ),
    FeatureGroupDefinition(
      id: 'funeral-operations',
      title: 'Funeral Operations',
      description:
          'Coordinate collections, mortuary care, funeral arrangements, claims, invoicing and settlement.',
      routePath: '/feature-groups/funeral-operations',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'funeral',
      displayOrder: 20,
      childWorkcenterIds: [
        'funeral-service-request', 'funeral-package-setup', 'pickup-request',
        'mortuary-inventory', 'corpse-check-in', 'corpse-check-out',
        'funeral-claim', 'funeral-claims', 'funeral-payment',
        'funeral-payments',
      ],
      aliases: ['funeral-management', 'funeral'],
    ),
    FeatureGroupDefinition(
      id: 'tombstone-operations',
      title: 'Tombstone Operations',
      description:
          'Manage tombstone orders from layby and assessment through design, production, installation and after-sales service.',
      routePath: '/feature-groups/tombstone-operations',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'tombstone',
      displayOrder: 30,
      childWorkcenterIds: [
        'tombstone-orders', 'tombstone-laybys',
        'tombstone-site-assessments', 'tombstone-design-approvals',
        'tombstone-production-jobs', 'tombstone-installation-planning',
        'tombstone-installation-calendar', 'tombstone-installation-teams',
        'tombstone-rework-jobs', 'tombstone-reports',
      ],
      aliases: ['tombstone-management', 'tombstones'],
    ),
    FeatureGroupDefinition(
      id: 'legal-practice',
      title: 'Legal Practice',
      description:
          'Manage clients, matters, parties, documents, court dates, activities, time, billing and disbursements.',
      routePath: '/feature-groups/legal-practice',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'legal',
      displayOrder: 40,
      childWorkcenterIds: [
        'legal-case', 'legal-cases', 'case', 'cases', 'case-management',
        'legal-documents', 'legal-time', 'legal-billing', 'trust-accounting',
      ],
      aliases: ['legal-management', 'legal-cases'],
    ),
    FeatureGroupDefinition(
      id: 'clients-relationships',
      title: 'Clients & Relationships',
      description:
          'Maintain clients, contacts, organisations and professional relationships.',
      routePath: '/feature-groups/clients-relationships',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'clients',
      displayOrder: 50,
      childWorkcenterIds: ['client', 'clients', 'business-partner', 'partner'],
      aliases: ['client-management'],
    ),
    FeatureGroupDefinition(
      id: 'sales-customers',
      title: 'Sales & Customers',
      description:
          'Manage customers, quotations and sales orders from enquiry through fulfilment.',
      routePath: '/feature-groups/sales-customers',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'sales',
      displayOrder: 60,
      childWorkcenterIds: [
        'customer', 'customers', 'quotation', 'quotations',
        'sales-order', 'sales-orders', 'prospect', 'prospects',
      ],
      aliases: ['sales-management', 'customer-management'],
    ),
    FeatureGroupDefinition(
      id: 'procurement-suppliers',
      title: 'Procurement & Suppliers',
      description:
          'Onboard suppliers and manage purchasing from requisition through supplier invoicing.',
      routePath: '/feature-groups/procurement-suppliers',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'procurement',
      displayOrder: 10,
      childWorkcenterIds: [
        'supplier', 'suppliers', 'purchase-requisition',
        'purchase-order', 'purchase-orders', 'supplier-invoice',
        'supplier-invoices',
      ],
      aliases: ['procurement-management', 'procurement', 'purchasing'],
    ),
    FeatureGroupDefinition(
      id: 'products-inventory',
      title: 'Products & Inventory',
      description:
          'Maintain products and services while controlling receiving, putaway, stock movement and warehouse availability.',
      routePath: '/feature-groups/products-inventory',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'inventory',
      displayOrder: 20,
      childWorkcenterIds: [
        'product', 'products', 'inventory', 'stock', 'goods-receipt',
        'goods-receipts', 'putaway', 'putaways', 'stock-on-hand',
        'stock-movement', 'stock-movements', 'inventory-audit',
        'inventory-setup', 'warehouse', 'storage-location',
      ],
      aliases: ['inventory-management', 'stock-management'],
    ),
    FeatureGroupDefinition(
      id: 'finance-payments',
      title: 'Finance & Payments',
      description:
          'Manage invoicing, receipts, outgoing payments, cashier reconciliation, deposits and payroll processing.',
      routePath: '/feature-groups/finance-payments',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'finance',
      displayOrder: 30,
      childWorkcenterIds: [
        'invoice', 'invoices', 'receipt', 'receipts', 'payment-request',
        'payment-requests', 'cashup', 'cashups', 'deposit', 'deposits',
        'payroll-batch', 'payroll-batches',
      ],
      aliases: ['finance-management', 'finance'],
    ),
    FeatureGroupDefinition(
      id: 'people-workplace',
      title: 'People & Workplace',
      description:
          'Maintain employees, employment actions, leave, organisational assets and workplace records.',
      routePath: '/feature-groups/people-workplace',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'people',
      displayOrder: 40,
      childWorkcenterIds: [
        'employee', 'employees', 'employment', 'employment-management',
        'employee-request', 'employee-requests', 'leave-request',
        'leave-requests', 'leave-management', 'asset', 'assets',
        'asset-register', 'asset-management',
      ],
      aliases: ['partner-management', 'human-resources', 'hr'],
    ),
    FeatureGroupDefinition(
      id: 'work-management',
      title: 'Work Management',
      description:
          'Coordinate approvals, tasks, appointments, calendars, forms and internal communication.',
      routePath: '/feature-groups/work-management',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'work',
      displayOrder: 50,
      childWorkcenterIds: [
        'approvals', 'approval-inbox', 'calendar', 'appointment',
        'appointments', 'employee-engagement', 'internal-communications',
        'company-forms', 'forms', 'tasks', 'diary',
      ],
      aliases: ['scheduling', 'communications', 'engagement'],
    ),
    FeatureGroupDefinition(
      id: 'reports-analytics',
      title: 'Reports & Analytics',
      description:
          'Explore operational, financial and management insights across enabled MAWA business areas.',
      routePath: '/feature-groups/reports-analytics',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'reports',
      displayOrder: 60,
      childWorkcenterIds: ['report', 'reports', 'reporting', 'analytics'],
      aliases: ['reports-and-analytics'],
    ),
    FeatureGroupDefinition(
      id: 'administration-integrations',
      title: 'Administration & Integrations',
      description:
          'Configure access, business rules, workflows, numbering, integrations and background processing.',
      routePath: '/feature-groups/administration-integrations',
      sectionCode: 'SYSTEM_ADMINISTRATION',
      iconKey: 'administration',
      displayOrder: 10,
      childWorkcenterIds: [
        'system-configuration', 'system-configurations', 'api-log',
        'api-logs', 'settings', 'fnb-integration-admin', 'fnb-integration',
        'xero-integration-admin', 'xero-integration', 'xero',
        'signiflow', 'message-queue-admin', 'approval-workflow',
        'number-range-configuration', 'manual-receipt-book',
        'underwriter-configuration', 'processing-schedules',
        'user', 'users', 'role', 'roles', 'company',
      ],
      aliases: ['administration', 'admin', 'system-settings'],
    ),
  ];

  static const Map<String, String> approvalTypeGroups = {
    'CLAIM': 'membership-cover',
    'MEMBERSHIP_TRANSFER': 'membership-cover',
    'MEMBERSHIP_PLAN_CHANGE': 'membership-cover',
    'PAYMENT': 'finance-payments',
    'PAYMENT_REQUEST': 'finance-payments',
    'INVOICE': 'finance-payments',
    'CASHUP': 'finance-payments',
    'JOURNAL': 'finance-payments',
    'CUSTOMER_REFUND': 'finance-payments',
    'PURCHASE_ORDER': 'procurement-suppliers',
    'SUPPLIER_INVOICE': 'procurement-suppliers',
    'SUPPLIER_ONBOARDING': 'procurement-suppliers',
    'SUPPLIER_BANKING_DETAILS': 'procurement-suppliers',
    'LEAVE': 'people-workplace',
  };

  static String approvalGroup(String approvalType) =>
      approvalTypeGroups[normalize(approvalType)] ?? 'work-management';

  static String approvalLabel(String approvalType) => approvalType
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');

  static String normalize(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static FeatureGroupDefinition? groupForWorkcenter(
    String workcenterId, [
    String? description,
  ]) {
    for (final group in groups) {
      if (group.matches(workcenterId, description)) return group;
    }
    return null;
  }

  static FeatureGroupDefinition? groupById(String id) {
    final normalized = normalize(id);
    for (final group in groups) {
      if (normalize(group.id) == normalized ||
          group.aliases.map(normalize).contains(normalized)) {
        return group;
      }
    }
    return null;
  }

  static String canonicalGroupId(String id) => groupById(id)?.id ?? id;

  static String? routeForGroup(String id) => groupById(id)?.routePath;

  static bool isGroupId(String id) => groupById(id) != null;

  static bool isStandaloneCard(String workcenterId, [String? description]) => false;
}
