import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import 'route_guards.dart';

import '../../features/setup/setup_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/admin_handoff_screen.dart';
import '../../features/home/home_page.dart';
import '../../features/home/screens/feature_group_screen.dart';
import '../../features/membership/screens/membership_detail_screen.dart';
import '../../features/membership/screens/member_list_screen.dart';
import '../../features/invoicing/screens/invoice_pdf_preview_screen.dart';
import '../../features/invoicing/screens/invoice_list_screen.dart';
import '../../features/service_orders/screens/service_order_list_screen.dart';
import '../../features/cases/screens/case_list_screen.dart';
import '../../features/cases/screens/create_case_screen.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/cases/screens/case_detail_shell_screen.dart';
import '../../features/approvals/screens/approval_list_screen.dart';
import '../../features/approvals/screens/approval_workflow_list_screen.dart';
import '../../features/inbox/screens/inbox_screen.dart';
import '../../features/settings/screens/system_configuration_screen.dart';
import '../../features/integrations/fnb/fnb_integration_admin_screen.dart';
import '../../features/settings/screens/xero_integration_screen.dart';
import '../../features/settings/screens/payment_request_invoice_email_configuration_screen.dart';
import '../../features/settings/screens/signiflow_configuration_screen.dart';
import '../../features/admin/message_queue/message_queue_admin_screen.dart';
import '../../features/device_sync/screens/device_sync_workcenter_screen.dart';
import '../../features/appointments/screens/appointment_calendar_screen.dart';
import '../../features/cashup/screens/cashup_list_screen.dart';
import '../../features/payments/screens/payment_request_list_screen.dart';
import '../../features/leave_management/screens/leave_management_screen.dart';
import '../../features/employment/screens/employment_management_screen.dart';
import '../../features/assets/screens/asset_register_screen.dart';
import '../../features/products/screens/product_maintenance_screen.dart';
import '../../features/membership/screens/membership_claim_list_screen.dart';
import '../../features/membership/screens/membership_plan_list_screen.dart';
import '../../features/membership/screens/group_society_list_screen.dart';
import '../../features/stock/screens/stock_management_screen.dart';
import '../../features/laybys/screens/layby_management_screen.dart';
import '../../features/tombstones/screens/tombstone_management_screen.dart';
import '../../features/tombstones/screens/tombstone_order_detail_screen.dart';
import '../../features/tombstones/screens/tombstone_order_form_screen.dart';
import '../../features/reports/screens/reports_dashboard_screen.dart';
import '../../features/forms/company_forms_screen.dart';

// Funeral Management
import '../../features/funeral/presentation/pages/funeral_dashboard_page.dart';
import '../../features/funeral/presentation/pages/pickup_requests_page.dart';
import '../../features/funeral/presentation/pages/create_pickup_request_page.dart';
import '../../features/funeral/presentation/pages/mortuary_inventory_page.dart';
import '../../features/funeral/presentation/pages/funeral_service_request_wizard_page.dart';
import '../../features/funeral/presentation/pages/funeral_claims_page.dart';
import '../../features/funeral/presentation/pages/funeral_invoice_preview_page.dart';
import '../../features/funeral/presentation/pages/funeral_invoice_payment_page.dart';
import '../../features/funeral/presentation/pages/funeral_service_request_page.dart';
import '../../features/funeral/presentation/pages/funeral_package_setup_page.dart';
import '../../features/funeral/presentation/pages/funeral_all_claims_page.dart';
import '../../features/funeral/presentation/pages/funeral_payments_page.dart';
import '../../features/funeral/presentation/pages/third_party_funeral_cover_underwriting_page.dart';

import '../services/session_service.dart';

import 'dart:async';
import '../api_client.dart';

