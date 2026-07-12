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
        'membership-claim',
        'group-society',
      ],
      aliases: ['memberships', 'membership-management'],
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
        'funeral-claims',
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
      id: 'inventory',
      title: 'Inventory Management',
      routePath: AppRoutes.inventory,
      childWorkcenterIds: [
        'inventory',
        'stock',
        'goods-receipt',
        'putaway',
        'stock-on-hand',
        'stock-movement',
        'inventory-audit',
        'inventory-setup',
        'sales-order',
        'quotation',
        'purchase-order',
      ],
      aliases: ['inventory-management', 'stock-management'],
    ),
    FeatureGroupDefinition(
      id: 'scheduling',
      title: 'Calendar & Appointments',
      routePath: AppRoutes.appointments,
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
        'customer',
        'customers',
        'client',
        'clients',
        'supplier',
        'suppliers',
        'employee',
        'employees',
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

  static String normalize(String value) =>
      value.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');

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
