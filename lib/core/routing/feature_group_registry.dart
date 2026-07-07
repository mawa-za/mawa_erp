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

  bool matches(String workcenterId) {
    final normalized = FeatureGroupRegistry.normalize(workcenterId);
    return normalizeList(childWorkcenterIds).contains(normalized) ||
        normalizeList(aliases).contains(normalized) ||
        normalize(id) == normalized;
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
        'member',
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
        'payment-request',
        'cashup',
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
        'sales-order',
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
        'client',
        'supplier',
        'employee',
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
        'api-log',
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

  static FeatureGroupDefinition? groupForWorkcenter(String workcenterId) {
    for (final group in groups) {
      if (group.matches(workcenterId)) return group;
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
