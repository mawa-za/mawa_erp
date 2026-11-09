import 'package:flutter/material.dart';
import '../models/role.dart';
import 'role_permission_assignment_screen.dart';
import 'role_workcenter_assignment_screen.dart';

/// Role access is configured in two independent sections.
class RoleAccessManagementScreen extends StatelessWidget {
  final Role role;
  const RoleAccessManagementScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Role Access · ${role.id}')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(role.description, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: const Icon(Icons.apps_outlined, size: 30),
        title: const Text('Workcentres'),
        subtitle: const Text('Choose the screens shown in navigation. This does not grant sensitive actions.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => RoleWorkcenterAssignmentScreen(role: role),
        )),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined, size: 30),
        title: const Text('Permissions'),
        subtitle: const Text('Choose the business actions allowed within workcentres.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => RolePermissionAssignmentScreen(role: role),
        )),
      )),
    ]),
  );
}
