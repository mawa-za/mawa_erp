import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import 'route_guards.dart';

import '../../features/setup/setup_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/home/home_page.dart';
import '../../features/home/screens/feature_group_screen.dart';
import '../../features/membership/screens/membership_detail_screen.dart';
import '../../features/membership/screens/member_list_screen.dart';

import '../../features/membership/screens/membership_plan_list_screen.dart';
import '../../features/membership/screens/membership_claim_list_screen.dart';
import '../../features/membership/screens/group_society_list_screen.dart';
import '../../features/invoicing/screens/invoice_pdf_preview_screen.dart';
import '../../features/invoicing/screens/invoice_list_screen.dart';
import '../../features/payments/screens/payment_request_list_screen.dart';
import '../../features/cashup/screens/cashup_list_screen.dart';
import '../../features/cases/screens/case_list_screen.dart';
import '../../features/cases/screens/create_case_screen.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/cases/screens/case_detail_shell_screen.dart';
import '../../features/approvals/screens/approval_list_screen.dart';
import '../../features/settings/screens/system_configuration_screen.dart';
import '../../features/settings/screens/api_log_list_screen.dart';
import '../../features/products/screens/product_maintenance_screen.dart';
import '../../features/integrations/fnb/fnb_integration_admin_screen.dart';
import '../../features/admin/message_queue/message_queue_admin_screen.dart';
import '../../features/appointments/screens/appointment_calendar_screen.dart';
import '../../features/stock/screens/stock_management_screen.dart';

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

import '../services/session_service.dart';

import 'dart:async';
import '../api_client.dart';

import '../../features/partners/screens/partner_list_screen.dart';


String _partnerTitleForRole(String role, String rawRole) {
  switch (role) {
    case 'CUSTOMER':
      return 'Customers';
    case 'CLIENT':
      return 'Clients';
    case 'EMPLOYEE':
      return 'Employees';
    case 'SUPPLIER':
      return 'Suppliers';
    case 'BUSINESS_PARTNER':
    case 'BUSINESS_PARTNERS':
    case 'PARTNER':
    case 'PARTNERS':
      return 'Business Partners';
    default:
      final words = rawRole
          .replaceAll('_', '-')
          .split('-')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
      return words.isEmpty ? 'Business Partners' : words;
  }
}

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
                                 state.matchedLocation.endsWith('/preview') ||
                                 state.matchedLocation == AppRoutes.legacyInvoicePreview; 

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
        path: AppRoutes.home,
        builder: (context, state) => const MyHomePage(title: 'Mawa ERP'),
      ),
      GoRoute(
        path: AppRoutes.featureGroup,
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
        path: AppRoutes.membershipPlans,
        builder: (context, state) => const MembershipPlanListScreen(),
      ),
      GoRoute(
        path: AppRoutes.membershipClaims,
        builder: (context, state) => const MembershipClaimListScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupSocieties,
        builder: (context, state) => const GroupSocietyListScreen(),
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
        path: AppRoutes.paymentRequests,
        builder: (context, state) => const PaymentRequestListScreen(),
      ),
      GoRoute(
        path: AppRoutes.cashups,
        builder: (context, state) => const CashupListScreen(),
      ),
      GoRoute(
        path: AppRoutes.apiLogs,
        builder: (context, state) => const ApiLogListScreen(),
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
        path: AppRoutes.partners,
        builder: (context, state) => const PartnerListScreen(
          title: 'Business Partners',
          allowCreate: true,
        ),
      ),
      GoRoute(
        path: '/partners/:role',
        builder: (context, state) {
          final rawRole = state.pathParameters['role']!;
          final role = rawRole.replaceAll('-', '_').toUpperCase();
          final title = _partnerTitleForRole(role, rawRole);
          return PartnerListScreen(
            role: role == 'BUSINESS_PARTNER' ? null : role,
            title: title,
            allowCreate: role == 'BUSINESS_PARTNER',
          );
        },
      ),

      GoRoute(
        path: AppRoutes.appointments,
        builder: (context, state) => const AppointmentCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (context, state) => const AppointmentCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.approvals,
        builder: (context, state) => const ApprovalListScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SystemConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.products,
        builder: (context, state) => const ProductMaintenanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.fnbIntegrationAdmin,
        builder: (context, state) => const FnbIntegrationAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.messageQueueAdmin,
        builder: (context, state) => const MessageQueueAdminScreen(),
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
        builder: (context, state) => const Scaffold(body: Center(child: Text('Funeral Payments List'))),
      ),
      GoRoute(
        path: AppRoutes.funeralPackageSetup,
        builder: (context, state) => const FuneralPackageSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.funeralAllClaims,
        builder: (context, state) => const Scaffold(body: Center(child: Text('All Funeral Claims List'))),
      ),
    ],
  );
}
