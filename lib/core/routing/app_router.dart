import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import 'route_guards.dart';

import '../../features/setup/setup_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/home/home_page.dart';
import '../../features/membership/screens/membership_detail_screen.dart';
import '../../features/membership/screens/member_list_screen.dart';
import '../../features/invoicing/screens/invoice_pdf_preview_screen.dart';
import '../../features/invoicing/screens/invoice_list_screen.dart';
import '../../features/cases/screens/case_list_screen.dart';
import '../../features/cases/screens/create_case_screen.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/cases/screens/case_detail_shell_screen.dart';
import '../../features/approvals/screens/approval_list_screen.dart';
import '../../features/settings/screens/system_configuration_screen.dart';

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
          final role = state.pathParameters['role']!;
          return PartnerListScreen(
            role: role,
            title: '${role[0]}${role.substring(1).toLowerCase()}s',
            allowCreate: false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.approvals,
        builder: (context, state) => const ApprovalListScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SystemConfigurationScreen(),
      ),
    ],
  );
}
