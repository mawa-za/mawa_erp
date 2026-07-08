class AppRoutes {
  static const String root = '/';
  static const String setup = '/setup';
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
  static const String adminHandoff = '/admin-handoff';
  static const String home = '/home';
  static const String featureGroup = '/feature-groups/:groupId';
  static const String memberships = '/memberships';
  static const String membershipDetail = '/memberships/:id';
  static const String membershipPlans = '/membership-plans';
  static const String membershipClaims = '/membership-claims';
  static const String groupSocieties = '/group-societies';
  static const String invoices = '/invoices';
  static const String paymentRequests = '/payment-requests';
  static const String cashups = '/cashups';
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
  static const String systemConfiguration = settings;
  static const String apiLogs = '/api-logs';
  static const String products = '/products';
  static const String inventory = '/inventory';
  static const String stock = inventory;
  static const String fnbIntegrationAdmin = '/admin/fnb-integration';
  static const String messageQueueAdmin = '/admin/message-queue';
  static const String internalCommunications = '/internal-communications';
  static const String partners = '/partners';
  static const String customers = '/partners/customer';
  static const String clients = '/partners/client';
  static const String employees = '/partners/employee';
  static const String suppliers = '/partners/supplier';
  static const String businessPartners = '/partners/business-partner';

  // Appointment Booking and Calendar
  static const String appointments = '/appointments';
  static const String calendar = '/calendar';
  
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
