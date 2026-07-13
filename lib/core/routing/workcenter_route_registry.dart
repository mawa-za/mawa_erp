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
    'SYSTEM_CONFIGURATION': AppRoutes.systemConfiguration,
    'SYSTEM_CONFIGURATIONS': AppRoutes.systemConfiguration,
    'CALENDAR': AppRoutes.calendar,
    'APPOINTMENT': AppRoutes.appointments,
    'APPOINTMENTS': AppRoutes.appointments,
    'APPOINTMENT_BOOKING': AppRoutes.appointments,
    'CASHUP': AppRoutes.cashups,
    'CASHUPS': AppRoutes.cashups,
    'PAYMENT_REQUEST': AppRoutes.paymentRequests,
    'PAYMENT_REQUESTS': AppRoutes.paymentRequests,
    'CUSTOMER': '/partners/CUSTOMER',
    'CUSTOMERS': '/partners/CUSTOMER',
    'CLIENT': '/partners/CUSTOMER',
    'CLIENTS': '/partners/CUSTOMER',
    'SUPPLIER': '/partners/SUPPLIER',
    'SUPPLIERS': '/partners/SUPPLIER',
    'EMPLOYEE': '/partners/EMPLOYEE',
    'EMPLOYEES': '/partners/EMPLOYEE',
    'PARTNER': '/partners/PARTNER',
    'PARTNERS': '/partners/PARTNER',
    'EMPLOYEE_REQUEST': AppRoutes.employeeRequests,
    'EMPLOYEE_REQUESTS': AppRoutes.employeeRequests,
    'LEAVE_REQUEST': AppRoutes.employeeRequests,
    'LEAVE_REQUESTS': AppRoutes.employeeRequests,
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
    'FUNERAL_SERVICE_REQUEST': AppRoutes.funeralNewServiceRequest,
    'FUNERAL_SERVICE_REQUESTS': AppRoutes.funeralNewServiceRequest,
    'CORPSE_CHECK_IN': AppRoutes.funeralPickups, // Usually happens via Pickups
    'CORPSE_CHECK_OUT': AppRoutes.funeralMortuary, // Usually happens via Mortuary
    'FUNERAL_PACKAGE': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGES': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGE_SETUP': AppRoutes.funeralPackageSetup,
  };

  static String? getRoutePath(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return null;
    return _mappings[normalized];
  }

  static String _normalizeKey(String key) {
    var value = key.trim();
    if (value.isEmpty) return '';

    // Workcenter configuration sometimes stores legacy absolute paths such as
    // /cashup, /payment-requests or /partners/CUSTOMER. Resolve the final path
    // segment through the registry before asking GoRouter to open it directly.
    final parsed = Uri.tryParse(value);
    final segments = parsed?.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    if (segments.isNotEmpty) {
      value = segments.last;
    }

    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
