import 'package:flutter/material.dart';
import 'user_list_screen.dart';
import 'company_info_screen.dart';
import 'role_list_screen.dart';
import 'field_option_list_screen.dart';
import 'api_log_list_screen.dart';
import '../../approvals/screens/approval_workflow_list_screen.dart';
import '../../membership/screens/membership_plan_list_screen.dart';
import '../../integrations/fnb/fnb_integration_admin_screen.dart';
import '../../admin/message_queue/message_queue_admin_screen.dart';
import 'xero_integration_screen.dart';
import '../../funeral/presentation/pages/funeral_tenant_integration_setup_page.dart';
import '../../funeral/presentation/pages/trusted_tenants_page.dart';
import 'pos_printing_settings_screen.dart';
import 'manual_receipt_cutover_settings_screen.dart';
import 'manual_receipt_book_maintenance_screen.dart';
import '../../funeral/presentation/pages/third_party_funeral_underwriter_configuration_page.dart';
import 'premium_generation_settings_screen.dart';
import 'membership_lapse_settings_screen.dart';
import '../../payments/screens/payment_account_configuration_screen.dart';
import 'number_range_configuration_screen.dart';
import 'storage_configuration_screen.dart';
import 'claim_type_configuration_screen.dart';
import 'membership_policy_configuration_screen.dart';
import '../../forms/company_form_configuration_screen.dart';
import 'payment_request_invoice_email_configuration_screen.dart';
import 'signiflow_configuration_screen.dart';

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
            title: 'Warehouse & Storage',
            subtitle: 'Configure reusable warehouses, storage locations and bins',
            icon: Icons.warehouse_outlined,
            color: Colors.brown,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageConfigurationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Claim Types',
            subtitle: 'Choose which claim types are available during claim processing',
            icon: Icons.fact_check_outlined,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimTypeConfigurationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Membership Policy',
            subtitle: 'Control multiple memberships and additional-membership approval',
            icon: Icons.card_membership_outlined,
            color: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipPolicyConfigurationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Company Forms',
            subtitle: 'Upload and replace centrally published forms',
            icon: Icons.description_outlined,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyFormConfigurationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'FNB Integration',
            subtitle: 'Activate and configure FNB payment processing',
            icon: Icons.account_balance_outlined,
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FnbIntegrationAdminScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Xero Integration',
            subtitle: 'Activate Xero and select the invoice organisation',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const XeroIntegrationScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Message Queue Processing',
            subtitle: 'Schedule, start, stop and monitor message queue processing',
            icon: Icons.queue_outlined,
            color: Colors.blueGrey,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MessageQueueAdminScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(context,title:'Payment Accounts',subtitle:'Configure debtor accounts by payment type and petty-cash/cash-claim creditor accounts',icon:Icons.account_balance_wallet_outlined,color:Colors.teal,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PaymentAccountConfigurationScreen()))),
          const SizedBox(height:12),
          _buildConfigTile(context,title:'Automatic Premium Generation',subtitle:'Choose the monthly generation date and backfill six missing periods',icon:Icons.calendar_month_outlined,color:Colors.indigo,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumGenerationSettingsScreen()))),
          const SizedBox(height:12),
          _buildConfigTile(
            context,
            title: 'Membership Lapse Configuration',
            subtitle: 'Lapse active memberships after a configured number of consecutive missed premiums',
            icon: Icons.event_busy_outlined,
            color: Colors.deepOrange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MembershipLapseSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Funeral Cover Underwriter Configuration',
            subtitle: 'Maintain the organisations that underwrite third-party funeral cover',
            icon: Icons.business_center_outlined,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ThirdPartyFuneralUnderwriterConfigurationPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Payment Request Invoice Email',
            subtitle: 'Email approved supplier invoice attachments and run the once-off backfill',
            icon: Icons.attach_email_outlined,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentRequestInvoiceEmailConfigurationScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'SigniFlow Electronic Signatures',
            subtitle: 'Configure electronic signing of generated claim forms',
            icon: Icons.draw_outlined,
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SigniFlowConfigurationScreen()),
            ),
          ),
          const SizedBox(height:12),
          _buildConfigTile(
            context,
            title: 'Manual Receipt Books',
            subtitle: 'Maintain valid receipt-book numbers, ranges and assignments',
            icon: Icons.menu_book_outlined,
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualReceiptBookMaintenanceScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Manual Receipt Cutover',
            subtitle: 'Configure MAWAPay go-live, legacy catch-up and emergency receipt rules',
            icon: Icons.receipt_long_outlined,
            color: Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualReceiptCutoverSettingsScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'POS Printing',
            subtitle: 'Pair terminals, Windows agents and receipt printers',
            icon: Icons.point_of_sale_outlined,
            color: Colors.deepOrange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PosPrintingSettingsScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Number Range Configuration',
            subtitle: 'Manage operational sequences, document ranges and device allocations',
            icon: Icons.format_list_numbered_rounded,
            color: Colors.cyan,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NumberRangeConfigurationScreen()),
            ),
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
            title: 'API Activity Logs',
            subtitle: 'Monitor backend requests and system performance',
            icon: Icons.api_outlined,
            color: Colors.brown,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ApiLogListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Membership Plans',
            subtitle: 'Configure products, plans and pricing',
            icon: Icons.card_membership_outlined,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MembershipPlanListScreen())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Trusted Tenants',
            subtitle: 'Request, approve, suspend or revoke cross-tenant access',
            icon: Icons.verified_user_outlined,
            color: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrustedTenantsPage())),
          ),
          const SizedBox(height: 12),
          _buildConfigTile(
            context,
            title: 'Funeral Tenant Integration',
            subtitle: 'Configure local and external membership and claim sources',
            icon: Icons.hub_outlined,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const FuneralTenantIntegrationSetupPage(),
              ),
            ),
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
