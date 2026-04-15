import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../main.dart'; // To access Initializer for logout navigation
import '../auth/change_password_screen.dart';
import '../auth/role_selection_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _displayName;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _displayName = prefs.getString('displayName');
      _selectedRole = prefs.getString('selectedRole');
    });
  }

  Future<void> _changeRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) return;

    // Fetch roles again to ensure we have the latest list
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
                  Navigator.of(context).pop(); // Go back from selection screen
                  _loadUserInfo(); // Refresh UI with new role
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 24),
            const Text('You are now logged in.'),
          ],
        ),
      ),
    );
  }
}
