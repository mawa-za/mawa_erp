import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/session_service.dart';

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
      final response = await ApiClient().post(
        '/v2/admin-handoff/exchange',
        body: {'token': handoffToken},
        includeRole: false,
      );

      if (response.statusCode != 200) {
        setState(() => _error = response.body.isNotEmpty
            ? response.body
            : 'Admin handoff failed with HTTP ${response.statusCode}.');
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
      await prefs.setString('selectedRole', 'SYSTEM');
      await prefs.setString('selectedRoleDescription', 'System Support');
      await prefs.setBool('adminHandoffSession', true);

      SessionService().startMonitoring();

      if (!mounted) return;
      final redirect = widget.redirectPath.trim().isEmpty ? AppRoutes.home : widget.redirectPath.trim();
      context.go(redirect.startsWith('/') ? redirect : '/$redirect');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Admin handoff failed: $e');
      }
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
