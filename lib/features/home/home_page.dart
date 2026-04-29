import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../main.dart';
import '../auth/change_password_screen.dart';
import '../auth/role_selection_screen.dart';
import '../invoicing/screens/invoice_list_screen.dart';
import '../membership/screens/member_list_screen.dart';
import '../payments/screens/payment_request_list_screen.dart';
import '../partners/screens/partner_list_screen.dart';
import 'models/workcenter.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _displayName;
  String? _selectedRole;
  List<Workcenter> _workcenters = [];
  bool _isLoadingWorkcenters = true;

  @override
  void initState() {
    super.initState();
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
          _isLoadingWorkcenters = false;
        });
      } else {
        setState(() => _isLoadingWorkcenters = false);
      }
    } catch (e) {
      setState(() => _isLoadingWorkcenters = false);
    }
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
    switch (id.toLowerCase()) {
      case 'membership':
      case 'membership-approval':
        return Icons.people_outline;
      case 'claim':
      case 'claim-approval':
        return Icons.request_quote_outlined;
      case 'group-society':
        return Icons.groups;
      case 'invoicing':
        return Icons.receipt_long_outlined;
      case 'business-partner':
        return Icons.contact_page_outlined;
      default:
        return Icons.grid_view_outlined;
    }
  }

  void _navigateToWorkcenter(Workcenter wc) {
    final id = wc.id.toLowerCase();
    final description = wc.description.toLowerCase();

    if (id.contains('invoic')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const InvoiceListScreen()),
      );
    } else if (id.contains('membership')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MemberListScreen()),
      );
    } else if (id.contains('claim') || id.contains('payment') || description.contains('payment')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const PaymentRequestListScreen()),
      );
    } else if (id.contains('partner') || description.contains('partner')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const PartnerListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${wc.description} feature coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 160).floor().clamp(2, 8);

    return Scaffold(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: false,
        title: const Text(
          'Mawa ERP',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          const SizedBox(width: 8),
          Center(
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _displayName?[0] ?? 'U',
                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              onSelected: (value) {
                if (value == 'change_role') _changeRole();
                if (value == 'change_password') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
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
                const PopupMenuItem(value: 'change_role', child: ListTile(leading: Icon(Icons.switch_account_outlined), title: Text('Switch Role'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'change_password', child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Security'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Sign Out', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildCategoryTab('Dashboard', true),
                const SizedBox(width: 24),
                _buildCategoryTab('All Modules', false),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingWorkcenters
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${_displayName?.split(' ').first ?? 'User'}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _workcenters.length,
                          itemBuilder: (context, index) {
                            final wc = _workcenters[index];
                            return _buildWorkcenterTile(wc);
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (isSelected)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 3,
            width: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkcenterTile(Workcenter wc) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToWorkcenter(wc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getIconData(wc.id),
                  size: 32,
                  color: colorScheme.primary,
                ),
                const Spacer(),
                Text(
                  wc.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.8),
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
}