import '../../features/partners/screens/partner_list_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(ApiClient().logoutStream),
    redirect: (context, state) async {
      final isConfigured = await RouteGuards.isConfigured();
      final isAuthenticated = await RouteGuards.isAuthenticated();

      final bool isPublicRoute = state.matchedLocation == AppRoutes.login ||
                                 state.matchedLocation == AppRoutes.setup ||
                                 state.matchedLocation == AppRoutes.resetPassword ||
                                 state.matchedLocation == AppRoutes.adminHandoff ||
                                 state.matchedLocation.endsWith('/preview') ||
                                 state.matchedLocation == AppRoutes.legacyInvoicePreview;

      // A secure Admin handoff may intentionally open on a shared ERP host.
      // Its signed token contains the tenant routing claim, so the handoff page
      // must be allowed to exchange the token before normal configuration
      // guards require a persisted tenant.
      if (state.matchedLocation == AppRoutes.adminHandoff) {
        return null;
      }

      if (!isConfigured && state.matchedLocation != AppRoutes.setup && !state.matchedLocation.endsWith('/preview')) {
        return AppRoutes.setup;
      }

      if (isConfigured && state.matchedLocation == AppRoutes.setup) {
        return AppRoutes.home;
      }

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && (state.matchedLocation == AppRoutes.login || state.matchedLocation == AppRoutes.root)) {
        return AppRoutes.home;
      }

      // Legacy redirects
      if (state.uri.path == AppRoutes.legacyMembershipDetail) {
        final id = state.uri.queryParameters['id'];
        if (id != null) return '/memberships/$id';
      }
      if (state.uri.path == AppRoutes.legacyInvoicePreview) {
        final id = state.uri.queryParameters['id'];
        if (id != null) return '/invoices/$id/preview';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (_, __) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => SetupScreen(
          onConfigured: () => context.go(AppRoutes.home),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          onLoggedIn: () {
            SessionService().startMonitoring();
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: AppRoutes.adminHandoff,
        builder: (context, state) => AdminHandoffScreen(
          token: state.uri.queryParameters['token'] ?? '',
          redirectPath: state.uri.queryParameters['redirect'] ?? AppRoutes.home,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MyHomePage(title: 'mawa'),
      ),
      GoRoute(
        path: '/feature-groups/:groupId',
        builder: (context, state) => FeatureGroupScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.memberships,
        builder: (context, state) => const MemberListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return MembershipDetailScreen(membershipId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.invoices,
        builder: (context, state) => const InvoiceListScreen(),
        routes: [
          GoRoute(
            path: ':id/preview',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return InvoicePdfPreviewScreen(invoiceId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.serviceOrders,
        builder: (context, state) => const ServiceOrderListScreen(),
      ),
      GoRoute(
        path: AppRoutes.cases,
        builder: (context, state) => const CaseListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CreateCaseScreen(),
          ),
          GoRoute(
            path: ':caseId',
            builder: (context, state) {
              final caseId = state.pathParameters['caseId']!;
              return CaseDetailShellScreen(caseId: caseId, initialTab: 'overview');
            },
            routes: [
              GoRoute(path: 'tasks', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'tasks')),
              GoRoute(path: 'events', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'events')),
              GoRoute(path: 'parties', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'parties')),
              GoRoute(path: 'notes', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'notes')),
              GoRoute(path: 'billing', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'billing')),
              GoRoute(path: 'invoice-preview', builder: (context, state) => CaseDetailShellScreen(caseId: state.pathParameters['caseId']!, initialTab: 'invoice-preview')),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/partners/:role',
        builder: (context, state) {
          final role = state.pathParameters['role']!.toUpperCase();
          final isBusinessPartner = role == 'PARTNER';
          return PartnerListScreen(
            role: isBusinessPartner ? null : role,
            title: isBusinessPartner
                ? 'Business Partners'
                : '${role[0]}${role.substring(1).toLowerCase()}s',
            // Generic Business Partner and Supplier onboarding allow creation.
            // Member/dependent records are maintained through membership flows.
            allowCreate: isBusinessPartner || role == 'SUPPLIER',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inbox,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.approvals,
        builder: (context, state) => ApprovalListScreen(
          approvalType: state.uri.queryParameters['type'],
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SystemConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.systemConfiguration,
        builder: (context, state) => const SystemConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.approvalWorkflows,
        builder: (context, state) => const ApprovalWorkflowListScreen(),
      ),
      GoRoute(
        path: AppRoutes.fnbIntegration,
        builder: (context, state) => const FnbIntegrationAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.xeroIntegration,
        builder: (context, state) => const XeroIntegrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentInvoiceEmailConfiguration,
        builder: (context, state) =>
            const PaymentRequestInvoiceEmailConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.signiFlowConfiguration,
        builder: (context, state) => const SigniFlowConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.messageQueueAdmin,
        builder: (context, state) => const MessageQueueAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceSyncWorkcenter,
        builder: (context, state) => const DeviceSyncWorkcenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (context, state) => const AppointmentCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.appointments,
        builder: (context, state) => const AppointmentCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.cashups,
        builder: (context, state) => const CashupListScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentRequests,
        builder: (context, state) => const PaymentRequestListScreen(),
      ),
      GoRoute(
        path: AppRoutes.employment,
        builder: (context, state) => const EmploymentManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.assetRegister,
        builder: (context, state) => const AssetRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.employeeRequests,
        builder: (context, state) => const LeaveManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.products,
        builder: (context, state) => const ProductMaintenanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.membershipClaims,
        builder: (context, state) => const MembershipClaimListScreen(),
      ),
      GoRoute(
        path: AppRoutes.membershipPlans,
        builder: (context, state) => const MembershipPlanListScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupSocieties,
        builder: (context, state) => const GroupSocietyListScreen(),
      ),
      GoRoute(
        path: AppRoutes.funeralCoverUnderwriting,
        builder: (context, state) =>
            const ThirdPartyFuneralCoverUnderwritingPage(),
      ),
      GoRoute(
        path: AppRoutes.companyForms,
        builder: (context, state) => const CompanyFormsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => ReportsDashboardScreen(
          reportKey: state.uri.queryParameters['report'],
        ),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventoryQuotations,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'quotations'),
      ),
      GoRoute(
        path: AppRoutes.inventoryPurchaseOrders,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'purchase-orders'),
      ),
      GoRoute(
        path: AppRoutes.inventoryStockOnHand,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'stock-on-hand'),
      ),
      GoRoute(
        path: AppRoutes.inventoryGoodsReceipts,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'goods-receipts'),
      ),
      GoRoute(
        path: AppRoutes.inventoryPutaways,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'putaways'),
      ),
      GoRoute(
        path: AppRoutes.inventoryMovements,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'stock-movements'),
      ),
      GoRoute(
        path: AppRoutes.inventorySalesOrders,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'sales-orders'),
      ),
      GoRoute(
        path: AppRoutes.laybys,
        builder: (context, state) => const LaybyManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventoryAudit,
        builder: (context, state) => const InventoryManagementScreen(initialSection: 'inventory-audit'),
      ),
      GoRoute(
        path: AppRoutes.inventorySetup,
        redirect: (context, state) => AppRoutes.systemConfiguration,
      ),

      // Tombstone Management
      GoRoute(
        path: AppRoutes.tombstones,
        builder: (context, state) => const TombstoneManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.tombstoneOrders,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'orders'),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const TombstoneOrderFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => TombstoneOrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.tombstoneLaybys,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'laybys'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneSiteAssessments,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'assessments'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneDesignApprovals,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'designs'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneProductionJobs,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'production'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneInstallations,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'installations'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneInstallationCalendar,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'calendar'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneInstallationTeams,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'teams'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneReworkJobs,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'rework'),
      ),
      GoRoute(
        path: AppRoutes.tombstoneReports,
        builder: (context, state) => const TombstoneManagementScreen(initialSection: 'reports'),
      ),

      // Funeral Routes
      GoRoute(
        path: AppRoutes.funeralDashboard,
        builder: (context, state) => const FuneralDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.funeralPickups,
        builder: (context, state) => const PickupRequestsPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CreatePickupRequestPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.funeralMortuary,
        builder: (context, state) => const MortuaryInventoryPage(),
      ),
      GoRoute(
        path: AppRoutes.funeralServiceRequests,
        builder: (context, state) => const FuneralServiceRequestPage(),
      ),
      GoRoute(
        path: AppRoutes.funeralNewServiceRequest,
        builder: (context, state) => const FuneralServiceRequestWizardPage(),
      ),
      GoRoute(
        path: '/funeral/service-request/:id/resume',
        builder: (context, state) => FuneralServiceRequestWizardPage(
          serviceRequestId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.funeralClaims,
        builder: (context, state) => FuneralClaimsPage(
          serviceRequestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.funeralInvoicePreview,
        builder: (context, state) => FuneralInvoicePreviewPage(
          serviceRequestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.funeralInvoicePayment,
        builder: (context, state) => FuneralInvoicePaymentPage(
          invoiceId: state.pathParameters['invoiceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.funeralPayments,
        builder: (context, state) => const FuneralPaymentsPage(),
      ),
      GoRoute(
        path: AppRoutes.funeralPackageSetup,
        builder: (context, state) => const FuneralPackageSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.legacyFuneralPackageSetup,
        redirect: (context, state) => AppRoutes.funeralPackageSetup,
      ),
      GoRoute(
        path: AppRoutes.funeralAllClaims,
        builder: (context, state) => const FuneralAllClaimsPage(),
      ),
    ],
  );
}
