import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'user_list_screen.dart';
import 'company_info_screen.dart';
import 'role_list_screen.dart';
import 'field_option_list_screen.dart';
import 'api_log_list_screen.dart';
import '../../approvals/screens/approval_workflow_list_screen.dart';
import '../../membership/screens/membership_plan_list_screen.dart';
import '../../products/screens/product_maintenance_screen.dart';
import '../../integrations/fnb/fnb_integration_admin_screen.dart';
import '../../admin/message_queue/message_queue_admin_screen.dart';
import 'scheduler_configuration_screen.dart';

class SystemConfigurationScreen extends StatelessWidget {
  const SystemConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('System Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConfigTile(
            context,
            title: 'System Parameters',
            subtitle: 'Manage global system settings and constants',
            icon: Icons.settings_applications_outlined,
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemSettingsScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Field Options',
            subtitle: 'Manage dropdown lists and field values',
            icon: Icons.list_alt_outlined,
            color: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FieldOptionListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Role Management',
            subtitle: 'Manage system roles and access levels',
            icon: Icons.admin_panel_settings_outlined,
            color: Colors.red,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Approval Workflows',
            subtitle: 'Configure multi-level approval processes',
            icon: Icons.account_tree_outlined,
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ApprovalWorkflowListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'User Management',
            subtitle: 'Manage system users and permissions',
            icon: Icons.people_outline,
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'FNB Integration',
            subtitle: 'Maintain FNB API credentials, debtor account and enablement',
            icon: Icons.account_balance_outlined,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FnbIntegrationAdminScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Scheduled Jobs',
            subtitle: 'Configure automated backend jobs and run windows',
            icon: Icons.schedule_outlined,
            color: Colors.deepOrange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedulerConfigurationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Message Queue Processing',
            subtitle: 'Monitor pending messages, retry failures and trigger processing',
            icon: Icons.queue_outlined,
            color: Colors.blueGrey,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessageQueueAdminScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'API Activity Logs',
            subtitle: 'Monitor backend requests and system performance',
            icon: Icons.api_outlined,
            color: Colors.brown,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ApiLogListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Product Maintenance',
            subtitle: 'Configure products, funeral extras, packages and pricing',
            icon: Icons.inventory_2_outlined,
            color: Colors.cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductMaintenanceScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Membership Plans',
            subtitle: 'Configure membership plans, premiums and claim payouts',
            icon: Icons.card_membership_outlined,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MembershipPlanListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Company Profile',
            subtitle: 'Manage company information and branding',
            icon: Icons.business_outlined,
            color: Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyInfoScreen(isReadOnly: false))),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
