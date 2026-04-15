import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../main.dart';
import '../auth/change_password_screen.dart';
import '../auth/role_selection_screen.dart';
import '../invoicing/screens/invoice_list_screen.dart';
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
          // Sort by position as provided in the sample response
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No other roles available.')),
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
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
        return Icons.people;
      case 'claim':
      case 'claim-approval':
        return Icons.request_quote;
      case 'group-society':
        return Icons.groups;
      case 'invoicing':
        return Icons.receipt_long;
      default:
        return Icons.apps;
    }
  }

  void _navigateToWorkcenter(Workcenter wc) {
    if (wc.id.toLowerCase().contains('invoic')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const InvoiceListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${wc.description} feature coming soon')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_role') {
                _changeRole();
              } else if (value == 'change_password') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                );
              } else if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'change_role',
                child: ListTile(
                  leading: Icon(Icons.switch_account_outlined),
                  title: Text('Switch Role'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'change_password',
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Change Password'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: <Widget>[
            const Icon(Icons.account_circle, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${_displayName ?? 'User'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (_selectedRole != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(_selectedRole!),
                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Workcenters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingWorkcenters
                ? const Center(child: CircularProgressIndicator())
                : _workcenters.isEmpty
                    ? const Text('No workcenters assigned to this role.')
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
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
    );
  }

  Widget _buildWorkcenterTile(Workcenter wc) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToWorkcenter(wc),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(wc.id),
                  size: 32,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                wc.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
