import 'app_routes.dart';

class FeatureGroupDefinition {
  final String id;
  final String title;
  final String routePath;
  final List<String> childWorkcenterIds;
  final List<String> aliases;

  const FeatureGroupDefinition({
    required this.id,
    required this.title,
    required this.routePath,
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
      ...normalizeList(childWorkcenterIds),
      ...normalizeList(aliases),
      normalize(id),
    };
    return candidates.any(accepted.contains);
  }

  static Set<String> normalizeList(List<String> values) =>
      values.map(normalize).toSet();

  static String normalize(String value) =>
      value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
}

class FeatureGroupRegistry {
  static const Set<String> standaloneCardIds = {
    'EMPLOYMENT',
    'EMPLOYMENT_MANAGEMENT',
    'LEAVE_MANAGEMENT',
    'ASSET',
    'ASSETS',
    'ASSET_REGISTER',
    'ASSET_MANAGEMENT',
  };

  static const List<FeatureGroupDefinition> groups = [
    FeatureGroupDefinition(
      id: 'membership-management',
      title: 'Membership Management',
      routePath: '/feature-groups/membership-management',
      childWorkcenterIds: [
        'membership',
        'memberships',
        'member',
        'members',
        'membership-plan',
        'membership-plans',
        'membership-claim',
        'membership-claims',
        'group-society',
        'group-societies',
      ],
      aliases: ['memberships', 'membership-management'],
    ),
    FeatureGroupDefinition(
      id: 'tombstone-management',
      title: 'Tombstone Management',
      routePath: '/feature-groups/tombstone-management',
      childWorkcenterIds: [
        'tombstone-orders',
        'tombstone-laybys',
        'tombstone-site-assessments',
        'tombstone-design-approvals',
        'tombstone-production-jobs',
        'tombstone-installation-planning',
        'tombstone-installation-calendar',
        'tombstone-installation-teams',
        'tombstone-rework-jobs',
        'tombstone-reports',
      ],
      aliases: ['tombstones', 'tombstone-management'],
    ),
    FeatureGroupDefinition(
      id: 'funeral-management',
      title: 'Funeral Management',
      routePath: '/feature-groups/funeral-management',
      childWorkcenterIds: [
        'funeral-service-request',
        'funeral-package-setup',
        'pickup-request',
        'mortuary-inventory',
        'corpse-check-in',
        'corpse-check-out',
        'funeral-claim',
        'funeral-claims',
        'funeral-payment',
        'funeral-payments',
      ],
      aliases: ['funeral', 'funeral-management'],
    ),
    FeatureGroupDefinition(
      id: 'finance-management',
      title: 'Finance Management',
      routePath: '/feature-groups/finance-management',
      childWorkcenterIds: [
        'invoice',
        'invoices',
        'payment-request',
        'payment-requests',
        'cashup',
        'cashups',
        'approvals',
      ],
      aliases: ['finance', 'finance-management'],
    ),
    FeatureGroupDefinition(
      id: 'sales-management',
      title: 'Sales Management',
      routePath: '/feature-groups/sales-management',
      childWorkcenterIds: [
        'customer',
        'customers',
        'client',
        'clients',
        'quotation',
        'quotations',
        'sales-order',
        'sales-orders',
      ],
      aliases: ['sales', 'customer-management'],
    ),
    FeatureGroupDefinition(
      id: 'procurement-management',
      title: 'Procurement Management',
      routePath: '/feature-groups/procurement-management',
      childWorkcenterIds: [
        'supplier',
        'suppliers',
        'purchase-order',
        'purchase-orders',
        'goods-receipt',
        'goods-receipts',
        'supplier-invoice',
        'supplier-invoices',
      ],
      aliases: ['procurement', 'purchasing'],
    ),
    FeatureGroupDefinition(
      id: 'inventory',
      title: 'Inventory Management',
      routePath: '/feature-groups/inventory',
      childWorkcenterIds: [
        'inventory',
        'stock',
        'putaway',
        'putaways',
        'stock-on-hand',
        'stock-movement',
        'stock-movements',
        'inventory-audit',
        'inventory-setup',
        'products',
        'product',
        'asset-register',
        'assets',
      ],
      aliases: ['inventory-management', 'stock-management'],
    ),
    FeatureGroupDefinition(
      id: 'scheduling',
      title: 'Calendar & Appointments',
      routePath: '/feature-groups/scheduling',
      childWorkcenterIds: [
        'calendar',
        'appointment',
      ],
      aliases: ['appointments', 'appointment-booking', 'booking', 'bookings'],
    ),
    FeatureGroupDefinition(
      id: 'partner-management',
      title: 'Partner Management',
      routePath: '/feature-groups/partner-management',
      childWorkcenterIds: [
        'employee',
        'employees',
        'employment',
        'employment-management',
        'employee-request',
        'employee-requests',
        'leave-request',
        'leave-requests',
        'leave-management',
        'business-partner',
        'partner',
      ],
      aliases: ['partners', 'business-partners'],
    ),
    FeatureGroupDefinition(
      id: 'administration',
      title: 'Administration',
      routePath: '/feature-groups/administration',
      childWorkcenterIds: [
        'system-configuration',
        'system-configurations',
        'api-log',
        'api-logs',
        'settings',
        'fnb-integration-admin',
        'fnb-integration',
        'xero-integration-admin',
        'xero-integration',
        'xero',
        'message-queue-admin',
      ],
      aliases: ['admin', 'system-settings'],
    ),
    FeatureGroupDefinition(
      id: 'legal-management',
      title: 'Legal Management',
      routePath: AppRoutes.cases,
      childWorkcenterIds: [
        'legal-case',
        'case',
      ],
      aliases: ['legal-cases', 'case-management'],
    ),
    FeatureGroupDefinition(
      id: 'communications',
      title: 'Communications',
      routePath: AppRoutes.internalCommunications,
      childWorkcenterIds: [
        'employee-engagement',
        'internal-communications',
      ],
      aliases: ['engagement'],
    ),
  ];

  static const Map<String, String> approvalTypeGroups = {
    'CLAIM': 'membership-management',
    'PAYMENT': 'finance-management',
    'PAYMENT_REQUEST': 'finance-management',
    'INVOICE': 'finance-management',
    'CASHUP': 'finance-management',
    'JOURNAL': 'finance-management',
    'CUSTOMER_REFUND': 'finance-management',
    'PURCHASE_ORDER': 'procurement-management',
    'SUPPLIER_INVOICE': 'procurement-management',
    'SUPPLIER_ONBOARDING': 'procurement-management',
    'SUPPLIER_BANKING_DETAILS': 'procurement-management',
    'LEAVE': 'partner-management',
  };

  static String approvalGroup(String approvalType) =>
      approvalTypeGroups[normalize(approvalType)] ?? 'finance-management';

  static String approvalLabel(String approvalType) => approvalType
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');

  static String normalize(String value) =>
      value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');

  static bool isStandaloneCard(String workcenterId, [String? description]) {
    if (standaloneCardIds.contains(normalize(workcenterId))) return true;
    return description != null &&
        description.trim().isNotEmpty &&
        standaloneCardIds.contains(normalize(description));
  }

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

  static String? routeForGroup(String id) => groupById(id)?.routePath;

  static bool isGroupId(String id) => groupById(id) != null;
}
