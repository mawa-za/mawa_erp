import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../main.dart';
import '../auth/change_password_screen.dart';
import '../auth/role_selection_screen.dart';
import '../invoicing/screens/invoice_create_screen.dart';
import '../invoicing/screens/invoice_list_screen.dart';
import '../membership/screens/member_list_screen.dart';
import '../membership/screens/membership_plan_list_screen.dart';
import '../membership/screens/membership_claim_list_screen.dart';
import '../payments/screens/payment_request_list_screen.dart';
import '../payroll/screens/payroll_batch_list_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/user_list_screen.dart';
import '../settings/screens/company_info_screen.dart';
import '../settings/screens/system_configuration_screen.dart';
import '../partners/screens/partner_list_screen.dart';
import '../cashup/screens/cashup_list_screen.dart';
import '../approvals/screens/approval_workflow_list_screen.dart';
import '../approvals/screens/approval_list_screen.dart';
import 'models/workcenter.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  String? _displayName;
  String? _selectedRole;
  List<Workcenter> _workcenters = [];
  List<Workcenter> _filteredWorkcenters = [];
  bool _isLoadingWorkcenters = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('selectedRole');
    setState(() {
      _displayName = prefs.getString('displayName');
      _selectedRole = role;
    });
    if (role != null) {
      _fetchWorkcenters(role);
    } else {
      setState(() => _isLoadingWorkcenters = false);
    }
  }

  Future<void> _fetchWorkcenters(String role) async {
    setState(() => _isLoadingWorkcenters = true);
    try {
      final response = await ApiClient().get('/role/$role/workcenter');
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

    final response = await ApiClient().get('/user/$userId/role');
    
    if (response.statusCode == 200) {
      final List<dynamic> roles = jsonDecode(response.body);
      final List<String> roleList = roles.cast<String>();

      if (roleList.length > 1) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('selectedRole');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Initializer()),
        (route) => false,
      );
    }
  }

  IconData _getIconData(String id) {
    final lowerId = id.toLowerCase();
    if (lowerId.contains('membership') || lowerId.contains('member')) return Icons.people_rounded;
    if (lowerId.contains('plan') || lowerId.contains('product')) return Icons.inventory_2_rounded;
    if (lowerId.contains('payroll')) return Icons.payments_rounded;
    if (lowerId.contains('claim')) return Icons.request_quote_rounded;
    if (lowerId.contains('payment')) return Icons.account_balance_wallet_rounded;
    if (lowerId.contains('group') || lowerId.contains('society')) return Icons.groups_rounded;
    if (lowerId.contains('invoic')) return Icons.description_rounded;
    if (lowerId.contains('partner')) return Icons.business_center_rounded;
    if (lowerId.contains('user')) return Icons.person_add_rounded;
    if (lowerId.contains('setting')) return Icons.settings_suggest_rounded;
    if (lowerId.contains('report')) return Icons.bar_chart_rounded;
    if (lowerId.contains('company')) return Icons.domain_rounded;
    if (lowerId.contains('cashup')) return Icons.point_of_sale_rounded;
    if (lowerId.contains('workflow')) return Icons.account_tree_rounded;
    if (lowerId.contains('approval')) return Icons.fact_check_rounded;
    if (lowerId.contains('config') || lowerId.contains('role')) return Icons.settings_applications_rounded;
    return Icons.apps_rounded;
  }

  void _navigateToWorkcenter(Workcenter wc) {
    final id = wc.id.toLowerCase();
    final description = wc.description.toLowerCase();

    if (id.contains('invoic') || description.contains('invoic')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InvoiceListScreen()));
    } else if (id.contains('plan') || description.contains('plan') || id.contains('product')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MembershipPlanListScreen()));
    } else if (id.contains('membership') || id.contains('member') || description.contains('membership')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MemberListScreen()));
    } else if (id.contains('payroll') || description.contains('payroll')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PayrollBatchListScreen()));
    } else if (id.contains('claim') || description.contains('claim')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MembershipClaimListScreen()));
    } else if (id.contains('payment') || description.contains('payment')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaymentRequestListScreen()));
    } else if (id.contains('partner') || description.contains('partner')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PartnerListScreen()));
    } else if (id.contains('user') || id.contains('setting') || id.contains('company') || id.contains('workflow') || id.contains('config') || id.contains('role')) {
      // All configuration consolidated under System Configuration module
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SystemConfigurationScreen()));
    } else if (id.contains('cashup') || description.contains('cashup')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CashupListScreen()));
    } else if (id.contains('approval')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ApprovalListScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${wc.description} feature coming soon'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 180).floor().clamp(2, 8);

    final modules = _filteredWorkcenters.where((wc) => !wc.id.toLowerCase().contains('report') && !wc.description.toLowerCase().contains('report')).toList();
    final reports = _filteredWorkcenters.where((wc) => wc.id.toLowerCase().contains('report') || wc.description.toLowerCase().contains('report')).toList();

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
                        _buildQuickActions(colorScheme),
                        const SizedBox(height: 32),
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

  Widget _buildAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Icon(Icons.blur_on, size: 200, color: Colors.white.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_displayName?.split(' ').first ?? 'User'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Let\'s manage your business today',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
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
      title: const Text('Mawa ERP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
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
          if (value == 'company_info') {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CompanyInfoScreen(isReadOnly: true)));
          }
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
                Text(_selectedRole ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Divider(),
              ],
            ),
          ),
          const PopupMenuItem(value: 'company_info', child: ListTile(leading: Icon(Icons.business_outlined), title: Text('Company Profile'), contentPadding: EdgeInsets.zero)),
          const PopupMenuItem(value: 'change_role', child: ListTile(leading: Icon(Icons.switch_account_outlined), title: Text('Switch Role'), contentPadding: EdgeInsets.zero)),
          const PopupMenuItem(value: 'change_password', child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Security'), contentPadding: EdgeInsets.zero)),
          const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Sign Out', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quick Actions', Icons.bolt_rounded),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildQuickActionBtn(
              colorScheme, 
              Icons.add_task_rounded, 
              'New Invoice', 
              Colors.blue,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InvoiceCreateScreen())),
            ),
            const SizedBox(width: 12),
            _buildQuickActionBtn(
              colorScheme, 
              Icons.person_add_alt_1_rounded, 
              'Add Member', 
              Colors.green,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MemberListScreen())), // Navigate to list, assuming they can add from there
            ),
            const SizedBox(width: 12),
            _buildQuickActionBtn(
              colorScheme, 
              Icons.request_quote_rounded, 
              'Payment', 
              Colors.orange,
              () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaymentRequestListScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn(ColorScheme colorScheme, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
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
            '© 2025 Mawa ERP',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0+1',
            style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w300),
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
