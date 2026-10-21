import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mawa_erp/core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

/// Tenant-wide accounting access, independent of any Xero connection.
class RoleVatPermissionScreen extends StatefulWidget {
  final String roleId;
  const RoleVatPermissionScreen({super.key, required this.roleId});

  @override
  State<RoleVatPermissionScreen> createState() => _RoleVatPermissionScreenState();
}

class _RoleVatPermissionScreenState extends State<RoleVatPermissionScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = true, _saving = false, _canView = false, _canManage = false;
  String? _error;
  String get _path => '/v2/role/${Uri.encodeComponent(widget.roleId)}/vat-permissions';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _api.get(_path);
      if (response.statusCode != 200) throw AppException(response.body);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _canView = data['canView'] == true;
        _canManage = data['canManage'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyErrorMessage(e); });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final response = await _api.put(_path, body: {
        'canView': _canView, 'canManage': _canManage,
      });
      if (response.statusCode != 200) throw AppException(response.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VAT role permissions saved')),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('VAT permissions · ${widget.roleId}')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(16), children: [
          if (_error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          SwitchListTile(
            title: const Text('View VAT Configuration'),
            subtitle: const Text('View the tenant VAT policy and history'),
            value: _canView,
            onChanged: _saving ? null : (value) => setState(() {
              _canView = value;
              if (!value) _canManage = false;
            }),
          ),
          SwitchListTile(
            title: const Text('Manage VAT Configuration'),
            subtitle: const Text('Create future-effective tenant VAT policies'),
            value: _canManage,
            onChanged: _saving ? null : (value) => setState(() {
              _canManage = value;
              if (value) _canView = true;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('SAVE PERMISSIONS'),
          ),
        ]),
  );
}
