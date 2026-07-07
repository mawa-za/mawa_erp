import 'app_routes.dart';
import 'feature_group_registry.dart';

class WorkcenterRouteRegistry {
  static const Map<String, String> _mappings = {
    'MEMBERSHIP_MANAGEMENT': '/feature-groups/membership-management',
    'MEMBERSHIP-MANAGEMENT': '/feature-groups/membership-management',
    'FUNERAL_MANAGEMENT_GROUP': '/feature-groups/funeral-management',
    'FINANCE_MANAGEMENT': '/feature-groups/finance-management',
    'FINANCE-MANAGEMENT': '/feature-groups/finance-management',
    'PARTNER_MANAGEMENT': '/feature-groups/partner-management',
    'PARTNER-MANAGEMENT': '/feature-groups/partner-management',
    'ADMINISTRATION': '/feature-groups/administration',
    'SCHEDULING': AppRoutes.appointments,
    'MEMBERSHIP': AppRoutes.memberships,
    'MEMBER': AppRoutes.memberships,
    'MEMBERSHIPS': AppRoutes.memberships,
    'INVOICE': AppRoutes.invoices,
    'INVOICES': AppRoutes.invoices,
    'PAYMENT_REQUEST': AppRoutes.paymentRequests,
    'PAYMENT-REQUEST': AppRoutes.paymentRequests,
    'PAYMENT_REQUESTS': AppRoutes.paymentRequests,
    'PAYMENT-REQUESTS': AppRoutes.paymentRequests,
    'PAYMENT': AppRoutes.paymentRequests,
    'CASHUP': AppRoutes.cashups,
    'CASHUPS': AppRoutes.cashups,
    'CASH_UP': AppRoutes.cashups,
    'CASH-UP': AppRoutes.cashups,
    'CASES': AppRoutes.cases,
    'CASE': AppRoutes.cases,
    'CASE_MANAGEMENT': AppRoutes.cases,
    'LEGAL_CASE': AppRoutes.cases,
    'LEGAL-CASE': AppRoutes.cases,
    'LEGAL_CASES': AppRoutes.cases,
    'LEGAL_CASE_MANAGEMENT': AppRoutes.cases,
    'APPROVALS': AppRoutes.approvals,
    'APPROVAL': AppRoutes.approvals,
    'SETTINGS': AppRoutes.settings,
    'SYSTEM_SETTINGS': AppRoutes.settings,
    'PRODUCT': AppRoutes.products,
    'PRODUCTS': AppRoutes.products,
    'PRODUCT_MAINTENANCE': AppRoutes.products,
    'FNB_INTEGRATION_ADMIN': AppRoutes.fnbIntegrationAdmin,
    'FNB-INTEGRATION-ADMIN': AppRoutes.fnbIntegrationAdmin,
    'FNB_ADMIN': AppRoutes.fnbIntegrationAdmin,
    'MESSAGE_QUEUE': AppRoutes.messageQueueAdmin,
    'MESSAGE_QUEUE_ADMIN': AppRoutes.messageQueueAdmin,
    'MESSAGE-QUEUE-ADMIN': AppRoutes.messageQueueAdmin,
    'PRODUCT-MAINTENANCE': AppRoutes.products,
    'INVENTORY': AppRoutes.inventory,
    'INVENTORY_MANAGEMENT': AppRoutes.inventory,
    'INVENTORY-MANAGEMENT': AppRoutes.inventory,
    'STOCK': AppRoutes.inventory,
    'GOODS_RECEIPT': AppRoutes.inventory,
    'GOODS-RECEIPT': AppRoutes.inventory,
    'PUTAWAY': AppRoutes.inventory,
    'STOCK_ON_HAND': AppRoutes.inventory,
    'STOCK-ON-HAND': AppRoutes.inventory,
    'SALES_ORDER': AppRoutes.inventory,
    'SALES-ORDER': AppRoutes.inventory,
    'INTERNAL_COMMUNICATIONS': AppRoutes.internalCommunications,
    'INTERNAL-COMMUNICATIONS': AppRoutes.internalCommunications,
    'COMMUNICATIONS': AppRoutes.internalCommunications,
    'EMPLOYEE_ENGAGEMENT': AppRoutes.internalCommunications,
    'EMPLOYEE-ENGAGEMENT': AppRoutes.internalCommunications,
    'ENGAGEMENT': AppRoutes.internalCommunications,
    'APPOINTMENT': AppRoutes.appointments,
    'APPOINTMENTS': AppRoutes.appointments,
    'APPOINTMENT_BOOKING': AppRoutes.appointments,
    'APPOINTMENT-BOOKING': AppRoutes.appointments,
    'BOOKING': AppRoutes.appointments,
    'BOOKINGS': AppRoutes.appointments,
    'CALENDAR': AppRoutes.calendar,
    
    // Funeral Management
    'FUNERAL': AppRoutes.funeralDashboard,
    'FUNERAL_MANAGEMENT': AppRoutes.funeralDashboard,
    'MORTUARY': AppRoutes.funeralMortuary,
    'MORTUARY_INVENTORY': AppRoutes.funeralMortuary,
    'PICKUP_REQUESTS': AppRoutes.funeralPickups,
    'PICKUP_REQUEST': AppRoutes.funeralPickups,
    'FUNERAL_SERVICE_REQUEST': AppRoutes.funeralServiceRequests,
    'FUNERAL_SERVICE_REQUESTS': AppRoutes.funeralServiceRequests,
    'FUNERAL_SERVICE_REQUEST_SEARCH': AppRoutes.funeralServiceRequests,
    'FUNERAL_ARRANGEMENT': AppRoutes.funeralNewServiceRequest,
    'FUNERAL_ARRANGEMENT_CREATE': AppRoutes.funeralNewServiceRequest,
    'CORPSE_CHECK_IN': AppRoutes.funeralPickups, // Usually happens via Pickups
    'CORPSE_CHECK_OUT': AppRoutes.funeralMortuary, // Usually happens via Mortuary
    'FUNERAL_PACKAGE': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGES': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGE_SETUP': AppRoutes.funeralPackageSetup,
  };

  static String? getRoutePath(String key) {
    final upperKey = key.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    final groupRoute = FeatureGroupRegistry.routeForGroup(key);
    if (groupRoute != null) return groupRoute;

    final route = _mappings[upperKey];
    if (route != null) return route;
    
    return _mappings[key.toUpperCase()];
  }
}
