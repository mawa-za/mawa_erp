import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/setup/setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_page.dart';

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
      home: const Initializer(),
    );
  }
}

class Initializer extends StatefulWidget {
  const Initializer({super.key});

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  bool _isLoading = true;
  bool _isConfigured = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    final tenant = prefs.getString('tenant');
    final apiHost = prefs.getString('api_host');
    final token = prefs.getString('accessToken');

    setState(() {
      if (kIsWeb) {
        _isConfigured = true;
      } else {
        _isConfigured = tenant != null && apiHost != null;
      }
      
      _isLoggedIn = token != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isConfigured) {
      return SetupScreen(onConfigured: () {
        setState(() => _isConfigured = true);
      });
    }

    if (!_isLoggedIn) {
      return LoginScreen(onLoggedIn: () {
        setState(() => _isLoggedIn = true);
      });
    }

    return const MyHomePage(title: 'Mawa ERP');
  }
}
