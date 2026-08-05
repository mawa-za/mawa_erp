import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';

import '../../../core/theme/mawa_design.dart';
import '../../../core/widgets/mawa_ui.dart';
import '../../admin/message_queue/message_queue_admin_screen.dart';
import '../../device_sync/screens/device_sync_workcenter_screen.dart';
import '../../approvals/screens/approval_workflow_list_screen.dart';
import '../../forms/company_form_configuration_screen.dart';
import '../../funeral/presentation/pages/funeral_package_setup_page.dart';
import '../../funeral/presentation/pages/funeral_tenant_integration_setup_page.dart';
import '../../funeral/presentation/pages/third_party_funeral_underwriter_configuration_page.dart';
import '../../funeral/presentation/pages/trusted_tenants_page.dart';
import '../../integrations/fnb/fnb_integration_admin_screen.dart';
import '../../leave_management/screens/leave_configuration_screen.dart';
import '../../membership/screens/membership_plan_list_screen.dart';
import '../../payments/screens/payment_account_configuration_screen.dart';
import 'api_log_list_screen.dart';
import 'claim_type_configuration_screen.dart';
import 'company_info_screen.dart';
import 'field_option_list_screen.dart';
import 'manual_receipt_book_maintenance_screen.dart';
import 'manual_receipt_cutover_settings_screen.dart';
import 'membership_lapse_settings_screen.dart';
import 'membership_policy_configuration_screen.dart';
import 'number_range_configuration_screen.dart';
import 'payment_request_invoice_email_configuration_screen.dart';
import 'pos_printing_settings_screen.dart';
import 'premium_generation_settings_screen.dart';
import 'purple_configuration_screen.dart';
import 'role_list_screen.dart';
import 'signiflow_configuration_screen.dart';
import 'storage_configuration_screen.dart';
import 'user_list_screen.dart';
import 'xero_integration_screen.dart';

class SystemConfigurationScreen extends StatefulWidget {
  const SystemConfigurationScreen({super.key});

