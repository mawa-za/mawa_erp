import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/models/module_usage.dart';
import '../../core/services/module_usage_service.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/workcenter_route_registry.dart';
import '../../core/routing/feature_group_registry.dart';
import '../../core/routing/app_routes.dart';
import '../../core/models/access_profile.dart';
import '../../core/services/access_profile_service.dart';
import '../settings/models/role.dart';
import 'models/workcenter.dart';

// Import missing screens for legacy navigation fallback
import '../auth/role_selection_screen.dart';
import '../auth/change_password_screen.dart';
import '../settings/screens/api_log_list_screen.dart';
import '../invoicing/screens/invoice_create_screen.dart';
import '../membership/screens/membership_claim_list_screen.dart';
import '../membership/screens/membership_plan_list_screen.dart';
import '../payroll/screens/payroll_batch_list_screen.dart';
import '../membership/screens/group_society_list_screen.dart';
import '../payments/screens/payment_request_list_screen.dart';
import '../partners/screens/partner_list_screen.dart';
import '../cashup/screens/cashup_list_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserInfo();
    _loadAppVersion();
    _fetchRecentModules();
    _fetchFrequentModules();
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
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
    setState(() {
      if (query.isEmpty) {
        _filteredWorkcenters = _workcenters;
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredWorkcenters = _workcenters.where((wc) {
          return wc.description.toLowerCase().contains(lowercaseQuery) ||
                 wc.id.toLowerCase().contains(lowercaseQuery);
        }).toList();
      }
    });
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
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
              child: const Text('Sign Out'),
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

  IconData _getIconData(String id) {
    final lowerId = id.toLowerCase();
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
      moduleName: wc.description,
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
        SnackBar(content: Text('${wc.description} feature coming soon'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<Workcenter> _groupWorkcenters(List<Workcenter> workcenters) {
    final grouped = <String, List<Workcenter>>{};
    final ungrouped = <Workcenter>[];

    for (final workcenter in workcenters) {
      if (FeatureGroupRegistry.isStandaloneCard(
        workcenter.id,
        workcenter.description,
      )) {
        ungrouped.add(workcenter);
        continue;
      }

      final group = FeatureGroupRegistry.groupForWorkcenter(
        workcenter.id,
        workcenter.description,
      );
      if (group == null) {
        ungrouped.add(workcenter);
      } else {
        grouped.putIfAbsent(group.id, () => <Workcenter>[]).add(workcenter);
      }
    }

    final result = <Workcenter>[...ungrouped];
    for (final entry in grouped.entries) {
      final group = FeatureGroupRegistry.groupById(entry.key)!;
      final children = entry.value..sort((a, b) => a.position.compareTo(b.position));
      result.add(
        Workcenter(
          id: group.id,
          description: group.title,
          defaultFunction: '',
          path: group.routePath,
          position: children.first.position,
          routeKey: group.id,
          routePath: group.routePath,
          iconKey: 'group',
        ),
      );
    }

    result.sort((a, b) => a.position.compareTo(b.position));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 180).floor().clamp(2, 8);

    final moduleWorkcenters = _filteredWorkcenters
        .where((wc) => !wc.id.toLowerCase().contains('report') && !wc.description.toLowerCase().contains('report'))
        .toList();
    final modules = _groupWorkcenters(moduleWorkcenters);
    final reports = _filteredWorkcenters
        .where((wc) => wc.id.toLowerCase().contains('report') || wc.description.toLowerCase().contains('report'))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: _isLoadingWorkcenters
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(colorScheme),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_accessProfile != null &&
                            (_accessProfile!.platformSession || _accessProfile!.testUser)) ...[
                          _buildAccessSessionBanner(_accessProfile!),
                          const SizedBox(height: 24),
                        ],
                        if (!_isLoadingRecent && _recentModules.isNotEmpty) ...[
                          _buildRecentModulesSection(colorScheme),
                          const SizedBox(height: 32),
                        ],
                        if (!_isLoadingFrequent && _frequentModules.isNotEmpty) ...[
                          _buildFrequentModulesSection(colorScheme),
                          const SizedBox(height: 32),
                        ],
                        _buildSearchBar(colorScheme),
                        const SizedBox(height: 32),
                        if (modules.isNotEmpty) ...[
                          _buildSectionHeader('Operational Modules', Icons.rocket_launch_rounded),
                          const SizedBox(height: 16),
                          _buildAnimatedGrid(modules, crossAxisCount, colorScheme),
                          const SizedBox(height: 32),
                        ],
                        if (reports.isNotEmpty) ...[
                          _buildSectionHeader('Reports & Analytics', Icons.analytics_rounded),
                          const SizedBox(height: 16),
                          _buildAnimatedGrid(reports, crossAxisCount, colorScheme, isReport: true),
                          const SizedBox(height: 32),
                        ],
                        if (_filteredWorkcenters.isEmpty && _searchController.text.isNotEmpty)
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 48),
                                Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('No matching modules found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 40),
                        _buildFooter(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }


  Widget _buildAccessSessionBanner(AccessProfile profile) {
    final isPlatform = profile.platformSession;
    final background = isPlatform ? Colors.red.shade50 : Colors.orange.shade50;
    final border = isPlatform ? Colors.red.shade200 : Colors.orange.shade200;
    final iconColor = isPlatform ? Colors.red.shade700 : Colors.orange.shade800;
    final title = isPlatform
        ? 'PLATFORM ADMINISTRATION SESSION'
        : 'TEST SESSION — ${profile.accountType.replaceAll('_', ' ')}';
    final detail = isPlatform
        ? 'Tenant: ${profile.tenantId} • ${profile.displayName} • ${profile.accessReason.isEmpty ? 'No reason supplied' : profile.accessReason}'
        : profile.externalTransactionsBlocked
            ? 'External financial and integration transactions are disabled.'
            : 'Testing account restrictions are active for this environment.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPlatform ? Icons.shield_rounded : Icons.science_rounded,
              color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
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

  Widget _buildAppBar(ColorScheme colorScheme) {
    const textColor = Color(0xFF20252D);
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: textColor,
      iconTheme: const IconThemeData(color: textColor),
      actionsIconTheme: const IconThemeData(color: textColor),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: const Color(0xFFF8F9FD),
          child: Stack(
            children: [
              Positioned(
                top: -24,
                right: -24,
                child: Icon(
                  Icons.blur_on,
                  size: 200,
                  color: colorScheme.primary.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_displayName?.split(' ').first ?? 'User'}',
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Let\'s manage your business today',
                      style: TextStyle(
                        color: textColor.withOpacity(0.65),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/branding/mawa_logo.png',
            height: 34,
            width: 120,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
            semanticLabel: 'MAWA',
          ),
          if (_appVersion.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _appVersion,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        _buildUserMenu(colorScheme),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildUserMenu(ColorScheme colorScheme) {
    return Center(
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              _displayName?[0] ?? 'U',
              style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        onSelected: (value) {
          if (value == 'change_role') _changeRole();
          if (value == 'change_password') {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
          }
          if (value == 'logout') _showLogoutConfirmation();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                Text(_selectedRoleDisplay ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Divider(),
              ],
            ),
          ),
          const PopupMenuItem(value: 'change_role', child: ListTile(leading: Icon(Icons.switch_account_outlined), title: Text('Switch Role'), contentPadding: EdgeInsets.zero)),
          const PopupMenuItem(value: 'change_password', child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Security'), contentPadding: EdgeInsets.zero)),
          const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Sign Out', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  Widget _buildRecentModulesSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Recently Used', 
          Icons.history_rounded,
          onAction: () async {
            await _moduleUsageService.resetUsage();
            _fetchRecentModules();
            _fetchFrequentModules();
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentModules.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final usage = _recentModules[index];
              return InkWell(
                onTap: () {
                  final wc = _workcenters.firstWhere(
                    (w) => w.id == usage.moduleCode,
                    orElse: () => Workcenter(
                      id: usage.moduleCode,
                      description: usage.moduleName ?? 'Unknown',
                      defaultFunction: '',
                      path: '',
                      position: 0,
                      routeKey: usage.moduleCode,
                    ),
                  );
                  _navigateToWorkcenter(wc);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(usage.moduleCode),
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        usage.moduleName ?? 'Module',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrequentModulesSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Frequently Used', Icons.auto_graph_rounded),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _frequentModules.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final usage = _frequentModules[index];
              return InkWell(
                onTap: () {
                  final wc = _workcenters.firstWhere(
                    (w) => w.id == usage.moduleCode,
                    orElse: () => Workcenter(
                      id: usage.moduleCode,
                      description: usage.moduleName ?? 'Unknown',
                      defaultFunction: '',
                      path: '',
                      position: 0,
                      routeKey: usage.moduleCode,
                    ),
                  );
                  _navigateToWorkcenter(wc);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.secondaryContainer.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(usage.moduleCode),
                        color: colorScheme.secondary,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        usage.moduleName ?? 'Module',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search modules and reports...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary.withOpacity(0.5)),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  _applySearch('');
                },
              )
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              title, 
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                letterSpacing: -0.5,
                color: Color(0xFF1A1C1E),
              )
            ),
          ],
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildAnimatedGrid(List<Workcenter> items, int crossAxisCount, ColorScheme colorScheme, {bool isReport = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final double slide = 50 * (1.0 - _animationController.value);
            final double opacity = _animationController.value;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, slide),
                child: child,
              ),
            );
          },
          child: _buildWorkcenterTile(items[index], colorScheme, isReport: isReport),
        );
      },
    );
  }

  Widget _buildWorkcenterTile(Workcenter wc, ColorScheme colorScheme, {bool isReport = false}) {
    final tileColor = isReport ? Colors.orange : colorScheme.primary;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tileColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToWorkcenter(wc),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getIconData(wc.id), 
                    size: 26, 
                    color: tileColor,
                  ),
                ),
                const Spacer(),
                Text(
                  wc.description,
                  style: const TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w700, 
                    color: Color(0xFF1A1C1E),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            '© 2026 mawa',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
