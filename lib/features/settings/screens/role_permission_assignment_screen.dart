import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';
import '../models/role.dart';
import '../models/role_permission.dart';
import '../services/role_service.dart';

/// Business actions are managed independently from navigable workcentres.
class RolePermissionAssignmentScreen extends StatefulWidget {
  final Role role;
  const RolePermissionAssignmentScreen({super.key, required this.role});

  @override
  State<RolePermissionAssignmentScreen> createState() => _RolePermissionAssignmentScreenState();
}

class _RolePermissionAssignmentScreenState extends State<RolePermissionAssignmentScreen> {
  final RoleService _roles = RoleService();
  List<RolePermission> _catalogue = [];
  Set<String> _assigned = {};
  String _search = '';
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final catalogue = await _roles.getAllPermissions();
      final assigned = await _roles.getRolePermissions(widget.role.id);
      if (!mounted) return;
      setState(() {
        _catalogue = catalogue;
        _assigned = assigned.intersection(catalogue.map((p) => p.code).toSet());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyErrorMessage(e); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await _roles.saveRolePermissions(widget.role.id, _assigned);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business permissions saved')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _catalogue.where((p) => [p.code, p.description, p.details, p.groupTitle]
        .join(' ').toLowerCase().contains(_search.toLowerCase())).toList();
    final groups = <String, List<RolePermission>>{};
    for (final permission in filtered) {
      groups.putIfAbsent(permission.groupTitle, () => []).add(permission);
    }
    return Scaffold(
      appBar: AppBar(title: Text('Permissions · ${widget.role.id}'), actions: [
        IconButton(onPressed: _loading || _saving ? null : _load, icon: const Icon(Icons.refresh)),
        TextButton(onPressed: _loading || _saving || _error != null ? null : _save,
            child: const Text('SAVE')),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(16), children: [
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
          'Permissions control actions within accessible workcentres. '
          'They do not create navigation cards. Sensitive actions require explicit grants; '
          'approval workflows remain separate. Only protected tenant administrators can save changes.',
        ))),
        if (_error != null) Padding(padding: const EdgeInsets.all(12),
          child: Text(_error!, style: const TextStyle(color: Colors.red))),
        TextField(decoration: const InputDecoration(
          labelText: 'Search permissions', prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ), onChanged: (text) => setState(() => _search = text)),
        const SizedBox(height: 12),
        for (final entry in groups.entries)
          Card(child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${entry.value.where((p) => _assigned.contains(p.code)).length} of ${entry.value.length} granted'),
            children: (entry.value..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
                .map((permission) => CheckboxListTile(
                  value: _assigned.contains(permission.code),
                  onChanged: _saving ? null : (value) => setState(() {
                    if (value == true) { _assigned.add(permission.code); }
                    else { _assigned.remove(permission.code); }
                  }),
                  title: Text(permission.description),
                  subtitle: Text('${permission.details}\n${permission.code}'),
                  isThreeLine: true,
                  secondary: permission.sensitive
                      ? const Tooltip(message: 'Sensitive business action', child: Icon(Icons.security, color: Colors.deepOrange))
                      : const Icon(Icons.verified_user_outlined),
                )).toList(),
          )),
        if (groups.isEmpty && _error == null)
          const Padding(padding: EdgeInsets.all(16), child: Text('No permissions match the search.')),
      ]),
      floatingActionButton: _loading || _saving || _error != null ? null :
        FloatingActionButton.extended(onPressed: _save, icon: const Icon(Icons.save),
          label: const Text('SAVE PERMISSIONS')),
    );
  }
}