  @override
  State<SystemConfigurationScreen> createState() =>
      _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchTerm = '';
  _ConfigurationCategory? _selectedCategory;
  bool _canConfigureApprovalWorkflows = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadApprovalWorkflowAccess();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _searchTerm) return;
    setState(() => _searchTerm = value);
  }

  Future<void> _loadApprovalWorkflowAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = (prefs.getString('selectedRole') ?? '').trim();
      if (roleId.isEmpty) return;

      final response = await ApiClient().get('/role/$roleId/workcenter');
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;

      final hasAccess = decoded.whereType<Map>().any((entry) {
        final workcenter = entry['workcenter'];
        final rawId = workcenter is Map ? workcenter['id'] : entry['id'];
        return rawId?.toString().trim().toLowerCase() ==
            'approval-workflow';
      });
      if (mounted) {
        setState(() => _canConfigureApprovalWorkflows = hasAccess);
      }
    } catch (_) {
      // The backend remains the source of truth. Hide the configuration tile
      // when role access cannot be confirmed.
    }
  }

  List<_ConfigurationItem> _configurationItems(BuildContext context) => [
        _ConfigurationItem(
          title: 'Company Profile',
          description:
              'Maintain company details, contact information and branding used across documents.',
          icon: Icons.business_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(
            context,
            const CompanyInfoScreen(isReadOnly: false),
          ),
        ),
        _ConfigurationItem(
          title: 'User Management',
          description:
              'Create users, maintain access and manage who can work in the tenant.',
          icon: Icons.people_outline_rounded,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const UserListScreen()),
        ),
        _ConfigurationItem(
          title: 'Role Management',
          description:
              'Define system roles and control the permissions assigned to each role.',
          icon: Icons.admin_panel_settings_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const RoleListScreen()),
        ),
        if (_canConfigureApprovalWorkflows)
          _ConfigurationItem(
            title: 'Approval Workflows',
            description:
                'Configure approval levels, approvers and activate or deactivate controlled business processes.',
            icon: Icons.account_tree_outlined,
            category: _ConfigurationCategory.organisation,
            onTap: () => _open(context, const ApprovalWorkflowListScreen()),
          ),
        _ConfigurationItem(
          title: 'Field Options',
          description:
              'Maintain tenant-specific values available in system dropdown fields.',
          icon: Icons.tune_rounded,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const FieldOptionListScreen()),
        ),
        _ConfigurationItem(
          title: 'Leave Types',
          description:
              'Maintain paid, unpaid, day and hour leave types with document and balance rules.',
          icon: Icons.category_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const LeaveConfigurationScreen(initialTab: 0)),
        ),
        _ConfigurationItem(
          title: 'Leave Profiles',
          description:
              'Configure leave entitlements, accrual, carry-over, waiting periods and profile rules.',
          icon: Icons.rule_folder_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const LeaveConfigurationScreen(initialTab: 1)),
        ),
        _ConfigurationItem(
          title: 'Leave Profile Assignments',
          description:
              'Assign effective-dated leave profiles to positions or individual employees.',
          icon: Icons.assignment_ind_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const LeaveConfigurationScreen(initialTab: 3)),
        ),
        _ConfigurationItem(
          title: 'Working Calendars',
          description:
              'Maintain working days, daily hours and holidays used for leave calculations.',
          icon: Icons.today_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const LeaveConfigurationScreen(initialTab: 2)),
        ),
        _ConfigurationItem(
          title: 'Company Forms',
          description:
              'Upload, replace and centrally publish the forms used by the organisation.',
          icon: Icons.description_outlined,
          category: _ConfigurationCategory.organisation,
          onTap: () => _open(context, const CompanyFormConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'Membership Plans',
          description:
              'Configure membership products, cover benefits, plan rules and pricing.',
          icon: Icons.card_membership_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () => _open(context, const MembershipPlanListScreen()),
        ),
        _ConfigurationItem(
          title: 'Membership Policy',
          description:
              'Control multiple memberships and approval requirements for additional cover.',
          icon: Icons.policy_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () =>
              _open(context, const MembershipPolicyConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'Claim Types',
          description:
              'Choose which claim types are available during claim registration and processing.',
          icon: Icons.fact_check_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () => _open(context, const ClaimTypeConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'Automatic Premium Generation',
          description:
              'Select the monthly generation date and backfill missing premium periods.',
          icon: Icons.calendar_month_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () => _open(context, const PremiumGenerationSettingsScreen()),
        ),
        _ConfigurationItem(
          title: 'Membership Lapse Rules',
          description:
              'Set when memberships lapse after consecutive premiums have been missed.',
          icon: Icons.event_busy_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () => _open(context, const MembershipLapseSettingsScreen()),
        ),
        _ConfigurationItem(
          title: 'Funeral Cover Underwriters',
          description:
              'Maintain organisations permitted to underwrite third-party funeral cover.',
          icon: Icons.business_center_outlined,
          category: _ConfigurationCategory.membership,
          onTap: () => _open(
            context,
            const ThirdPartyFuneralUnderwriterConfigurationPage(),
          ),
        ),
        _ConfigurationItem(
          title: 'Payment Accounts',
          description:
              'Map debtor and creditor accounts used by each payment request type.',
          icon: Icons.account_balance_wallet_outlined,
          category: _ConfigurationCategory.finance,
          onTap: () =>
              _open(context, const PaymentAccountConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'FNB Integration',
          description:
              'Activate and configure secure FNB payment instruction processing.',
          icon: Icons.account_balance_outlined,
          category: _ConfigurationCategory.finance,
          onTap: () => _open(context, const FnbIntegrationAdminScreen()),
        ),
        _ConfigurationItem(
          title: 'Xero Integration',
          description:
              'Connect Xero and select the organisation used for invoice synchronisation.',
          icon: Icons.sync_alt_rounded,
          category: _ConfigurationCategory.finance,
          onTap: () => _open(context, const XeroIntegrationScreen()),
        ),
        _ConfigurationItem(
          title: 'Supplier Invoice Email',
          description:
              'Email approved supplier invoice attachments and manage the once-off backfill.',
          icon: Icons.attach_email_outlined,
          category: _ConfigurationCategory.finance,
          onTap: () => _open(
            context,
            const PaymentRequestInvoiceEmailConfigurationScreen(),
          ),
        ),
        _ConfigurationItem(
          title: 'Manual Receipt Books',
          description:
              'Maintain valid receipt-book numbers, ranges and employee assignments.',
          icon: Icons.menu_book_outlined,
          category: _ConfigurationCategory.finance,
          onTap: () =>
              _open(context, const ManualReceiptBookMaintenanceScreen()),
        ),
        _ConfigurationItem(
          title: 'Manual Receipt Cutover',
          description:
              'Configure MAWAPay go-live, legacy capture and emergency receipt rules.',
          icon: Icons.receipt_long_outlined,
          category: _ConfigurationCategory.finance,
          onTap: () =>
              _open(context, const ManualReceiptCutoverSettingsScreen()),
        ),
        _ConfigurationItem(
          title: 'Number Allocation',
          description:
              'Configure employee numbers, document sequences, operational ranges and device allocations.',
          icon: Icons.format_list_numbered_rounded,
          category: _ConfigurationCategory.operations,
          onTap: () =>
              _open(context, const NumberRangeConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'Funeral Packages',
          description:
              'Configure fixed-price or item-based funeral packages and their included products.',
          icon: Icons.inventory_2_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const FuneralPackageSetupPage()),
        ),
        _ConfigurationItem(
          title: 'Warehouse & Storage',
          description:
              'Configure warehouses, storage locations, location types and bins.',
          icon: Icons.warehouse_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const StorageConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'POS Printing',
          description:
              'Pair payment terminals, Windows print agents and receipt printers.',
          icon: Icons.point_of_sale_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const PosPrintingSettingsScreen()),
        ),
        _ConfigurationItem(
          title: 'Device Sync Corrections',
          description:
              'Review failed MawaPay submissions, correct queued payloads and reprocess transactions.',
          icon: Icons.sync_problem_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const DeviceSyncWorkcenterScreen()),
        ),
        _ConfigurationItem(
          title: 'Message Queue Processing',
          description:
              'Schedule, start, stop and monitor asynchronous message processing.',
          icon: Icons.queue_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const MessageQueueAdminScreen()),
        ),
        _ConfigurationItem(
          title: 'API Activity Logs',
          description:
              'Review backend requests, response outcomes and system performance.',
          icon: Icons.monitor_heart_outlined,
          category: _ConfigurationCategory.operations,
          onTap: () => _open(context, const ApiLogListScreen()),
        ),
        _ConfigurationItem(
          title: 'Purple Customer App',
          description:
              'Enrol this tenant, publish services and configure customer booking availability.',
          icon: Icons.auto_awesome_outlined,
          category: _ConfigurationCategory.integrations,
          onTap: () => _open(context, const PurpleConfigurationScreen()),
        ),
        _ConfigurationItem(
          title: 'Trusted Tenants',
          description:
              'Request, approve, suspend or revoke secure cross-tenant relationships.',
          icon: Icons.verified_user_outlined,
          category: _ConfigurationCategory.integrations,
          onTap: () => _open(context, const TrustedTenantsPage()),
        ),
        _ConfigurationItem(
          title: 'Funeral Tenant Integration',
          description:
              'Configure local and external membership and claim data sources.',
          icon: Icons.hub_outlined,
          category: _ConfigurationCategory.integrations,
          onTap: () =>
              _open(context, const FuneralTenantIntegrationSetupPage()),
        ),
        _ConfigurationItem(
          title: 'SigniFlow Electronic Signatures',
          description:
              'Configure electronic signing for generated claim forms and documents.',
          icon: Icons.draw_outlined,
          category: _ConfigurationCategory.integrations,
          onTap: () => _open(context, const SigniFlowConfigurationScreen()),
        ),
      ];

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _configurationItems(context);
    final visibleItems = allItems.where((item) {
      final categoryMatches = _selectedCategory == null ||
          item.category == _selectedCategory;
      if (!categoryMatches) return false;
      if (_searchTerm.isEmpty) return true;

      final searchableText = [
        item.title,
        item.description,
        item.category.title,
        item.category.description,
      ].join(' ').toLowerCase();
      return searchableText.contains(_searchTerm);
    }).toList();

    return Scaffold(
      backgroundColor: MawaDesign.page,
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: MawaDesign.surface,
        surfaceTintColor: MawaDesign.surface,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: MawaDesign.responsivePagePadding(constraints.maxWidth),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(context, allItems.length),
                    const SizedBox(height: 22),
                    _buildSearchAndFilters(context, visibleItems.length),
                    const SizedBox(height: 26),
                    if (visibleItems.isEmpty)
                      MawaEmptyState(
                        icon: Icons.manage_search_rounded,
                        title: 'No configuration found',
                        description:
                            'Try a different search term or select another configuration area.',
                        action: TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Clear filters'),
                        ),
                      )
                    else
                      ..._buildCategorySections(context, visibleItems),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(BuildContext context, int configurationCount) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MawaDesign.navy, MawaDesign.navySoft],
        ),
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        boxShadow: MawaDesign.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'ADMINISTRATION CONTROL CENTRE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Configure how MAWA operates',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'Manage organisation rules, memberships, finance, operations and integrations from one organised workspace.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          );

          final summary = Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: MawaDesign.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_suggest_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$configurationCount',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Configuration areas',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introduction,
                const SizedBox(height: 22),
                Align(alignment: Alignment.centerLeft, child: summary),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: introduction),
              const SizedBox(width: 28),
              summary,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, int resultCount) {
    final theme = Theme.of(context);
    return MawaSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search configuration',
                  hintText: 'Search by name, purpose or business area',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchTerm.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
              final count = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: MawaDesign.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MawaDesign.border),
                ),
                child: Text(
                  '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: MawaDesign.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );

              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: count),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 14),
                  count,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Configuration areas',
            style: theme.textTheme.labelLarge?.copyWith(
              color: MawaDesign.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All areas'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              for (final category in _ConfigurationCategory.values)
                ChoiceChip(
                  avatar: Icon(category.icon, size: 17),
                  label: Text(category.title),
                  selected: _selectedCategory == category,
                  onSelected: (_) => setState(
                    () => _selectedCategory =
                        _selectedCategory == category ? null : category,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections(
    BuildContext context,
    List<_ConfigurationItem> visibleItems,
  ) {
    final sections = <Widget>[];
    for (final category in _ConfigurationCategory.values) {
      final categoryItems = visibleItems
          .where((item) => item.category == category)
          .toList(growable: false);
      if (categoryItems.isEmpty) continue;

      sections.add(
        _ConfigurationSection(
          category: category,
          items: categoryItems,
        ),
      );
      sections.add(const SizedBox(height: 30));
    }
    if (sections.isNotEmpty) sections.removeLast();
    return sections;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _selectedCategory = null);
  }
}

class _ConfigurationSection extends StatelessWidget {
  final _ConfigurationCategory category;
  final List<_ConfigurationItem> items;

  const _ConfigurationSection({
    required this.category,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MawaSectionHeader(
          title: category.title,
          description: category.description,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MawaDesign.iconBackground(category.color),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${items.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: category.color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = MawaDesign.responsiveGridCount(
              constraints.maxWidth,
              minimumCardWidth: 350,
              maxColumns: 3,
            );
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 174,
              ),
              itemBuilder: (context, index) => _ConfigurationCard(
                item: items[index],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  final _ConfigurationItem item;

  const _ConfigurationCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.category.color;
    return Material(
      color: MawaDesign.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: MawaDesign.surface,
            borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
            border: Border.all(color: MawaDesign.border),
            boxShadow: MawaDesign.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MawaIconBadge(
                      icon: item.icon,
                      color: color,
                      size: 46,
                    ),
                    const Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: MawaDesign.surfaceMuted,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: MawaDesign.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MawaDesign.text,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MawaDesign.textMuted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigurationItem {
  final String title;
  final String description;
  final IconData icon;
  final _ConfigurationCategory category;
  final VoidCallback onTap;

  const _ConfigurationItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.onTap,
  });
}

enum _ConfigurationCategory {
  organisation(
    title: 'Organisation, People & Access',
    description:
        'Manage company identity, users, roles, approvals, workforce rules and reusable business values.',
    icon: Icons.corporate_fare_outlined,
    color: MawaDesign.info,
  ),
  membership(
    title: 'Memberships & Claims',
    description:
        'Control membership products, policy rules, premiums, lapses and claim options.',
    icon: Icons.groups_2_outlined,
    color: Color(0xFF8B5CF6),
  ),
  finance(
    title: 'Finance & Documents',
    description:
        'Configure payment processing, accounting, receipt controls and finance documents.',
    icon: Icons.payments_outlined,
    color: MawaDesign.success,
  ),
  operations(
    title: 'Operations & Monitoring',
    description:
        'Configure operational numbering, funeral packages, storage, printing and technical processing.',
    icon: Icons.settings_suggest_outlined,
    color: Color(0xFFF97316),
  ),
  integrations(
    title: 'Tenant & Service Integrations',
    description:
        'Connect trusted tenants and external services used by funeral and signing workflows.',
    icon: Icons.hub_outlined,
    color: Color(0xFF0EA5A8),
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _ConfigurationCategory({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
