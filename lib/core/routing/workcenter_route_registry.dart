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
    'INTERNAL_COMMUNICATIONS': AppRoutes.internalCommunications,
    'EMPLOYEE_ENGAGEMENT': AppRoutes.internalCommunications,
  };

  static String? getRoutePath(String key) {
    final upperKey = key.toUpperCase();
    return _mappings[upperKey];
  }
}
