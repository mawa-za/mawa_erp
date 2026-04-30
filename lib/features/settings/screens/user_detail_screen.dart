import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = true;
  User? _user;
  List<String> _roles = [];
  String? _error;

  // This would ideally come from an API (e.g., GET /role)
  final List<String> _availableRoles = [
    'SYSTEM-ADMINISTRATOR',
    'MEMBERSHIP-MAINTAINER',
    'INVOICE-CLERK',
    'PAYMENT-OFFICER',
    'PARTNER-MANAGER',
    'REPORT-VIEWER',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await UserService().getUser(widget.userId);
      final roles = await UserService().getUserRoles(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAction(String action) async {
    try {
      if (action == 'lock') await UserService().lockUser(widget.userId);
      if (action == 'unlock') await UserService().unlockUser(widget.userId);
      if (action == 'reset') await UserService().resetUser(widget.userId);
      
      _fetchUserDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $action successful'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _manageRoles() async {
    List<String> selectedRoles = List.from(_roles);
    final colorScheme = Theme.of(context).colorScheme;

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage User Roles'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _availableRoles.map((role) {
                final isSelected = selectedRoles.contains(role);
                return CheckboxListTile(
                  title: Text(role.replaceAll('-', ' '), style: const TextStyle(fontSize: 14)),
                  value: isSelected,
                  activeColor: colorScheme.primary,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedRoles.add(role);
                      } else {
                        selectedRoles.remove(role);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedRoles),
              child: const Text('SAVE ROLES'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await UserService().updateUserRoles(widget.userId, result);
        _fetchUserDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Roles updated successfully'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('User Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_user != null)
            PopupMenuButton<String>(
              onSelected: _handleAction,
              itemBuilder: (context) => [
                if (_user!.status.toUpperCase() == 'ACTIVE')
                  const PopupMenuItem(value: 'lock', child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Lock User'), contentPadding: EdgeInsets.zero)),
                if (_user!.status.toUpperCase() == 'LOCKED')
                  const PopupMenuItem(value: 'unlock', child: ListTile(leading: Icon(Icons.lock_open_outlined), title: Text('Unlock User'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'reset', child: ListTile(leading: Icon(Icons.restart_alt), title: Text('Reset Password'), contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildUserContent(colorScheme),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Failed to load user', style: Theme.of(context).textTheme.titleMedium),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _fetchUserDetails, icon: const Icon(Icons.refresh), label: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildUserContent(ColorScheme colorScheme) {
    final user = _user!;
    final partner = user.partner;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(user, colorScheme),
          const SizedBox(height: 16),
          
          _buildInfoSection(
            'Assigned Roles', 
            [
              if (_roles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No roles assigned', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _roles.map((role) => Chip(
                    label: Text(role, style: const TextStyle(fontSize: 12)),
                    backgroundColor: colorScheme.secondaryContainer,
                    labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
                    side: BorderSide.none,
                  )).toList(),
                ),
            ],
            action: TextButton.icon(
              onPressed: _manageRoles,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Manage'),
            ),
          ),
          
          const SizedBox(height: 16),
          _buildInfoSection('User Information', [
            _buildInfoTile('Username', user.username, Icons.person_outline),
            _buildInfoTile('Email', user.email ?? 'Not provided', Icons.email_outlined),
            _buildInfoTile('Cellphone', user.cellphone ?? 'Not provided', Icons.phone_android_outlined),
            _buildInfoTile('User Type', user.type, Icons.badge_outlined),
            _buildInfoTile('Password Status', user.passwordStatus ?? 'N/A', Icons.security_outlined),
          ]),
          if (partner != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection('Partner Profile', [
              _buildInfoTile('Full Name', partner.fullName, Icons.contact_page_outlined),
              _buildInfoTile('Partner No', partner.number, Icons.numbers),
              _buildInfoTile('Gender', partner.gender ?? 'N/A', Icons.wc),
              _buildInfoTile('Birth Date', partner.birthDate ?? 'N/A', Icons.cake_outlined),
              _buildInfoTile('Language', partner.language ?? 'N/A', Icons.language_outlined),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(User user, ColorScheme colorScheme) {
    final bool isActive = user.status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(user.username[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(user.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: isActive ? Colors.green[400] : Colors.orange[400], borderRadius: BorderRadius.circular(8)),
                  child: Text(user.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
              if (action != null) action,
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
