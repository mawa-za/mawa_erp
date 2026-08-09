import 'dart:async';
import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/services/session_service.dart';
import 'core/routing/app_router.dart';
import 'core/routing/route_guards.dart';
import 'core/theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _logoutSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _logoutSubscription = ApiClient().logoutStream.listen((sessionExpired) {
      if (mounted) {
        SessionService().stopMonitoring();
        // GoRouter will handle redirection via its own logic if we trigger a refresh
        // but for now we can also force a refresh or rely on the next navigation
        if (sessionExpired) {
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Session expired. Please login again.')),
            );
        }
        // We can use the global navigator key if needed, or just let the router handle it
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    if (await RouteGuards.isAuthenticated()) {
      SessionService().startMonitoring();
    }
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'mawa',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) => SessionService().userActivityDetected(),
          onPointerMove: (_) => SessionService().userActivityDetected(),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox.expand(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
