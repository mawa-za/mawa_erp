import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/services/field_service.dart';
import '../settings/models/role.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiHost;
      String tenantId;

      if (kIsWeb) {
        apiHost = Config.apiHost;
        tenantId = Config.webTenant;
      } else {
        apiHost = prefs.getString('api_host') ?? '';
        tenantId = prefs.getString('tenant') ?? '';
      }

      final url = Uri.parse('https://$apiHost/v2/authenticate');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TenantID': tenantId,
        },
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final userId = data['userId']?.toString() ?? '';
        final accessToken = (data['accessToken'] ?? data['token'])?.toString() ?? '';
        final refreshToken = data['refreshToken']?.toString() ?? '';
        final username = (data['username'] ?? _usernameController.text.trim()).toString();
        final displayName = (data['displayName'] ?? '').toString();

        await prefs.setString('userId', userId);
        await prefs.setString('username', username);
        await prefs.setString('displayName', displayName);
        await prefs.setString('accessToken', accessToken);
        await prefs.setString('refreshToken', refreshToken);

        _prefetchFieldOptions();

        try {
          final rolesResponse = await ApiClient().get('/v2/user/$userId/role');
          if (rolesResponse.statusCode == 200) {
            final List<dynamic> rolesData = jsonDecode(rolesResponse.body);
            final List<Role> roleList = rolesData.map((e) {
              if (e is String) {
                return Role(id: e, description: e);
              }
              return Role.fromJson(e as Map<String, dynamic>);
            }).toList();

            if (roleList.length > 1) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RoleSelectionScreen(
                      roles: roleList,
                      onRoleSelected: () {
                        Navigator.of(context).pop();
                        widget.onLoggedIn();
                      },
                    ),
                  ),
                );
              }
            } else if (roleList.length == 1) {
              final role = roleList.first;
              await prefs.setString('selectedRole', role.id);
              await prefs.setString('selectedRoleDescription', role.description);
              widget.onLoggedIn();
            } else {
              widget.onLoggedIn();
            }
          } else {
            debugPrint('Failed to fetch roles: ${rolesResponse.statusCode} ${rolesResponse.body}');
            widget.onLoggedIn();
          }
        } catch (e) {
          debugPrint('Failed to fetch roles after login: $e');
          widget.onLoggedIn();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prefetchFieldOptions() {
    () async {
      try {
        await FieldService().getOptions();
      } catch (e) {
        debugPrint('Failed to prefetch field options: $e');
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/branding/mawa_logo.png', height: 72, fit: BoxFit.contain),
                          const SizedBox(height: 8),
                          Text(
                            'Login to continue',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 48),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                );
                              },
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    backgroundColor: const Color(0xFFE53935),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'v1.0.0+1',
                style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
