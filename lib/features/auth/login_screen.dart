import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/services/field_service.dart';
import '../../core/services/access_profile_service.dart';
import '../../core/theme/mawa_design.dart';
import '../../core/widgets/app_feedback.dart';
import '../settings/models/role.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiHost;
      String tenantId;

      if (kIsWeb) {
        apiHost = Config.apiHost;
        final tenantFromAddress = Config.webTenant;
        final storedTenant = (prefs.getString('tenant') ?? '').trim();
        tenantId = tenantFromAddress.isNotEmpty ? tenantFromAddress : storedTenant;
        if (Config.isSharedApplicationHost(tenantId)) tenantId = '';
      } else {
        apiHost = prefs.getString('api_host') ?? '';
        tenantId = prefs.getString('tenant') ?? '';
      }

      if (tenantId.trim().isEmpty) {
        throw AppException(
          'This MAWA address does not identify a tenant. Open the tenant-specific link or launch MAWA from the Admin portal.',
        );
      }

      final url = Uri.parse('https://$apiHost/v2/authenticate');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-TenantID': tenantId,
              'X-Tenant-Id': tenantId,
            },
            body: jsonEncode({
              'username': _usernameController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final userId = data['userId']?.toString() ?? '';
        final accessToken = (data['accessToken'] ?? data['token'])?.toString() ?? '';
        final refreshToken = data['refreshToken']?.toString() ?? '';
        final username = (data['username'] ?? _usernameController.text.trim()).toString();
        final displayName = (data['displayName'] ?? '').toString();
        final resolvedTenantId = (data['tenantId'] ?? data['tenant_id'] ?? '').toString().trim();

        await prefs.setString('userId', userId);
        if (resolvedTenantId.isNotEmpty) {
          await prefs.setString('tenant', resolvedTenantId);
        }
        await prefs.setString('username', username);
        await prefs.setString('displayName', displayName);
        await prefs.setString('accessToken', accessToken);
        await prefs.setString('refreshToken', refreshToken);
        await AccessProfileService().persistAuthentication(
          Map<String, dynamic>.from(data as Map),
        );
        try {
          await AccessProfileService().getProfile();
        } catch (e) {
          debugPrint('Failed to load access profile after login: $e');
        }

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
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: response.statusCode == 401 || response.statusCode == 403
              ? 'The username or password is incorrect.'
              : 'We could not sign you in. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      if (mounted) {
        AppFeedback.showError(
          context,
          e,
          fallback: 'We could not sign you in. Please try again.',
        );
      }
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
    final width = MediaQuery.sizeOf(context).width;
    final showBrandPanel = width >= 980;

    return Scaffold(
      backgroundColor: MawaDesign.page,
      body: Row(
        children: [
          if (showBrandPanel)
            Expanded(
              flex: 5,
              child: Container(
                height: double.infinity,
                padding: const EdgeInsets.all(56),
                color: MawaDesign.navy,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/branding/mawa_logo_white.png',
                        height: 48,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                      const Spacer(),
                      Text(
                        'One platform for the work\nthat matters every day.',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 38,
                              height: 1.16,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Manage memberships, funeral arrangements, finance, inventory and operations with clarity.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFCBD5E1),
                              height: 1.6,
                            ),
                      ),
                      const SizedBox(height: 34),
                      const _LoginFeature(
                        icon: Icons.grid_view_rounded,
                        text: 'Role-based workcenters',
                      ),
                      const SizedBox(height: 14),
                      const _LoginFeature(
                        icon: Icons.verified_user_outlined,
                        text: 'Secure business processes',
                      ),
                      const SizedBox(height: 14),
                      const _LoginFeature(
                        icon: Icons.insights_outlined,
                        text: 'Operational visibility',
                      ),
                      const Spacer(),
                      const Text(
                        'Trusted technology for communities that matter.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            flex: showBrandPanel ? 4 : 1,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(34),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!showBrandPanel) ...[
                              Image.asset(
                                'assets/branding/mawa_logo.png',
                                height: 52,
                              ),
                              const SizedBox(height: 24),
                            ],
                            Text(
                              'Welcome back',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue to MAWA.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: MawaDesign.textMuted,
                                  ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) => value?.trim().isEmpty ?? true
                                  ? 'Please enter your username'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _isLoading ? null : _login(),
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please enter your password'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'MAWA • v1.0.9+10',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MawaDesign.textMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _LoginFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LoginFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
