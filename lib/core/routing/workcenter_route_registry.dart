import 'app_routes.dart';

class WorkcenterRouteRegistry {
  static const Map<String, String> _mappings = {
    'MEMBERSHIP': AppRoutes.memberships,
    'MEMBERSHIPS': AppRoutes.memberships,
    'MEMBER': '/partners/MEMBER',
    'MEMBERS': '/partners/MEMBER',
    'INVOICE': AppRoutes.invoices,
    'INVOICES': AppRoutes.invoices,
    'CASES': AppRoutes.cases,
    'CASE': AppRoutes.cases,
    'CASE_MANAGEMENT': AppRoutes.cases,
    'LEGAL_CASES': AppRoutes.cases,
    'LEGAL_CASE_MANAGEMENT': AppRoutes.cases,
    'APPROVALS': AppRoutes.approvals,
    'APPROVAL': AppRoutes.approvals,
    'INBOX': AppRoutes.inbox,
    'NOTIFICATION': AppRoutes.inbox,
    'NOTIFICATIONS': AppRoutes.inbox,
    'APPROVAL_INBOX': AppRoutes.inbox,
    'APPROVAL-INBOX': AppRoutes.inbox,
    'REPORT': AppRoutes.reports,
    'REPORTS': AppRoutes.reports,
    'MANAGEMENT_MEMBERSHIP_OVERVIEW_REPORT':
        '/reports?report=membership-overview',
    'MANAGEMENT_MEMBERSHIPS_BY_PLAN_REPORT':
        '/reports?report=memberships-by-plan',
    'OPERATIONAL_PREMIUM_PERFORMANCE_REPORT':
        '/reports?report=premium-performance',
    'OPERATIONAL_CLAIMS_ACTIVITY_REPORT':
        '/reports?report=claims-activity',
    'COMPANY_FORMS': AppRoutes.companyForms,
    'COMPANY_FORM': AppRoutes.companyForms,
    'SETTINGS': AppRoutes.settings,
    'SYSTEM_SETTINGS': AppRoutes.settings,
    'SYSTEM_CONFIGURATION': AppRoutes.systemConfiguration,
    'SYSTEM_CONFIGURATIONS': AppRoutes.systemConfiguration,
    'APPROVAL_WORKFLOW': AppRoutes.approvalWorkflows,
    'APPROVAL_WORKFLOWS': AppRoutes.approvalWorkflows,
    'FNB_INTEGRATION': AppRoutes.fnbIntegration,
    'FNB_INTEGRATION_ADMIN': AppRoutes.fnbIntegration,
    'FNB_API': AppRoutes.fnbIntegration,
    'PAYMENT_INVOICE_EMAIL': AppRoutes.paymentInvoiceEmailConfiguration,
    'SIGNIFLOW': AppRoutes.signiFlowConfiguration,
    'ELECTRONIC_SIGNATURES': AppRoutes.signiFlowConfiguration,
    'XERO': AppRoutes.xeroIntegration,
    'XERO_INTEGRATION': AppRoutes.xeroIntegration,
    'XERO_INTEGRATION_ADMIN': AppRoutes.xeroIntegration,
    'MESSAGE_QUEUE': AppRoutes.messageQueueAdmin,
    'MESSAGE_QUEUE_ADMIN': AppRoutes.messageQueueAdmin,
    'QUEUE_ADMIN': AppRoutes.messageQueueAdmin,
    'DEVICE_SYNC': AppRoutes.deviceSyncWorkcenter,
    'DEVICE_SYNC_CORRECTION': AppRoutes.deviceSyncWorkcenter,
    'MAWAPAY_SYNC': AppRoutes.deviceSyncWorkcenter,
    'CALENDAR': AppRoutes.calendar,
    'APPOINTMENT': AppRoutes.appointments,
    'APPOINTMENTS': AppRoutes.appointments,
    'APPOINTMENT_BOOKING': AppRoutes.appointments,
    'SERVICE_MANAGEMENT': AppRoutes.serviceManagement,
    'SERVICE-MANAGEMENT': AppRoutes.serviceManagement,
    'SERVICES': AppRoutes.serviceManagement,
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
    'EMPLOYEE': AppRoutes.employment,
    'EMPLOYEES': AppRoutes.employment,
    'EMPLOYMENT': AppRoutes.employment,
    'EMPLOYMENT_MANAGEMENT': AppRoutes.employment,
    'PARTNER': '/partners/PARTNER',
    'PARTNERS': '/partners/PARTNER',
    'BUSINESS_PARTNER': '/partners/PARTNER',
    'BUSINESS_PARTNERS': '/partners/PARTNER',
    'PARTNER_MANAGEMENT': '/partners/PARTNER',
    'EMPLOYEE_REQUEST': AppRoutes.employeeRequests,
    'EMPLOYEE_REQUESTS': AppRoutes.employeeRequests,
    'LEAVE_REQUEST': AppRoutes.employeeRequests,
    'LEAVE_REQUESTS': AppRoutes.employeeRequests,
    'LEAVE_APPROVAL': AppRoutes.employeeRequests,
    'LEAVE_APPROVALS': AppRoutes.employeeRequests,
    'LEAVE_MANAGEMENT': AppRoutes.employeeRequests,
    'ASSET': AppRoutes.assetRegister,
    'ASSETS': AppRoutes.assetRegister,
    'ASSET_REGISTER': AppRoutes.assetRegister,
    'INTERNAL_COMMUNICATIONS': AppRoutes.internalCommunications,
    'INTERNAL-COMMUNICATIONS': AppRoutes.internalCommunications,
    'COMMUNICATIONS': AppRoutes.internalCommunications,
    'EMPLOYEE_ENGAGEMENT': AppRoutes.internalCommunications,
    'EMPLOYEE-ENGAGEMENT': AppRoutes.internalCommunications,
    'ENGAGEMENT': AppRoutes.internalCommunications,

    // Membership and product maintenance
    'PRODUCT': AppRoutes.products,
    'PRODUCTS': AppRoutes.products,
    'PRODUCT_MAINTENANCE': AppRoutes.products,
    'PRODUCT_MASTER': AppRoutes.products,
    'MEMBERSHIP_CLAIM': AppRoutes.membershipClaims,
    'MEMBERSHIP_CLAIMS': AppRoutes.membershipClaims,
    'CLAIMS': AppRoutes.membershipClaims,
    'MEMBERSHIP_PLAN': AppRoutes.membershipPlans,
    'MEMBERSHIP_PLANS': AppRoutes.membershipPlans,
    'GROUP_SOCIETY': AppRoutes.groupSocieties,
    'GROUP_SOCIETIES': AppRoutes.groupSocieties,
    'GROUP_SOCIETY_MANAGEMENT': AppRoutes.groupSocieties,
    'FUNERAL_COVER_UNDERWRITING': AppRoutes.funeralCoverUnderwriting,
    'THIRD_PARTY_FUNERAL_UNDERWRITING': AppRoutes.funeralCoverUnderwriting,

    // Inventory Management
    'INVENTORY': AppRoutes.inventory,
    'INVENTORY_MANAGEMENT': AppRoutes.inventory,
    'STOCK_MANAGEMENT': AppRoutes.inventory,
    'QUOTATION': AppRoutes.inventoryQuotations,
    'QUOTATIONS': AppRoutes.inventoryQuotations,
    'QUOTE': AppRoutes.inventoryQuotations,
    'QUOTES': AppRoutes.inventoryQuotations,
    'PURCHASE_ORDER': AppRoutes.inventoryPurchaseOrders,
    'PURCHASE_ORDERS': AppRoutes.inventoryPurchaseOrders,
    'STOCK_ON_HAND': AppRoutes.inventoryStockOnHand,
    'GOODS_RECEIPT': AppRoutes.inventoryGoodsReceipts,
    'GOODS_RECEIPTS': AppRoutes.inventoryGoodsReceipts,
    'PUTAWAY': AppRoutes.inventoryPutaways,
    'PUTAWAYS': AppRoutes.inventoryPutaways,
    'STOCK_MOVEMENT': AppRoutes.inventoryMovements,
    'STOCK_MOVEMENTS': AppRoutes.inventoryMovements,
    'INVENTORY_MOVEMENT': AppRoutes.inventoryMovements,
    'INVENTORY_MOVEMENTS': AppRoutes.inventoryMovements,
    'SALES_ORDER': AppRoutes.inventorySalesOrders,
    'SALES_ORDERS': AppRoutes.inventorySalesOrders,
    'LAYBY': AppRoutes.laybys,
    'LAYBYS': AppRoutes.laybys,
    'SERVICE_ORDER': AppRoutes.serviceOrders,
    'SERVICE_ORDERS': AppRoutes.serviceOrders,
    'INVENTORY_AUDIT': AppRoutes.inventoryAudit,
    'STOCK_AUDIT': AppRoutes.inventoryAudit,
    'INVENTORY_SETUP': AppRoutes.systemConfiguration,
    'WAREHOUSE_SETUP': AppRoutes.systemConfiguration,

    // Tombstone Management
    'TOMBSTONE': AppRoutes.tombstones,
    'TOMBSTONES': AppRoutes.tombstones,
    'TOMBSTONE_MANAGEMENT': AppRoutes.tombstones,
    'TOMBSTONE_ORDER': AppRoutes.tombstoneOrders,
    'TOMBSTONE_ORDERS': AppRoutes.tombstoneOrders,
    'TOMBSTONE_LAYBY': AppRoutes.tombstoneLaybys,
    'TOMBSTONE_LAYBYS': AppRoutes.tombstoneLaybys,
    'TOMBSTONE_SITE_ASSESSMENT': AppRoutes.tombstoneSiteAssessments,
    'TOMBSTONE_SITE_ASSESSMENTS': AppRoutes.tombstoneSiteAssessments,
    'TOMBSTONE_DESIGN_APPROVAL': AppRoutes.tombstoneDesignApprovals,
    'TOMBSTONE_DESIGN_APPROVALS': AppRoutes.tombstoneDesignApprovals,
    'TOMBSTONE_PRODUCTION_JOB': AppRoutes.tombstoneProductionJobs,
    'TOMBSTONE_PRODUCTION_JOBS': AppRoutes.tombstoneProductionJobs,
    'TOMBSTONE_INSTALLATION': AppRoutes.tombstoneInstallations,
    'TOMBSTONE_INSTALLATIONS': AppRoutes.tombstoneInstallations,
    'TOMBSTONE_INSTALLATION_PLANNING': AppRoutes.tombstoneInstallations,
    'TOMBSTONE_INSTALLATION_CALENDAR': AppRoutes.tombstoneInstallationCalendar,
    'TOMBSTONE_INSTALLATION_TEAM': AppRoutes.tombstoneInstallationTeams,
    'TOMBSTONE_INSTALLATION_TEAMS': AppRoutes.tombstoneInstallationTeams,
    'TOMBSTONE_REWORK_JOB': AppRoutes.tombstoneReworkJobs,
    'TOMBSTONE_REWORK_JOBS': AppRoutes.tombstoneReworkJobs,
    'TOMBSTONE_REPORT': AppRoutes.tombstoneReports,
    'TOMBSTONE_REPORTS': AppRoutes.tombstoneReports,

    // Funeral Management
    'FUNERAL': AppRoutes.funeralDashboard,
    'FUNERAL_MANAGEMENT': AppRoutes.funeralDashboard,
    'MORTUARY': AppRoutes.funeralMortuary,
    'MORTUARY_INVENTORY': AppRoutes.funeralMortuary,
    'PICKUP_REQUESTS': AppRoutes.funeralPickups,
    'PICKUP_REQUEST': AppRoutes.funeralPickups,
    'FUNERAL_SERVICE_REQUEST': AppRoutes.funeralServiceRequests,
    'FUNERAL_SERVICE_REQUESTS': AppRoutes.funeralServiceRequests,
    'CORPSE_CHECK_IN': AppRoutes.funeralPickups, // Usually happens via Pickups
    'CORPSE_CHECK_OUT': AppRoutes.funeralMortuary, // Usually happens via Mortuary
    'FUNERAL_PACKAGE': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGES': AppRoutes.funeralPackageSetup,
    'FUNERAL_PACKAGE_SETUP': AppRoutes.funeralPackageSetup,
    'FUNERAL_CLAIM': AppRoutes.funeralAllClaims,
    'FUNERAL_CLAIMS': AppRoutes.funeralAllClaims,
    'FUNERAL_PAYMENT': AppRoutes.funeralPayments,
    'FUNERAL_PAYMENTS': AppRoutes.funeralPayments,
  };

