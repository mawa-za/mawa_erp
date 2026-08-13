import 'package:flutter/material.dart';

import '../models/role.dart';
import '../services/role_service.dart';
import 'role_workcenter_assignment_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class RoleListScreen extends StatefulWidget {
  const RoleListScreen({super.key});

  @override
  State<RoleListScreen> createState() => _RoleListScreenState();
}

class _RoleListScreenState extends State<RoleListScreen> {
  final RoleService _service = RoleService();
  bool _loading = true;
  String? _error;
  List<Role> _roles = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await _service.getRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _edit([Role? existing]) async {
    final idController = TextEditingController(text: existing?.id ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    bool accessAll = existing?.accessAllWorkcentres ?? false;
    bool protectedRole = existing?.protectedRole ?? false;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Create role' : 'Edit ${existing.id}'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'Role ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  value: accessAll,
                  onChanged: existing?.systemRole == true ||
                          existing?.protectedRole == true
                      ? null
                      : (value) =>
                          setLocalState(() => accessAll = value),
                  title: const Text(
                    'Access all current and future workcentres',
                  ),
                ),
                SwitchListTile(
                  value: protectedRole,
                  onChanged: existing?.systemRole == true
                      ? null
                      : (value) =>
                          setLocalState(() => protectedRole = value),
                  title: const Text('Protected role'),
                  subtitle: const Text(
                    'Cannot be deleted; removing the final protected '
                    'assignment is blocked.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    try {
      final role = Role(
        id: idController.text.trim().toUpperCase(),
        description: descriptionController.text.trim(),
        systemRole: existing?.systemRole ?? false,
        protectedRole: protectedRole,
        accessAllWorkcentres: accessAll,
      );
      if (existing == null) {
        await _service.createRole(role);
      } else {
        await _service.updateRole(role);
      }
      await _load();
    } catch (error) {
      _show(error);
    }
  }

  Future<void> _delete(Role role) async {
    if (role.systemRole || role.protectedRole) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete role'),
        content: Text('Delete ${role.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _service.deleteRole(role.id);
      await _load();
    } catch (error) {
      _show(error);
    }
  }

  List<Role> get _visibleRoles {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _roles;
    return _roles.where((role) => [role.id, role.description]
        .join(' ')
        .toLowerCase()
        .contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roles = _visibleRoles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Maintenance'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('ROLE'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search roles',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: roles.isEmpty
                          ? const Center(child: Text('No roles match your search'))
                          : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            role.accessAllWorkcentres
                                ? Icons.all_inclusive
                                : Icons.admin_panel_settings,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                role.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (role.systemRole)
                              _badge('SYSTEM', Colors.blue),
                            if (role.protectedRole)
                              _badge('PROTECTED', Colors.green),
                            if (role.accessAllWorkcentres)
                              _badge('ALL WORKCENTRES', Colors.purple),
                          ],
                        ),
                        subtitle: Text(
                          '${role.description}\n'
                          '${role.accessAllWorkcentres ? 'Automatically includes future workcentres' : 'Configured through role workcentre maintenance'}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoleWorkcenterAssignmentScreen(
                              role: role,
                            ),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _edit(role);
                            if (value == 'delete') _delete(role);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit role'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              enabled: !role.systemRole && !role.protectedRole,
                              child: const Text('Delete role'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                    ),
                  ],
                ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  void _show(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyErrorMessage('$error')),
        backgroundColor: Colors.red,
      ),
    );
  }
}
