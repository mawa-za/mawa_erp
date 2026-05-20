import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/services/session_service.dart';
import 'features/setup/setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/home/home_page.dart';
import 'features/invoicing/screens/invoice_pdf_preview_screen.dart';
import 'features/membership/screens/membership_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mawa ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) => SessionService().userActivityDetected(),
          onPointerMove: (_) => SessionService().userActivityDetected(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        final uri = Uri.base;
        
        // Handle /reset-password?token=...
        if (uri.path.contains('reset-password')) {
          final token = uri.queryParameters['token'];
          if (token != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token),
            );
          }
        }

        // Handle /membership-detail?id=...
        if (uri.path.contains('membership-detail')) {
          final id = uri.queryParameters['id'];
          if (id != null) {
            return MaterialPageRoute(
              builder: (context) => Initializer(membershipId: id),
            );
          }
        }

        // Handle /invoice-preview?id=...
        if (uri.path.contains('invoice-preview')) {
          final id = uri.queryParameters['id'];
          if (id != null) {
            return MaterialPageRoute(
              builder: (context) => Initializer(targetId: id),
            );
          }
        }

        return MaterialPageRoute(
          builder: (context) => const Initializer(),
        );
      },
    );
  }
}

class Initializer extends StatefulWidget {
  final String? targetId;
  final String? membershipId;
  const Initializer({super.key, this.targetId, this.membershipId});

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  bool _isLoading = true;
  bool _isConfigured = false;
  bool _isLoggedIn = false;
  StreamSubscription? _logoutSubscription;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _logoutSubscription = ApiClient().logoutStream.listen((_) {
      if (mounted) {
        SessionService().stopMonitoring();
        setState(() {
          _isLoggedIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    final tenant = prefs.getString('tenant');
    final apiHost = prefs.getString('api_host');
    final token = prefs.getString('accessToken');

    final isLoggedIn = token != null && token.isNotEmpty;

    setState(() {
      if (kIsWeb) {
        _isConfigured = true;
      } else {
        _isConfigured = tenant != null && apiHost != null;
      }
      
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });

    if (isLoggedIn) {
      SessionService().startMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Allow viewing an invoice even if not configured/logged in
    if (widget.targetId != null) {
      return InvoicePdfPreviewScreen(invoiceId: widget.targetId);
    }

    if (!_isConfigured) {
      return SetupScreen(onConfigured: () {
        setState(() => _isConfigured = true);
      });
    }

    if (!_isLoggedIn) {
      return LoginScreen(onLoggedIn: () {
        SessionService().startMonitoring();
        setState(() => _isLoggedIn = true);
      });
    }

    // If logged in and we have a membership ID, go straight to details
    if (widget.membershipId != null) {
      return MembershipDetailScreen(membershipId: widget.membershipId!);
    }

    return const MyHomePage(title: 'Mawa ERP');
  }
}