  static String? getRoutePath(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return null;

    final direct = _mappings[normalized];
    if (direct != null) return direct;

    // Tenant workcenter identifiers are not always consistent. Resolve the
    // common descriptive variants here so configured cards never fall back to
    // the old "feature coming soon" placeholder merely because a suffix such
    // as LIST, MANAGEMENT or DISPLAY was added.
    if (normalized.contains('REPORT') && !normalized.contains('TOMBSTONE')) {
      return AppRoutes.reports;
    }
    if (normalized.contains('FNB') && normalized.contains('INTEGRATION')) {
      return AppRoutes.fnbIntegration;
    }
    if (normalized.contains('XERO')) {
      return AppRoutes.xeroIntegration;
    }
    if (normalized.contains('DEVICE') && normalized.contains('SYNC')) {
      return AppRoutes.deviceSyncWorkcenter;
    }
    if (normalized.contains('MAWAPAY') && normalized.contains('SYNC')) {
      return AppRoutes.deviceSyncWorkcenter;
    }
    if (normalized.contains('MESSAGE') && normalized.contains('QUEUE')) {
      return AppRoutes.messageQueueAdmin;
    }
    if (normalized.contains('FUNERAL') && normalized.contains('CLAIM')) {
      return AppRoutes.funeralAllClaims;
    }
    if (normalized.contains('FUNERAL') && normalized.contains('PAYMENT')) {
      return AppRoutes.funeralPayments;
    }
    if (normalized.contains('MEMBERSHIP') && normalized.contains('CLAIM')) {
      return AppRoutes.membershipClaims;
    }
    if (normalized.contains('MEMBERSHIP') && normalized.contains('PLAN')) {
      return AppRoutes.membershipPlans;
    }
    if (normalized.contains('GROUP') && normalized.contains('SOCIET')) {
      return AppRoutes.groupSocieties;
    }
    if (normalized.contains('EMPLOYMENT') || normalized == 'EMPLOYEE' || normalized == 'EMPLOYEES') {
      return AppRoutes.employment;
    }
    if (normalized.contains('LEAVE')) {
      return AppRoutes.employeeRequests;
    }
    if (normalized.contains('ASSET')) {
      return AppRoutes.assetRegister;
    }
    if (normalized.contains('FUNERAL') && normalized.contains('SERVICE') && normalized.contains('REQUEST')) {
      return AppRoutes.funeralServiceRequests;
    }
    if (normalized.contains('TOMBSTONE')) {
      if (normalized.contains('LAYBY')) return AppRoutes.tombstoneLaybys;
      if (normalized.contains('ASSESS')) return AppRoutes.tombstoneSiteAssessments;
      if (normalized.contains('DESIGN')) return AppRoutes.tombstoneDesignApprovals;
      if (normalized.contains('PRODUCTION')) return AppRoutes.tombstoneProductionJobs;
      if (normalized.contains('CALENDAR')) return AppRoutes.tombstoneInstallationCalendar;
      if (normalized.contains('TEAM')) return AppRoutes.tombstoneInstallationTeams;
      if (normalized.contains('REWORK')) return AppRoutes.tombstoneReworkJobs;
      if (normalized.contains('REPORT')) return AppRoutes.tombstoneReports;
      if (normalized.contains('INSTALL')) return AppRoutes.tombstoneInstallations;
      if (normalized.contains('ORDER')) return AppRoutes.tombstoneOrders;
      return AppRoutes.tombstones;
    }
    if (normalized.contains('PRODUCT')) {
      return AppRoutes.products;
    }
    if (normalized.contains('QUOT')) {
      return AppRoutes.inventoryQuotations;
    }
    if (normalized.contains('LAYBY')) {
      return AppRoutes.laybys;
    }
    if (normalized.contains('SERVICE') && normalized.contains('MANAGEMENT')) {
      return AppRoutes.serviceManagement;
    }
    if (normalized.contains('SERVICE') && normalized.contains('ORDER')) {
      return AppRoutes.serviceOrders;
    }
    if (normalized.contains('PURCHASE') && normalized.contains('ORDER')) {
      return AppRoutes.inventoryPurchaseOrders;
    }
    if (normalized.contains('STOCK') && normalized.contains('HAND')) {
      return AppRoutes.inventoryStockOnHand;
    }
    if (normalized.contains('GOODS') && normalized.contains('RECEIPT')) {
      return AppRoutes.inventoryGoodsReceipts;
    }
    if (normalized.contains('PUTAWAY')) {
      return AppRoutes.inventoryPutaways;
    }
    if (normalized.contains('STOCK') && normalized.contains('MOVEMENT')) {
      return AppRoutes.inventoryMovements;
    }
    if (normalized.contains('SALES') && normalized.contains('ORDER')) {
      return AppRoutes.inventorySalesOrders;
    }
    if (normalized.contains('INVENTORY') && normalized.contains('AUDIT')) {
      return AppRoutes.inventoryAudit;
    }
    if (normalized.contains('INVENTORY') &&
        (normalized.contains('SETUP') || normalized.contains('CONFIG'))) {
      return AppRoutes.systemConfiguration;
    }

    return null;
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
