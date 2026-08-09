import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/session_service.dart';
import '../../core/services/access_profile_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AdminHandoffScreen extends StatefulWidget {
  final String token;
  final String redirectPath;

  const AdminHandoffScreen({
    super.key,
    required this.token,
    required this.redirectPath,
  });

  @override
  State<AdminHandoffScreen> createState() => _AdminHandoffScreenState();
}

class _AdminHandoffScreenState extends State<AdminHandoffScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _exchangeToken();
  }

  Future<void> _exchangeToken() async {
    final handoffToken = widget.token.trim();
    if (handoffToken.isEmpty) {
      setState(() => _error = 'Admin handoff token is missing.');
      return;
    }

    try {
      final response = await ApiClient().postPublic(
        '/v2/admin-handoff/exchange',
        body: {'token': handoffToken},
        // This value is used only to route the exchange request to the tenant
        // schema. Authentication and all claims are still validated by the
        // backend using the signed, short-lived handoff token.
        tenantOverride: _tenantRoutingClaim(handoffToken),
      );

      if (response.statusCode != 200) {
        setState(
          () => _error = friendlyErrorMessage(
            response.body,
            statusCode: response.statusCode,
            fallback: 'The secure admin session could not be opened. Please try again.',
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      final tokenContainer = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;

      final accessToken = _readString(tokenContainer, const [
        'accessToken',
        'access_token',
        'token',
        'jwt',
      ]);
      final refreshToken = _readString(tokenContainer, const [
        'refreshToken',
        'refresh_token',
        'refresh',
      ]);
      final userId = _readString(tokenContainer, const ['userId', 'user_id', 'id']) ?? '';
      final username = _readString(tokenContainer, const ['username']) ?? 'system';
      final displayName = _readString(tokenContainer, const ['displayName', 'display_name']) ?? 'Support Admin';
      final roleId = _readString(tokenContainer, const ['roleId', 'role_id']) ?? 'SUPPORT_VERIFICATION';
      final roleDescription = _readString(tokenContainer, const ['roleDescription', 'role_description']) ?? roleId;

      if (accessToken == null || accessToken.isEmpty) {
        setState(() => _error = 'Admin handoff did not return an access token.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refreshToken', refreshToken);
      }
      await prefs.setString('userId', userId);
      await prefs.setString('username', username);
      await prefs.setString('displayName', displayName);
      final tenantId = _readString(tokenContainer, const ['tenantId', 'tenant_id', 'tenant']);
      if (tenantId != null && tenantId.isNotEmpty) {
        await prefs.setString('tenant', tenantId);
      }
      await prefs.setString('selectedRole', roleId);
      await prefs.setString('selectedRoleDescription', roleDescription);
      await prefs.setBool('adminHandoffSession', true);
      await AccessProfileService().persistAuthentication(tokenContainer);
      try {
        await AccessProfileService().getProfile();
      } catch (_) {
        // The handoff response itself still contains enough metadata to render
        // the protected platform-session warning banner.
      }

      SessionService().startMonitoring();

      if (!mounted) return;
      final redirect = widget.redirectPath.trim().isEmpty ? AppRoutes.home : widget.redirectPath.trim();
      context.go(redirect.startsWith('/') ? redirect : '/$redirect');
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage('Admin handoff failed: $e'));
      }
    }
  }

  String? _tenantRoutingClaim(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final claims = Map<String, dynamic>.from(decoded);
      return _readString(claims, const [
        'tenant-id',
        'tenant',
        'tenant_id',
        'tenantId',
        'tenant_host',
        'tenantHost',
        'aud',
      ]);
    } catch (_) {
      return null;
    }
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _error == null ? Icons.admin_panel_settings_rounded : Icons.error_outline_rounded,
                    size: 56,
                    color: _error == null ? const Color(0xFFF20D1A) : Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error == null ? 'Opening tenant ERP...' : 'Admin handoff failed',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (_error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text(
                      'Validating the short-lived support token and creating a scoped ERP session.',
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Go to login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
