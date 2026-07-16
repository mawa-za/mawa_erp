class AppRoutes {
  static const String root = '/';
  static const String setup = '/setup';
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
  static const String adminHandoff = '/admin-handoff';
  static const String home = '/home';
  static const String memberships = '/memberships';
  static const String membershipDetail = '/memberships/:id';
  static const String invoices = '/invoices';
  static const String invoicePreview = '/invoices/:id/preview';
  static const String cases = '/cases';
  static const String createCase = '/cases/new';
  static const String caseDetail = '/cases/:caseId';
  static const String caseTasks = '/cases/:caseId/tasks';
  static const String caseEvents = '/cases/:caseId/events';
  static const String caseParties = '/cases/:caseId/parties';
  static const String caseNotes = '/cases/:caseId/notes';
  static const String caseBilling = '/cases/:caseId/billing';
  static const String caseInvoicePreview = '/cases/:caseId/invoice-preview';
  static const String approvals = '/approvals';
  static const String settings = '/settings';
  static const String systemConfiguration = '/system-configuration';
  static const String fnbIntegration = '/system-configuration/fnb-integration';
  static const String xeroIntegration = '/system-configuration/xero-integration';
  static const String messageQueueAdmin = '/admin/message-queue';
  static const String calendar = '/calendar';
  static const String appointments = '/appointments';
  static const String cashups = '/cashups';
  static const String paymentRequests = '/payment-requests';
  static const String employment = '/employment';
  static const String employeeRequests = '/employee-requests';
  static const String assetRegister = '/assets';
  static const String internalCommunications = '/internal-communications';
  static const String products = '/products';
  static const String membershipClaims = '/membership-claims';
  static const String membershipPlans = '/membership-plans';
  static const String groupSocieties = '/group-societies';
  static const String inventory = '/inventory';
  static const String inventoryQuotations = '/inventory/quotations';
  static const String inventoryPurchaseOrders = '/inventory/purchase-orders';
  static const String inventoryStockOnHand = '/inventory/stock-on-hand';
  static const String inventoryGoodsReceipts = '/inventory/goods-receipts';
  static const String inventoryPutaways = '/inventory/putaways';
  static const String inventoryMovements = '/inventory/stock-movements';
  static const String inventorySalesOrders = '/inventory/sales-orders';
  static const String inventoryAudit = '/inventory/audit';
  static const String inventorySetup = '/inventory/setup';

  // Tombstone Management
  static const String tombstones = '/tombstones';
  static const String tombstoneOrders = '/tombstones/orders';
  static const String tombstoneOrderDetail = '/tombstones/orders/:id';
  static const String tombstoneNewOrder = '/tombstones/orders/new';
  static const String tombstoneLaybys = '/tombstones/laybys';
  static const String tombstoneSiteAssessments = '/tombstones/site-assessments';
  static const String tombstoneDesignApprovals = '/tombstones/designs';
  static const String tombstoneProductionJobs = '/tombstones/production';
  static const String tombstoneInstallations = '/tombstones/installations';
  static const String tombstoneInstallationCalendar = '/tombstones/calendar';
  static const String tombstoneInstallationTeams = '/tombstones/teams';
  static const String tombstoneReworkJobs = '/tombstones/rework';
  static const String tombstoneReports = '/tombstones/reports';

  // Funeral Management
  static const String funeralDashboard = '/funeral';
  static const String funeralPickups = '/funeral/pickups';
  static const String funeralNewPickup = '/funeral/pickups/new';
  static const String funeralMortuary = '/funeral/mortuary';
  static const String funeralServiceRequests = '/funeral/service-requests';
  static const String funeralNewServiceRequest = '/funeral/service-request/new';
  static const String funeralClaims = '/funeral/service-request/:id/claims';
  static const String funeralAllClaims = '/funeral/claims';
  static const String funeralInvoicePreview = '/funeral/service-request/:id/invoice-preview';
  static const String funeralInvoicePayment = '/funeral/invoice/:invoiceId/payment';
  static const String funeralPayments = '/funeral/payments';
  static const String funeralPackageSetup = '/funeral/packages/setup';

  // Legacy routes for redirection
  static const String legacyMembershipDetail = '/membership-detail';
  static const String legacyInvoicePreview = '/invoice-preview';
}
