class AppRoutes {
  static const String root = '/';
  static const String setup = '/setup';
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
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
  static const String internalCommunications = '/internal-communications';
  
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
