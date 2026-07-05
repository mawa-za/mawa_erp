import 'app_routes.dart';

class WorkcenterRouteRegistry {
  static const Map<String, String> _mappings = {
    'MEMBERSHIP': AppRoutes.memberships,
    'MEMBER': AppRoutes.memberships,
    'MEMBERSHIPS': AppRoutes.memberships,
    'INVOICE': AppRoutes.invoices,
    'INVOICES': AppRoutes.invoices,
    'CASES': AppRoutes.cases,
    'CASE': AppRoutes.cases,
    'CASE_MANAGEMENT': AppRoutes.cases,
    'LEGAL_CASES': AppRoutes.cases,
    'LEGAL_CASE_MANAGEMENT': AppRoutes.cases,
    'APPROVALS': AppRoutes.approvals,
    'APPROVAL': AppRoutes.approvals,
    'SETTINGS': AppRoutes.settings,
    'SYSTEM_SETTINGS': AppRoutes.settings,
    'PRODUCT': AppRoutes.products,
    'PRODUCTS': AppRoutes.products,
    'PRODUCT_MAINTENANCE': AppRoutes.products,
    'PRODUCT-MAINTENANCE': AppRoutes.products,
    'INTERNAL_COMMUNICATIONS': AppRoutes.internalCommunications,
    'INTERNAL-COMMUNICATIONS': AppRoutes.internalCommunications,
    'COMMUNICATIONS': AppRoutes.internalCommunications,
    'EMPLOYEE_ENGAGEMENT': AppRoutes.internalCommunications,
    'EMPLOYEE-ENGAGEMENT': AppRoutes.internalCommunications,
    'ENGAGEMENT': AppRoutes.internalCommunications,
    
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
    final route = _mappings[upperKey];
    if (route != null) return route;
    
    return _mappings[key.toUpperCase()];
  }
}
