import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/models/module_usage.dart';
import '../../core/services/module_usage_service.dart';
import '../../core/services/tenant_experience_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/routing/workcenter_route_registry.dart';
import '../../core/routing/feature_group_registry.dart';
import '../../core/routing/workcenter_card_descriptions.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/mawa_design.dart';
import '../../core/widgets/mawa_ui.dart';
import '../../core/models/access_profile.dart';
import '../../core/services/access_profile_service.dart';
import '../settings/models/role.dart';
import 'models/workcenter.dart';
import 'models/tenant_experience.dart';

// Import missing screens for legacy navigation fallback
import '../auth/role_selection_screen.dart';
import '../auth/change_password_screen.dart';
import '../settings/screens/api_log_list_screen.dart';
import '../settings/screens/pos_printing_settings_screen.dart';
import '../settings/screens/system_installation_files_screen.dart';
import '../invoicing/screens/invoice_create_screen.dart';
import '../membership/screens/membership_claim_list_screen.dart';
import '../membership/screens/membership_plan_list_screen.dart';
import '../payroll/screens/payroll_batch_list_screen.dart';
import '../membership/screens/group_society_list_screen.dart';
import '../payments/screens/payment_request_list_screen.dart';
import '../partners/screens/partner_list_screen.dart';
import '../cashup/screens/cashup_list_screen.dart';
import '../inbox/models/inbox.dart';
import '../inbox/services/inbox_service.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  String? _displayName;
  String? _selectedRoleDisplay;
  String _appVersion = '';
  AccessProfile? _accessProfile;
  List<Workcenter> _workcenters = [];
  List<Workcenter> _filteredWorkcenters = [];
  List<ModuleUsage> _recentModules = [];
  List<ModuleUsage> _frequentModules = [];
  bool _isLoadingWorkcenters = true;
  bool _isLoadingRecent = true;
  bool _isLoadingFrequent = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;
  final ModuleUsageService _moduleUsageService = ModuleUsageService();
  final TenantExperienceService _tenantExperienceService = TenantExperienceService();
  TenantExperience? _tenantExperience;
  final InboxService _inboxService = InboxService();
  InboxCounts _inboxCounts = const InboxCounts.empty();
  Timer? _inboxTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserInfo();
    _loadTenantExperience();
    _loadAppVersion();
    _fetchRecentModules();
    _fetchFrequentModules();
    _loadInboxCounts();
    _inboxTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadInboxCounts(silent: true),
    );
  }

  Future<void> _loadInboxCounts({bool silent = false}) async {
    try {
      final counts = await _inboxService.getCounts();
      if (!mounted) return;
      setState(() => _inboxCounts = counts);
    } catch (error) {
      if (!silent) debugPrint('Unable to load inbox counts: $error');
    }
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadTenantExperience() async {
    try {
      final experience = await _tenantExperienceService.getExperience();
      if (mounted) setState(() => _tenantExperience = experience);
    } catch (error) {
      debugPrint('Unable to load tenant industry experience: $error');
      if (mounted) setState(() => _tenantExperience = null);
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final roleId = prefs.getString('selectedRole');
    final roleDesc = prefs.getString('selectedRoleDescription');

    setState(() {
      _displayName = prefs.getString('displayName');
      _selectedRoleDisplay = roleDesc ?? roleId;
    });

    try {
      final profile = await AccessProfileService().getProfile();
      if (mounted) setState(() => _accessProfile = profile);
    } catch (e) {
      debugPrint('Unable to load access profile: $e');
    }

    if (roleId != null) {
      _fetchWorkcenters(roleId);
    } else {
      setState(() => _isLoadingWorkcenters = false);
    }
  }

  Future<void> _fetchWorkcenters(String roleId) async {
    setState(() => _isLoadingWorkcenters = true);
    try {
      final response = await ApiClient().get('/role/$roleId/workcenter');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _workcenters = data.map((json) => Workcenter.fromJson(json)).toList();
          _workcenters.sort((a, b) => a.position.compareTo(b.position));
          _filteredWorkcenters = _workcenters;
          _isLoadingWorkcenters = false;
        });
        _animationController.forward(from: 0.0);
      } else {
        setState(() => _isLoadingWorkcenters = false);
      }
    } catch (e) {
      setState(() => _isLoadingWorkcenters = false);
    }
  }

  Future<void> _fetchRecentModules() async {
    try {
      final recent = await _moduleUsageService.getRecentlyUsed(limit: 6);
      if (mounted) {
        setState(() {
          _recentModules = recent;
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent modules: $e');
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  Future<void> _fetchFrequentModules() async {
    try {
      final frequent = await _moduleUsageService.getFrequentlyUsed(limit: 6);
      if (mounted) {
        setState(() {
          _frequentModules = frequent;
          _isLoadingFrequent = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching frequent modules: $e');
      if (mounted) setState(() => _isLoadingFrequent = false);
    }
  }

  void _applySearch(String query) {
    setState(() => _filteredWorkcenters = _workcenters);
    _animationController.forward(from: 0.0);
  }

  Future<void> _changeRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) return;

    final response = await ApiClient().get('/v2/user/$userId/role');

    if (response.statusCode == 200) {
      final List<dynamic> rolesData = jsonDecode(response.body);
      final List<Role> roleList = rolesData.map((e) {
        if (e is String) {
          return Role(id: e, description: e);
        }
        return Role.fromJson(e as Map<String, dynamic>);
      }).toList();

      if (roleList.isNotEmpty) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RoleSelectionScreen(
                roles: roleList,
                onRoleSelected: () {
                  Navigator.of(context).pop();
                  _loadUserInfo();
                },
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showLogoutConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded, color: MawaDesign.red),
          title: const Text('Sign out of MAWA?'),
          content: const Text('You will need to sign in again to continue working.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Sign out'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await ApiClient().logout();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  IconData _getIconData(String id, [String? iconKey]) {
    final lowerId = '${iconKey ?? ''} $id'.toLowerCase();
    if (lowerId.contains('service')) return Icons.design_services_rounded;
    if (lowerId.contains('employment')) return Icons.work_history_rounded;
    if (lowerId.contains('leave')) return Icons.event_available_rounded;
    if (lowerId.contains('asset')) return Icons.precision_manufacturing_rounded;
    if (lowerId == 'employee') return Icons.badge_rounded;
    if (lowerId == 'supplier') return Icons.local_shipping_rounded;
    if (lowerId == 'customer') return Icons.person_pin_rounded;
    if (lowerId == 'client') return Icons.handshake_rounded;
    if (lowerId == 'member') return Icons.card_membership_rounded;
    if (lowerId == 'membership-claim') return Icons.request_quote_rounded;
    if (lowerId.contains('membership') || lowerId.contains('member')) return Icons.people_rounded;
    if (lowerId.contains('plan') || lowerId.contains('product')) return Icons.inventory_2_rounded;
    if (lowerId.contains('payroll')) return Icons.payments_rounded;
    if (lowerId.contains('claim')) return Icons.request_quote_rounded;
    if (lowerId.contains('payment')) return Icons.account_balance_wallet_rounded;
    if (lowerId.contains('group') || lowerId.contains('society')) return Icons.groups_rounded;
    if (lowerId.contains('invoic')) return Icons.description_rounded;
    if (lowerId.contains('partner')) return Icons.business_center_rounded;
    if (lowerId.contains('user')) return Icons.person_add_rounded;
    if (lowerId.contains('api-log')) return Icons.api_rounded;
    if (lowerId.contains('setting')) return Icons.settings_suggest_rounded;
    if (lowerId.contains('report')) return Icons.bar_chart_rounded;
    if (lowerId.contains('company')) return Icons.domain_rounded;
    if (lowerId.contains('cashup')) return Icons.point_of_sale_rounded;
    if (lowerId.contains('workflow')) return Icons.account_tree_rounded;
    if (lowerId.contains('approval')) return Icons.fact_check_rounded;
    if (lowerId.contains('config') || lowerId.contains('role')) return Icons.settings_applications_rounded;
    if (lowerId.contains('case')) return Icons.gavel_rounded;
    if (lowerId.contains('engagement') || lowerId.contains('communication')) return Icons.campaign_rounded;
    return Icons.apps_rounded;
  }

  void _navigateToWorkcenter(Workcenter wc) {
    // Track module usage
    _moduleUsageService.trackUsage(
      moduleCode: wc.id,
      moduleName: wc.presentationTitle,
      modulePath: wc.routePath,
      workcenterId: wc.id,
    );
    _fetchRecentModules();
    _fetchFrequentModules();

    // Synthetic group cards must always open their feature-group screen.
    // Do this before route normalization because a group such as `inventory`
    // also has a valid operational route in the workcenter registry.
    if (FeatureGroupRegistry.isGroupId(wc.id)) {
      final groupRoute = FeatureGroupRegistry.routeForGroup(wc.id);
      if (groupRoute != null) {
        context.push(groupRoute);
        return;
      }
    }

    // Prefer the workcenter identity over a configured path. Some tenants still
    // carry stale paths (for example Products pointing to Membership Plans),
    // while the id/route key remains authoritative.
    final routeById = WorkcenterRouteRegistry.getRoutePath(wc.id);
    if (routeById != null) {
      context.push(routeById);
      return;
    }

    final routeByRegistry = WorkcenterRouteRegistry.getRoutePath(wc.routeKey);
    if (routeByRegistry != null) {
      context.push(routeByRegistry);
      return;
    }

    final configuredPath = wc.routePath?.trim();
    if (configuredPath != null && configuredPath.isNotEmpty) {
      final mappedPath = WorkcenterRouteRegistry.getRoutePath(configuredPath);
      if (mappedPath != null) {
        context.push(mappedPath);
        return;
      }
      if (configuredPath.startsWith('/')) {
        context.push(configuredPath);
        return;
      }
    }

    // Fallback logic
    final id = wc.id.toUpperCase();
    final description = wc.description.toLowerCase();

    if (id == 'EMPLOYEE') {
      context.push(AppRoutes.employment);
      return;
    }

    if (['SUPPLIER', 'CUSTOMER', 'CLIENT', 'MEMBER'].contains(id)) {
      context.push('/partners/$id'); // Assuming we'll have this route, or use fallback navigation
      return;
    }

    // Fallback to legacy navigation for cases not yet in registry
    if (id == 'API-LOG') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ApiLogListScreen()));
      return;
    }

    if (id == 'INVOICE-CREATE') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InvoiceCreateScreen()));
    } else if (id == 'MEMBERSHIP-CLAIM') {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MembershipClaimListScreen()));
    } else if (id.contains('INVOIC') || description.contains('invoic')) {
      context.push(AppRoutes.invoices);
    } else if (id.contains('PRODUCT')) {
      context.push(AppRoutes.products);
    } else if (id.contains('PLAN') || description.contains('plan')) {
      context.push(AppRoutes.membershipPlans);
    } else if (id.contains('MEMBERSHIP') || description.contains('membership')) {
      context.push(AppRoutes.memberships);
    } else if (id.contains('PAYROLL') || description.contains('payroll')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PayrollBatchListScreen()));
    } else if (id.contains('CLAIM') || description.contains('claim')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MembershipClaimListScreen()));
    } else if (id.contains('GROUP') || id.contains('SOCIETY') || description.contains('group') || description.contains('society')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GroupSocietyListScreen()));
    } else if (id.contains('PAYMENT') || description.contains('payment')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaymentRequestListScreen()));
    } else if (id.contains('PARTNER') || description.contains('partner')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PartnerListScreen()));
    } else if (id.contains('USER') || id.contains('SETTING') || id.contains('COMPANY') || id.contains('WORKFLOW') || id.contains('CONFIG') || id.contains('ROLE')) {
      context.push(AppRoutes.settings);
    } else if (id.contains('CASHUP') || description.contains('cashup')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CashupListScreen()));
    } else if (id.contains('APPROVAL')) {
      context.push(AppRoutes.approvals);
    } else if (id.contains('CASE')) {
      context.push(AppRoutes.cases);
    } else if (id.contains('ENGAGEMENT') || id.contains('COMMUNICATION') || description.contains('engagement') || description.contains('communication')) {
      context.push(AppRoutes.internalCommunications);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${wc.presentationTitle} feature coming soon'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<_HomeWorkcenterSection> _buildHomeSections(
    List<Workcenter> roleWorkcenters,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final experience = _tenantExperience;
    final sections = experience?.sections.isNotEmpty == true
        ? experience!.sections
        : _fallbackExperienceSections();
    final usedIds = <String>{};
    final result = <_HomeWorkcenterSection>[];
    final centralApprovalWorkcenter =
        _findCentralApprovalWorkcenter(roleWorkcenters);
    final serviceManagementWorkcenter =
        _findRoleWorkcenter(roleWorkcenters, 'service-management');
    var centralApprovalsConfigured = false;
    var serviceManagementConfigured = false;

    for (final section in sections) {
      final cards = <Workcenter>[];
      final orderedGroups = [...section.groups]
        ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
      for (final group in orderedGroups) {
        if (!group.active) continue;
        final isCentralApprovalsGroup = FeatureGroupRegistry.normalize(group.code) ==
            FeatureGroupRegistry.normalize('approvals');
        final isReportsAnalyticsGroup = FeatureGroupRegistry.normalize(group.code) ==
            FeatureGroupRegistry.normalize('reports-analytics');
        final isServiceManagementGroup = FeatureGroupRegistry.normalize(group.code) ==
            FeatureGroupRegistry.normalize('service-management');
        if (isCentralApprovalsGroup) centralApprovalsConfigured = true;
        if (isServiceManagementGroup) serviceManagementConfigured = true;
        final configuredChildren = <Workcenter>[];
        for (final item in group.workcenters) {
          if (!item.active) continue;
          if (!FeatureGroupRegistry.belongsToCanonicalGroup(item.id, group.code)) {
            continue;
          }
          final matched = _findRoleWorkcenter(roleWorkcenters, item.id);
          if (matched == null) continue;
          if (FeatureGroupRegistry.isLegacyInventoryUmbrella(matched.id)) {
            continue;
          }
          if (_isCentralApprovalWorkcenter(matched) &&
              !isCentralApprovalsGroup) {
            // Older industry profiles placed the approval inbox under Work
            // Management. It is intentionally removed there and surfaced in
            // the dedicated Approvals workspace below.
            continue;
          }
          final normalizedId = FeatureGroupRegistry.normalize(matched.id);
          if (usedIds.contains(normalizedId)) continue;
          configuredChildren.add(matched);
          usedIds.add(normalizedId);
        }

        // Normalise older tenant-experience profiles at runtime. Sales and
        // procurement documents have one clear owner and inventory operations
        // belong under Products & Inventory, regardless of stale duplicated
        // group entries in the compiled tenant profile.
        for (final candidate in roleWorkcenters) {
          if (FeatureGroupRegistry.isLegacyInventoryUmbrella(candidate.id)) {
            continue;
          }
          final owner =
              FeatureGroupRegistry.canonicalOwnerForWorkcenter(candidate.id);
          if (owner == null ||
              FeatureGroupRegistry.normalize(owner) !=
                  FeatureGroupRegistry.normalize(
                    FeatureGroupRegistry.canonicalGroupId(group.code),
                  )) {
            continue;
          }
          final normalizedId = FeatureGroupRegistry.normalize(candidate.id);
          if (usedIds.contains(normalizedId)) continue;
          configuredChildren.add(candidate);
          usedIds.add(normalizedId);
        }

        if (isReportsAnalyticsGroup) {
          // Existing tenant-experience JSON may still reference the old
          // generic `reports` workcentre. The role now receives individual
          // report permissions, so surface those cards without waiting for a
          // tenant-experience regeneration.
          for (final report in roleWorkcenters.where(_isReportingWorkcenter)) {
            final normalizedId = FeatureGroupRegistry.normalize(report.id);
            if (usedIds.contains(normalizedId)) continue;
            configuredChildren.add(report);
            usedIds.add(normalizedId);
          }
        }
        if (configuredChildren.isEmpty) continue;

        final groupTitle = FeatureGroupRegistry.presentationTitleForGroup(
          group.code,
          group.title,
        );
        final groupMatches = query.isEmpty ||
            groupTitle.toLowerCase().contains(query) ||
            group.description.toLowerCase().contains(query);
        final childMatches = query.isEmpty ||
            configuredChildren.any((child) =>
                child.description.toLowerCase().contains(query) ||
                child.id.toLowerCase().contains(query));
        if (!groupMatches && !childMatches) continue;

        cards.add(
          Workcenter(
            id: group.code,
            description: groupTitle,
            displayLabel: groupTitle,
            cardDescription: group.description,
            defaultFunction: '',
            path: '/feature-groups/${group.code}',
            position: group.displayOrder,
            routeKey: group.code,
            routePath: '/feature-groups/${group.code}',
            iconKey: group.iconKey,
          ),
        );
      }
      if (cards.isNotEmpty) {
        cards.sort((a, b) => a.position.compareTo(b.position));
        result.add(
          _HomeWorkcenterSection(
            code: section.code,
            title: section.title,
            description: section.description,
            displayOrder: section.displayOrder,
            items: cards,
          ),
        );
      }
    }

    if (centralApprovalWorkcenter != null && !centralApprovalsConfigured) {
      usedIds.add(FeatureGroupRegistry.normalize(centralApprovalWorkcenter.id));
      _addCentralApprovalsCard(
        sections: result,
        query: query,
        approvalWorkcenter: centralApprovalWorkcenter,
      );
    }

    if (serviceManagementWorkcenter != null && !serviceManagementConfigured) {
      usedIds.add(FeatureGroupRegistry.normalize(serviceManagementWorkcenter.id));
      _addServiceManagementCard(
        sections: result,
        query: query,
        serviceManagementWorkcenter: serviceManagementWorkcenter,
      );
    }

    final allowUnassignedWorkcenters = experience == null ||
        experience.primaryIndustryCode.trim().toUpperCase() == 'GENERAL_CUSTOM';
    if (allowUnassignedWorkcenters) {
      final unmatched = roleWorkcenters.where((workcenter) {
        if (FeatureGroupRegistry.isGroupId(workcenter.id)) return false;
        if (FeatureGroupRegistry.isLegacyInventoryUmbrella(workcenter.id)) {
          return false;
        }
        if (usedIds.contains(FeatureGroupRegistry.normalize(workcenter.id))) {
          return false;
        }
        if (query.isEmpty) return true;
        return workcenter.description.toLowerCase().contains(query) ||
            workcenter.id.toLowerCase().contains(query);
      }).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      if (unmatched.isNotEmpty) {
        result.add(
          _HomeWorkcenterSection(
            code: 'ADDITIONAL_WORKCENTERS',
            title: 'Additional Workcenters',
            description:
                'Role-specific capabilities that have not yet been assigned to a custom industry group.',
            displayOrder: 90,
            items: unmatched,
          ),
        );
      }
    }
    result.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return result;
  }

  void _addServiceManagementCard({
    required List<_HomeWorkcenterSection> sections,
    required String query,
    required Workcenter serviceManagementWorkcenter,
  }) {
    final definition = FeatureGroupRegistry.groupById('service-management');
    if (definition == null) return;

    final searchable = <String>[
      definition.title,
      definition.description,
      serviceManagementWorkcenter.description,
      serviceManagementWorkcenter.id,
    ].join(' ').toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return;

    final card = Workcenter(
      id: definition.id,
      description: definition.title,
      displayLabel: definition.title,
      cardDescription: definition.description,
      defaultFunction: '',
      path: definition.routePath,
      position: definition.displayOrder,
      routeKey: definition.id,
      routePath: definition.routePath,
      iconKey: definition.iconKey,
    );

    final yourBusinessIndex = sections.indexWhere(
      (section) => FeatureGroupRegistry.normalize(section.code) == 'YOUR_BUSINESS',
    );
    if (yourBusinessIndex >= 0) {
      final items = sections[yourBusinessIndex].items;
      if (!items.any((item) =>
          FeatureGroupRegistry.normalize(item.id) == 'SERVICE_MANAGEMENT')) {
        items.add(card);
        items.sort((left, right) => left.position.compareTo(right.position));
      }
      return;
    }

    sections.add(
      _HomeWorkcenterSection(
        code: 'YOUR_BUSINESS',
        title: 'Your Business',
        description: 'Core solutions configured for this organisation.',
        displayOrder: 10,
        items: [card],
      ),
    );
  }

  Workcenter? _findCentralApprovalWorkcenter(
    List<Workcenter> roleWorkcenters,
  ) {
    for (final workcenter in roleWorkcenters) {
      if (_isCentralApprovalWorkcenter(workcenter)) return workcenter;
    }
    return null;
  }

  bool _isCentralApprovalWorkcenter(Workcenter workcenter) {
    const approvalKeys = <String>{
      'APPROVAL',
      'APPROVALS',
      'APPROVAL_INBOX',
    };
    final candidates = <String>{
      FeatureGroupRegistry.normalize(workcenter.id),
      FeatureGroupRegistry.normalize(workcenter.routeKey),
      FeatureGroupRegistry.normalize(workcenter.defaultFunction),
    };
    return candidates.any(approvalKeys.contains);
  }

  bool _isReportingWorkcenter(Workcenter workcenter) {
    final id = FeatureGroupRegistry.normalize(workcenter.id);
    if (id == 'REPORT' ||
        id == 'REPORTS' ||
        id == 'REPORTING' ||
        id == 'REPORTS_ANALYTICS') {
      return false;
    }
    return id.contains('REPORT');
  }

  void _addCentralApprovalsCard({
    required List<_HomeWorkcenterSection> sections,
    required String query,
    required Workcenter approvalWorkcenter,
  }) {
    final definition = FeatureGroupRegistry.groupById('approvals');
    if (definition == null) return;

    final searchable = <String>[
      definition.title,
      definition.description,
      approvalWorkcenter.description,
      approvalWorkcenter.id,
    ].join(' ').toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return;

    final card = Workcenter(
      id: definition.id,
      description: definition.title,
      displayLabel: definition.title,
      cardDescription: definition.description,
      defaultFunction: '',
      path: definition.routePath,
      position: definition.displayOrder,
      routeKey: definition.id,
      routePath: definition.routePath,
      iconKey: definition.iconKey,
    );

    final businessServicesIndex = sections.indexWhere(
      (section) => FeatureGroupRegistry.normalize(section.code) ==
          'BUSINESS_SERVICES',
    );
    if (businessServicesIndex >= 0) {
      final items = sections[businessServicesIndex].items;
      if (!items.any((item) =>
          FeatureGroupRegistry.normalize(item.id) == 'APPROVALS')) {
        items.add(card);
        items.sort((left, right) => left.position.compareTo(right.position));
      }
      return;
    }

    sections.add(
      _HomeWorkcenterSection(
        code: 'BUSINESS_SERVICES',
        title: 'Business Services',
        description: 'Shared services supporting daily operations.',
        displayOrder: 20,
        items: [card],
      ),
    );
  }

  Workcenter? _findRoleWorkcenter(
    List<Workcenter> roleWorkcenters,
    String configuredId,
  ) {
    final target = FeatureGroupRegistry.normalize(configuredId);
    for (final workcenter in roleWorkcenters) {
      final candidates = <String>{
        FeatureGroupRegistry.normalize(workcenter.id),
        FeatureGroupRegistry.normalize(workcenter.routeKey),
        FeatureGroupRegistry.normalize(workcenter.defaultFunction),
      };
      if (candidates.contains(target)) return workcenter;
    }
    return null;
  }

  List<TenantExperienceSection> _fallbackExperienceSections() {
    final sectionMetadata = <String, ({String title, String description, int order})>{
      'YOUR_BUSINESS': (
        title: 'Your Business',
        description: 'Core solutions configured for this organisation.',
        order: 10,
      ),
      'BUSINESS_SERVICES': (
        title: 'Business Services',
        description: 'Shared services supporting daily operations.',
        order: 20,
      ),
      'SYSTEM_ADMINISTRATION': (
        title: 'System Administration',
        description: 'Configuration, integrations and platform administration.',
        order: 30,
      ),
    };
    return sectionMetadata.entries.map((entry) {
      final groups = FeatureGroupRegistry.groups
          .where((group) => group.sectionCode == entry.key)
          .map((group) => TenantExperienceGroup(
                code: group.id,
                title: group.title,
                description: group.description,
                sectionCode: group.sectionCode,
                iconKey: group.iconKey,
                displayOrder: group.displayOrder,
                active: true,
                workcenters: group.childWorkcenterIds
                    .asMap()
                    .entries
                    .map((item) => TenantExperienceWorkcenter(
                          id: item.value,
                          displayLabel: '',
                          description: '',
                          displayOrder: item.key * 10,
                          active: true,
                        ))
                    .toList(),
              ))
          .toList();
      return TenantExperienceSection(
        code: entry.key,
        title: entry.value.title,
        description: entry.value.description,
        displayOrder: entry.value.order,
        groups: groups,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sections = _buildHomeSections(_filteredWorkcenters);
    final modules = sections.expand((section) => section.items).toList();
    final reports = modules
        .where((item) =>
            item.id.toLowerCase().contains('report') ||
            item.presentationTitle.toLowerCase().contains('report'))
        .toList();
    final showSidebar = screenWidth >= 1120;

    return Scaffold(
      backgroundColor: MawaDesign.page,
      body: _isLoadingWorkcenters
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                if (showSidebar) _buildDesktopSidebar(modules),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(showSidebar: showSidebar),
                      Expanded(
                        child: _buildDashboardContent(
                          modules: modules,
                          reports: reports,
                          sections: sections,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar({required bool showSidebar}) {
    final theme = Theme.of(context);
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: showSidebar ? 28 : 18),
      decoration: const BoxDecoration(
        color: MawaDesign.surface,
        border: Border(bottom: BorderSide(color: MawaDesign.border)),
      ),
      child: Row(
        children: [
          if (!showSidebar) ...[
            Image.asset(
              'assets/branding/mawa_logo.png',
              height: 34,
              width: 116,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _applySearch,
                decoration: InputDecoration(
                  hintText: 'Search MAWA workcenters and reports',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _applySearch('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: MawaDesign.surfaceMuted,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (_selectedRoleDisplay != null && MediaQuery.sizeOf(context).width >= 760)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: MawaDesign.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: MawaDesign.border),
              ),
              child: Text(
                _selectedRoleDisplay!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: MawaDesign.textMuted,
                ),
              ),
            ),
          _buildInboxButton(),
          const SizedBox(width: 8),
          _buildUserMenu(),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(List<Workcenter> modules) {
    final theme = Theme.of(context);
    final navigationModules = modules.take(7).toList();
    return Container(
      width: MawaDesign.desktopSidebarWidth,
      decoration: const BoxDecoration(
        color: MawaDesign.surface,
        border: Border(right: BorderSide(color: MawaDesign.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/branding/mawa_logo.png',
                      height: 36,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  if (_appVersion.isNotEmpty)
                    Text(
                      _appVersion,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: MawaDesign.textSubtle,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            _sidebarItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
            _sidebarItem(
              icon: Icons.inbox_rounded,
              label: _inboxCounts.pendingApprovalCount > 0
                  ? 'Inbox (${_inboxCounts.pendingApprovalCount})'
                  : 'Inbox',
              onTap: () => context.push(AppRoutes.inbox),
            ),
            ...navigationModules.map(
              (workcenter) => _sidebarItem(
                icon: _getIconData(workcenter.id, workcenter.iconKey),
                label: workcenter.description,
                onTap: () => _navigateToWorkcenter(workcenter),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: OutlinedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: MawaDesign.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? MawaDesign.redSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? MawaDesign.red : MawaDesign.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? MawaDesign.navy : MawaDesign.textMuted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

  Widget _buildDashboardContent({
    required List<Workcenter> modules,
    required List<Workcenter> reports,
    required List<_HomeWorkcenterSection> sections,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MawaDesign.responsivePagePadding(constraints.maxWidth);
        return SingleChildScrollView(
          padding: padding,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                if (_accessProfile != null &&
                    (_accessProfile!.platformSession ||
                        _accessProfile!.testUser)) ...[
                  const SizedBox(height: 18),
                  _buildAccessSessionBanner(_accessProfile!),
                ],
                const SizedBox(height: 22),
                _buildActionGrid(modules: modules, reports: reports),
                const SizedBox(height: 24),
                _buildActivityRow(modules),
                const SizedBox(height: 30),
                for (var index = 0; index < sections.length; index++) ...[
                  if (index > 0) const SizedBox(height: 30),
                  _buildWorkcenterSection(
                    title: sections[index].title,
                    description: sections[index].description,
                    items: sections[index].items,
                    isReport: sections[index].code == 'REPORTS_ANALYTICS',
                  ),
                ],
                if (sections.isEmpty &&
                    _searchController.text.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const MawaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching workcenters',
                    description:
                        'Try a different name, process or report in the search field.',
                  ),
                ],
                const SizedBox(height: 34),
                _buildFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    final theme = Theme.of(context);
    final firstName = _displayName?.trim().split(RegExp(r'\s+')).first ?? 'User';
    final date = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return MawaPageHeader(
      title: 'Good ${_greetingForNow()}, $firstName',
      description: _tenantExperience == null
          ? 'Here is a clear view of the MAWA areas available for your role.'
          : 'Your ${_tenantExperience!.primaryIndustryName} workspace, shaped around the industries configured for this organisation.',
      eyebrow: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: MawaDesign.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: theme.textTheme.labelMedium?.copyWith(
              color: MawaDesign.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  Widget _buildActionGrid({
    required List<Workcenter> modules,
    required List<Workcenter> reports,
  }) {
    Workcenter? findWorkcenter(bool Function(Workcenter) matches) {
      for (final item in modules) {
        if (matches(item)) return item;
      }
      return null;
    }

    bool containsAny(Workcenter item, List<String> terms) {
      final haystack = '${item.id} ${item.routeKey} ${item.description} ${item.presentationTitle}'.toLowerCase();
      return terms.any(haystack.contains);
    }

    final paymentRequests = findWorkcenter(
      (item) => containsAny(item, const ['payment_request', 'payment request']),
    );
    final invoices = findWorkcenter(
      (item) => containsAny(item, const ['invoice', 'invoicing']),
    );
    final reportsWorkcenter = reports.isEmpty ? null : reports.first;

    Workcenter? recent;
    for (final usage in _recentModules) {
      final match = _workcenterForUsage(usage);
      if (match != null) {
        recent = match;
        break;
      }
    }

    Workcenter? frequent;
    for (final usage in _frequentModules) {
      final match = _workcenterForUsage(usage);
      if (match != null && match.id != recent?.id) {
        frequent = match;
        break;
      }
    }

    final actions = <Widget>[
      _buildHomeActionCard(
        icon: Icons.fact_check_outlined,
        title: _inboxCounts.pendingApprovalCount > 0
            ? 'Approvals need attention'
            : 'Approval inbox',
        description: _inboxCounts.pendingApprovalCount > 0
            ? '${_inboxCounts.pendingApprovalCount} request${_inboxCounts.pendingApprovalCount == 1 ? '' : 's'} waiting for your decision. Review and action them from one place.'
            : 'Review approval requests, workflow decisions and items waiting for your action.',
        actionLabel: 'Open approvals',
        onTap: () async {
          await context.push(AppRoutes.inbox);
          _loadInboxCounts();
        },
      ),
      if (paymentRequests != null)
        _buildHomeActionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment requests',
          description:
              'Review supplier, claim, funeral and other payment requests and follow their approval or payment status.',
          actionLabel: 'Open payment requests',
          onTap: () => _navigateToWorkcenter(paymentRequests!),
        )
      else
        _buildHomeActionCard(
          icon: Icons.notifications_active_outlined,
          title: 'Inbox & notifications',
          description: _inboxCounts.unreadCount > 0
              ? '${_inboxCounts.unreadCount} unread notification${_inboxCounts.unreadCount == 1 ? '' : 's'} need your attention.'
              : 'Review workflow outcomes, system notifications and items sent to you.',
          actionLabel: 'Open inbox',
          onTap: () async {
            await context.push(AppRoutes.inbox);
            _loadInboxCounts();
          },
        ),
      if (invoices != null)
        _buildHomeActionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Invoices & billing',
          description:
              'Create, review and follow customer invoices without navigating through unrelated workcentres.',
          actionLabel: 'Open invoices',
          onTap: () => _navigateToWorkcenter(invoices!),
        )
      else if (recent != null)
        _buildHomeActionCard(
          icon: Icons.history_rounded,
          title: 'Continue working',
          description:
              'Return to ${recent.presentationTitle}, the work area you used most recently.',
          actionLabel: 'Resume ${recent.presentationTitle}',
          onTap: () => _navigateToWorkcenter(recent!),
        )
      else
        _buildHomeActionCard(
          icon: Icons.search_rounded,
          title: 'Find a work area',
          description:
              'Search the workcentres available to your role and go directly to the task you need.',
          actionLabel: 'Search workcentres',
          onTap: () => _searchFocusNode.requestFocus(),
        ),
      if (reportsWorkcenter != null)
        _buildHomeActionCard(
          icon: Icons.insights_outlined,
          title: 'Reports & analytics',
          description:
              'Open operational and management reports to investigate performance and exceptions.',
          actionLabel: 'Open reports',
          onTap: () => _navigateToWorkcenter(reportsWorkcenter),
        )
      else if (frequent != null)
        _buildHomeActionCard(
          icon: Icons.bolt_outlined,
          title: 'Frequently used',
          description:
              'Open ${frequent.presentationTitle}, one of your regular work areas.',
          actionLabel: 'Open ${frequent.presentationTitle}',
          onTap: () => _navigateToWorkcenter(frequent!),
        )
      else
        _buildHomeActionCard(
          icon: Icons.search_rounded,
          title: 'Find another work area',
          description:
              'Search all workcentres available to your role instead of browsing passive dashboard totals.',
          actionLabel: 'Search workcentres',
          onTap: () => _searchFocusNode.requestFocus(),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = MawaDesign.responsiveGridCount(
          constraints.maxWidth,
          minimumCardWidth: 270,
          maxColumns: 4,
        );
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: columns >= 4 ? 1.75 : 1.9,
          children: actions,
        );
      },
    );
  }

  Widget _buildHomeActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.75),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MawaIconBadge(
                    icon: icon,
                    color: MawaDesign.red,
                    size: 40,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: MawaDesign.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow(List<Workcenter> modules) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final quickActions = _buildQuickActions(modules);
        final recent = _buildRecentActivity();
        if (stacked) {
          return Column(
            children: [
              quickActions,
              const SizedBox(height: 16),
              recent,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: quickActions),
            const SizedBox(width: 16),
            Expanded(child: recent),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(List<Workcenter> modules) {
    final theme = Theme.of(context);
    final source = <Workcenter>[];
    for (final usage in _frequentModules) {
      final match = _workcenterForUsage(usage);
      if (match != null && !source.any((item) => item.id == match.id)) source.add(match);
    }
    for (final item in modules) {
      if (source.length >= 4) break;
      if (!source.any((existing) => existing.id == item.id)) source.add(item);
    }

    return MawaSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MawaSectionHeader(
            title: 'Quick actions',
            description: 'Open your most useful work areas.',
          ),
          const SizedBox(height: 14),
          if (source.isEmpty)
            const MawaEmptyState(
              icon: Icons.bolt_outlined,
              title: 'No quick actions yet',
              description: 'Your most frequently used workcenters will appear here.',
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            )
          else
            ...source.take(4).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: MawaDesign.surfaceMuted,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => _navigateToWorkcenter(item),
                    borderRadius: BorderRadius.circular(11),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          MawaIconBadge(
                            icon: _getIconData(item.id),
                            color: MawaDesign.red,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  FeatureGroupRegistry.isGroupId(item.id)
                                      ? WorkcenterCardDescriptions.forGroup(
                                          item.id,
                                          item.description,
                                        )
                                      : WorkcenterCardDescriptions.forWorkcenter(
                                          item.id,
                                          item.description,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: MawaDesign.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: MawaDesign.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final theme = Theme.of(context);
    return MawaSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MawaSectionHeader(
            title: 'Recently used',
            description: 'Continue where you last worked.',
            trailing: _recentModules.isEmpty
                ? null
                : TextButton(
                    onPressed: () async {
                      await _moduleUsageService.resetUsage();
                      _fetchRecentModules();
                      _fetchFrequentModules();
                    },
                    child: const Text('Clear'),
                  ),
          ),
          const SizedBox(height: 14),
          if (_isLoadingRecent)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 38),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recentModules.isEmpty)
            const MawaEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No recent work yet',
              description: 'Workcenters you open will be listed here for quick access.',
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            )
          else
            ..._recentModules.take(5).map((usage) {
              final workcenter = _workcenterForUsage(usage);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: workcenter == null ? null : () => _navigateToWorkcenter(workcenter),
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      children: [
                        MawaIconBadge(
                          icon: _getIconData(usage.moduleCode),
                          color: MawaDesign.info,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            usage.moduleName ?? usage.moduleCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: MawaDesign.textSubtle,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Workcenter? _workcenterForUsage(ModuleUsage usage) {
    for (final item in _workcenters) {
      if (item.id == usage.moduleCode) return item;
    }
    if (usage.moduleCode.isEmpty) return null;
    return Workcenter(
      id: usage.moduleCode,
      description: usage.moduleName ?? usage.moduleCode,
      defaultFunction: '',
      path: usage.modulePath ?? '',
      position: 0,
      routeKey: usage.moduleCode,
      routePath: usage.modulePath,
    );
  }

  Widget _buildWorkcenterSection({
    required String title,
    required String description,
    required List<Workcenter> items,
    bool isReport = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MawaSectionHeader(title: title, description: description),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 224,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildWorkcenterCard(
                items[index],
                index: index,
                isReport: isReport,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWorkcenterCard(
    Workcenter workcenter, {
    required int index,
    required bool isReport,
  }) {
    final theme = Theme.of(context);
    final tint = isReport ? MawaDesign.warning : MawaDesign.iconTint(index);
    final description = workcenter.cardDescription ??
        (FeatureGroupRegistry.isGroupId(workcenter.id)
            ? WorkcenterCardDescriptions.forGroup(
                workcenter.id,
                workcenter.description,
              )
            : WorkcenterCardDescriptions.forWorkcenter(
                workcenter.id,
                workcenter.description,
              ));

    return Card(
      child: InkWell(
        onTap: () => _navigateToWorkcenter(workcenter),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MawaIconBadge(
                    icon: _getIconData(workcenter.id, workcenter.iconKey),
                    color: tint,
                    size: 48,
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: MawaDesign.surfaceMuted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: MawaDesign.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                workcenter.presentationTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: MawaDesign.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open  →',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: MawaDesign.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessSessionBanner(AccessProfile profile) {
    final isPlatform = profile.platformSession;
    final colour = isPlatform ? MawaDesign.red : MawaDesign.warning;
    final background = isPlatform ? MawaDesign.redSoft : MawaDesign.warningSoft;
    final title = isPlatform
        ? 'Platform administration session'
        : 'Test session — ${profile.accountType.replaceAll('_', ' ')}';
    final detail = isPlatform
        ? 'Tenant: ${profile.tenantId} • ${profile.displayName} • ${profile.accessReason.isEmpty ? 'No reason supplied' : profile.accessReason}'
        : profile.externalTransactionsBlocked
            ? 'External financial and integration transactions are disabled.'
            : 'Testing account restrictions are active for this environment.';

    return MawaSurface(
      color: background,
      border: Border.all(color: colour.withValues(alpha: 0.24)),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MawaIconBadge(
            icon: isPlatform ? Icons.shield_rounded : Icons.science_rounded,
            color: colour,
            size: 42,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colour,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(detail),
                if (profile.expiresAt != null)
                  Text('Access expires: ${profile.expiresAt!.toLocal()}'),
                if (profile.ticketReference.isNotEmpty)
                  Text('Reference: ${profile.ticketReference}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxButton() {
    final badgeCount = _inboxCounts.unreadCount;
    return Tooltip(
      message: _inboxCounts.pendingApprovalCount > 0
          ? '${_inboxCounts.pendingApprovalCount} approval item(s) waiting'
          : 'Inbox',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await context.push(AppRoutes.inbox);
            _loadInboxCounts();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: MawaDesign.textMuted),
                if (badgeCount > 0)
                  Positioned(
                    right: -7,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: MawaDesign.red,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MawaDesign.surface, width: 2),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
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

  Widget _buildUserMenu() {
    final theme = Theme.of(context);
    final displayName = _displayName?.trim().isNotEmpty == true ? _displayName! : 'User';
    final initial = displayName.substring(0, 1).toUpperCase();
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      tooltip: 'Account menu',
      onSelected: (value) {
        if (value == 'change_role') _changeRole();
        if (value == 'change_password') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
          );
        }
        if (value == 'printer_settings') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PosPrintingSettingsScreen()),
          );
        }
        if (value == 'installation_files') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SystemInstallationFilesScreen(),
            ),
          );
        }
        if (value == 'logout') _showLogoutConfirmation();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  _selectedRoleDisplay ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: MawaDesign.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'change_role',
          child: ListTile(
            leading: Icon(Icons.switch_account_outlined),
            title: Text('Switch role'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'change_password',
          child: ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('Security'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'printer_settings',
          child: ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Printer configuration'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'installation_files',
          child: ListTile(
            leading: Icon(Icons.install_desktop_outlined),
            title: Text('Installation files'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: MawaDesign.red),
            title: Text('Sign out', style: TextStyle(color: MawaDesign.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: MawaDesign.redSoft,
            child: Text(
              initial,
              style: const TextStyle(
                color: MawaDesign.redDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 860) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  'MAWA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: MawaDesign.textSubtle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '© 2026 MAWA',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MawaDesign.textSubtle,
                ),
          ),
          if (_appVersion.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              '• $_appVersion',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MawaDesign.textSubtle,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _inboxTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}


class _HomeWorkcenterSection {
  final String code;
  final String title;
  final String description;
  final int displayOrder;
  final List<Workcenter> items;

  const _HomeWorkcenterSection({
    required this.code,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.items,
  });
}
