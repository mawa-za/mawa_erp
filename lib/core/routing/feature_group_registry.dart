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
        'sales-order', 'sales-orders', 'layby', 'laybys', 'prospect', 'prospects',
      ],
      aliases: ['sales-management', 'customer-management'],
    ),
    FeatureGroupDefinition(
      id: 'service-management',
      title: 'Service Management',
      description:
          'Manage customer service demand, contracts, work orders, appointments, services and operational resources.',
      routePath: '/feature-groups/service-management',
      sectionCode: 'YOUR_BUSINESS',
      iconKey: 'service',
      displayOrder: 70,
      childWorkcenterIds: [
        'service-request', 'service-requests',
        'service-order', 'service-orders',
        'service-contract', 'service-contracts',
        'service-appointment', 'service-appointments',
        'service-catalogue', 'service-catalog',
        'service-resource', 'service-resources',
      ],
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
        'payroll-batch', 'payroll-batches',
      ],
      aliases: ['partner-management', 'human-resources', 'hr'],
    ),
    FeatureGroupDefinition(
      id: 'approvals',
      title: 'Approvals',
      description:
          'Review and action every approval request from one central workspace.',
      routePath: '/feature-groups/approvals',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'approvals',
      displayOrder: 45,
      childWorkcenterIds: [
        'approval', 'approvals', 'approval-inbox',
      ],
      aliases: ['approval-management', 'approval-centre', 'approval-center'],
    ),
    FeatureGroupDefinition(
      id: 'work-management',
      title: 'Workplace Collaboration',
      description:
          'Coordinate tasks, appointments, calendars, forms and internal communication.',
      routePath: '/feature-groups/work-management',
      sectionCode: 'BUSINESS_SERVICES',
      iconKey: 'work',
      displayOrder: 50,
      childWorkcenterIds: [
        'calendar', 'appointment', 'appointments', 'employee-engagement',
        'internal-communications', 'company-forms', 'forms', 'tasks', 'diary',
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
      childWorkcenterIds: [
        'management-membership-overview-report',
        'management-memberships-by-plan-report',
        'operational-premium-performance-report',
        'operational-claims-activity-report',
        'operational-customer-money-received-report',
        'operational-cashier-collections-report',
        'operational-deposits-summary-report',
        'operational-undeposited-collections-report',
        'management-collections-deposits-reconciliation-report',
        'management-supplier-payments-summary-report',
        'management-payments-by-service-report',
        'operational-supplier-payment-detail-report',
        'tombstone-reports',
      ],
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

  /// Approval requests are intentionally presented in one operational area.
  /// The originating module remains available from the approval detail, while
  /// the approval cards themselves are never scattered across business groups.
  static String approvalGroup(String approvalType) => 'approvals';

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

  static String presentationTitleForGroup(String id, String configuredTitle) {
    final group = groupById(id);
    if (group != null && normalize(group.id) == normalize('sales-customers')) {
      return group.title;
    }
    return configuredTitle;
  }

  static String presentationLabelForWorkcenter(
    String groupId,
    String workcenterId,
    String configuredLabel,
  ) {
    if (normalize(canonicalGroupId(groupId)) == normalize('sales-customers') &&
        {'CUSTOMER', 'CUSTOMERS'}.contains(normalize(workcenterId)) &&
        normalize(configuredLabel).contains('FAMILIES')) {
      return 'Customers';
    }
    return configuredLabel;
  }

  static String? routeForGroup(String id) => groupById(id)?.routePath;

  static bool isGroupId(String id) => groupById(id) != null;

  /// Returns the single business workspace that owns a cross-module workcenter.
  /// This prevents sales/procurement documents from being repeated under the
  /// inventory workspace when older tenant-experience profiles contain the
  /// same workcenter in more than one group.
  static String? canonicalOwnerForWorkcenter(String workcenterId) {
    final id = normalize(workcenterId);
    if (id.startsWith('APPROVAL_') && id != 'APPROVAL_WORKFLOW') {
      return 'approvals';
    }
    if ({
      'MEMBER', 'MEMBERS', 'MEMBERSHIP', 'MEMBERSHIPS',
      'MEMBERSHIP_PLAN', 'MEMBERSHIP_PLANS', 'MEMBERSHIP_CLAIM',
      'MEMBERSHIP_CLAIMS', 'GROUP_SOCIETY', 'GROUP_SOCIETIES',
      'FUNERAL_COVER_UNDERWRITING', 'COVER_UNDERWRITING',
      'THIRD_PARTY_COVER_UNDERWRITING',
    }.contains(id)) {
      return 'membership-cover';
    }
    if ({'PAYMENT_REQUEST', 'PAYMENT_REQUESTS', 'INVOICE', 'INVOICES',
      'CASHUP', 'CASHUPS', 'DEPOSIT', 'DEPOSITS', 'RECEIPT', 'RECEIPTS'}
        .contains(id)) {
      return 'finance-payments';
    }
    if ({'BUSINESS_PARTNER', 'BUSINESS_PARTNERS'}.contains(id)) {
      return 'sales-customers';
    }
    if ({
      'SERVICE_REQUEST', 'SERVICE_REQUESTS', 'SERVICE_ORDER', 'SERVICE_ORDERS',
      'SERVICE_CONTRACT', 'SERVICE_CONTRACTS',
      'SERVICE_APPOINTMENT', 'SERVICE_APPOINTMENTS',
      'SERVICE_CATALOGUE', 'SERVICE_CATALOG',
      'SERVICE_RESOURCE', 'SERVICE_RESOURCES',
    }.contains(id)) {
      return 'service-management';
    }
    if ({'QUOTATION', 'QUOTATIONS', 'QUOTE', 'QUOTES', 'SALES_ORDER', 'SALES_ORDERS', 'LAYBY', 'LAYBYS'}
        .contains(id)) {
      return 'sales-customers';
    }
    if ({'PURCHASE_ORDER', 'PURCHASE_ORDERS'}.contains(id)) {
      return 'procurement-suppliers';
    }
    if (id.contains('PAYROLL') || id.contains('EMPLOYEE') ||
        id.contains('EMPLOYMENT') || id.contains('LEAVE') ||
        id.contains('ASSET')) {
      return 'people-workplace';
    }
    if (id.contains('REPORT')) return 'reports-analytics';
    if ({
      'PRODUCT',
      'PRODUCTS',
      'GOODS_RECEIPT',
      'GOODS_RECEIPTS',
      'PUTAWAY',
      'PUTAWAYS',
      'STOCK_ON_HAND',
      'STOCK',
      'STOCK_MOVEMENT',
      'STOCK_MOVEMENTS',
      'INVENTORY_MOVEMENT',
      'INVENTORY_MOVEMENTS',
      'INVENTORY_AUDIT',
      'STOCK_AUDIT',
      'INVENTORY_SETUP',
      'WAREHOUSE',
      'STORAGE_LOCATION',
    }.contains(id)) {
      return 'products-inventory';
    }
    return null;
  }

  /// Single grouping source used by Role Maintenance and navigation. Groups
  /// are presentation-only and are never permissions themselves.
  static FeatureGroupDefinition? configurationGroupForWorkcenter(
      String workcenterId, [String? description]) {
    final owner = canonicalOwnerForWorkcenter(workcenterId);
    if (owner != null) return groupById(owner);
    final direct = groupForWorkcenter(workcenterId, description);
    if (direct != null) return direct;
    final id = normalize('$workcenterId ${description ?? ''}');
    if (id.contains('APPROVAL') && !id.contains('WORKFLOW')) return groupById('approvals');
    if (id.contains('INVOICE') || id.contains('PAYMENT') || id.contains('CASHUP') ||
        id.contains('RECEIPT') || id.contains('PREMIUM')) return groupById('finance-payments');
    if (id.contains('WAREHOUSE') || id.contains('STOCK') || id.contains('PRODUCT') ||
        id.contains('PUTAWAY') || id.contains('GOODS_RECEIPT')) return groupById('products-inventory');
    if (id.contains('SUPPLIER') || id.contains('PURCHASE')) return groupById('procurement-suppliers');
    if (id.contains('MEMBER') || id.contains('COVER') || id.contains('GROUP_SOCIETY')) return groupById('membership-cover');
    if (id.contains('FUNERAL') || id.contains('MORTUARY') || id.contains('CORPSE') || id.contains('PICKUP')) return groupById('funeral-operations');
    if (id.contains('CUSTOMER') || id.contains('PROSPECT') || id.contains('QUOTATION') ||
        id.contains('SALES') || id.contains('LAYBY') || id.contains('COMPLAINT') ||
        id.contains('INTERACTION')) return groupById('sales-customers');
    if (id.contains('PARTNER') || id.contains('CLIENT')) return groupById('clients-relationships');
    if (id.contains('CALENDAR') || id.contains('APPOINTMENT') || id.contains('FORM') ||
        id.contains('ENGAGEMENT') || id.contains('TIME_TRACKER')) return groupById('work-management');
    if (id.contains('CONFIG') || id.contains('ADMIN') || id.contains('API_LOG') ||
        id.contains('COMPANY')) return groupById('administration-integrations');
    return null;
  }

  static bool belongsToCanonicalGroup(String workcenterId, String groupId) {
    final owner = canonicalOwnerForWorkcenter(workcenterId);
    return owner == null || normalize(owner) == normalize(canonicalGroupId(groupId));
  }

  /// Legacy umbrella workcenters created a second nested Inventory Management
  /// landing page alongside the granular Products & Inventory cards. Keep the
  /// routes for backwards-compatible deep links, but do not surface them as
  /// navigation cards.
  static bool isLegacyInventoryUmbrella(String workcenterId) {
    return {
      'INVENTORY',
      'INVENTORY_MANAGEMENT',
      'STOCK_MANAGEMENT',
    }.contains(normalize(workcenterId));
  }

  static bool isStandaloneCard(String workcenterId, [String? description]) => false;
}
