import 'package:flutter/material.dart';
import '../models/role.dart';
import '../services/role_service.dart';
import 'role_workcenter_assignment_screen.dart';

class RoleListScreen extends StatefulWidget {
  const RoleListScreen({super.key});

  @override
  State<RoleListScreen> createState() => _RoleListScreenState();
}

class _RoleListScreenState extends State<RoleListScreen> {
  final RoleService _roleService = RoleService();
  bool _isLoading = true;
  List<Role> _roles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final roles = await _roleService.getRoles();
      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateRoleDialog() async {
    final idController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Role'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Role ID',
                  hintText: 'e.g. MANAGER',
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Store Manager',
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _roleService.createRole(Role(
          id: idController.text.trim().toUpperCase(),
          description: descController.text.trim(),
        ));
        _fetchRoles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteRole(Role role) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete the role "${role.id}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _roleService.deleteRole(role.id);
        _fetchRoles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Role Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRoles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchRoles, child: const Text('Retry')),
                    ],
                  ),
                )
              : _roles.isEmpty
                  ? const Center(child: Text('No roles found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        final role = _roles[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.admin_panel_settings_outlined),
                            ),
                            title: Text(role.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(role.description),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RoleWorkcenterAssignmentScreen(role: role),
                                      ),
                                    );
                                  },
                                  tooltip: 'Assign Workcenters',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteRole(role),
                                  tooltip: 'Delete Role',
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoleWorkcenterAssignmentScreen(role: role),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRoleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
