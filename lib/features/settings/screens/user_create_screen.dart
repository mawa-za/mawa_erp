import 'package:flutter/material.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../models/role.dart';
import '../services/role_service.dart';

class UserCreateScreen extends StatefulWidget {
  const UserCreateScreen({super.key});
  @override State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _cellphone = TextEditingController();
  final _environmentScope = TextEditingController();
  final _protectedReason = TextEditingController();
  final _expiry = TextEditingController();
  final _roleService = RoleService();
  String? _partnerId;
  String _userType = 'INTERNAL';
  String _accountType = 'STANDARD';
  bool _testUser = false;
  bool _blocked = false;
  bool _mfaRequired = false;
  bool _loading = false;
  bool _obscure = true;
  List<Role> _roles = [];
  final Set<String> _selectedRoles = {};

  @override void initState() { super.initState(); _loadRoles(); }
  Future<void> _loadRoles() async {
    try { final roles = await _roleService.getRoles(); if (mounted) setState(() => _roles = roles); } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all required fields, including the employee partner.')));
      return;
    }
    final expiresAt = _expiry.text.trim().isEmpty ? null : DateTime.tryParse('${_expiry.text.trim()}T23:59:59');
    if (_accountType == 'SUPPORT_VERIFICATION' && expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temporary support verification users require an expiry date.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await UserService().createUser(
        username: _username.text.trim(), password: _password.text,
        email: _email.text.trim(), cellphone: _cellphone.text.trim(),
        userType: _userType, partnerId: _partnerId!, accountType: _accountType,
        testUser: _testUser, protectedUser: _selectedRoleGrantsProtection,
        accessScope: _selectedRoleGrantsProtection ? 'TENANT_ALL' : 'STANDARD', environmentScope: _environmentScope.text.trim(),
        externalTransactionsBlocked: _blocked, expiresAt: expiresAt,
        protectedReason: _protectedReason.text.trim(), mfaRequired: _mfaRequired,
      );
      if (_selectedRoles.isNotEmpty) {
        await UserService().updateUserRoles(user.id, _selectedRoles.toList());
      }
      if (mounted) { Navigator.pop(context, true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully.'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create User')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        _title('Account details'),
        TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Username'), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _password, obscureText: _obscure, decoration: InputDecoration(labelText: 'Initial password', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => (v?.length ?? 0) < 6 ? 'Minimum 6 characters' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => !(v ?? '').contains('@') ? 'Valid email required' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _cellphone, decoration: const InputDecoration(labelText: 'Cellphone')),
        const SizedBox(height: 12),
        PartnerSearchDropdown(role: 'EMPLOYEE', label: 'Business Partner (Employee)', onPartnerSelected: (p) => setState(() => _partnerId = p?.id), validator: (p) => p == null ? 'Required' : null),
        const SizedBox(height: 24),
        _title('Access policy'),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _userType, decoration: const InputDecoration(labelText: 'User type'), items: ['INTERNAL','ADMIN','EXTERNAL'].map(_item).toList(), onChanged: (v) => setState(() => _userType = v!))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(value: _accountType, decoration: const InputDecoration(labelText: 'Account type'), items: ['STANDARD','QA_TESTER','AUTOMATION_TEST','DEMO_USER','SUPPORT_VERIFICATION'].map(_item).toList(), onChanged: (v) => setState(() { _accountType = v!; _testUser = v != 'STANDARD'; if (_testUser) { _blocked = true; if (_environmentScope.text.isEmpty) _environmentScope.text = 'DEV,ALPHA,BETA'; } }))),
        ]),
        const SizedBox(height: 12),
        InputDecorator(decoration: const InputDecoration(labelText: 'Access scope', helperText: 'Derived from roles maintained in Role Maintenance'), child: Text(_selectedRoleGrantsProtection ? 'TENANT_ALL' : 'STANDARD')),
        SwitchListTile(value: _testUser, title: const Text('Testing user'), onChanged: (v) => setState(() { _testUser = v; if (v) { _blocked = true; if (_environmentScope.text.isEmpty) _environmentScope.text = 'DEV,ALPHA,BETA'; } })),
        SwitchListTile(value: _selectedRoleGrantsProtection, title: const Text('Protected — cannot be deleted'), subtitle: const Text('Derived only from a role that grants all current and future workcentres.'), onChanged: null),
        SwitchListTile(value: _blocked, title: const Text('Block external transactions'), onChanged: (v) => setState(() => _blocked = v)),
        SwitchListTile(value: _mfaRequired, title: const Text('MFA required'), onChanged: (v) => setState(() => _mfaRequired = v)),
        TextField(controller: _environmentScope, decoration: const InputDecoration(labelText: 'Environment scope', helperText: 'Example: DEV,ALPHA,BETA or ALL')),
        const SizedBox(height: 12),
        TextField(controller: _expiry, decoration: const InputDecoration(labelText: 'Expiry date', helperText: 'YYYY-MM-DD')),
        const SizedBox(height: 12),
        TextField(controller: _protectedReason, decoration: const InputDecoration(labelText: 'Protection/access reason')),
        const SizedBox(height: 24),
        _title('Roles from Role Maintenance'),
        Wrap(spacing: 8, runSpacing: 8, children: _roles.map((r) => FilterChip(avatar: (r.protectedRole || r.accessAllWorkcentres) ? const Icon(Icons.shield, size: 16) : null, label: Text(r.id), selected: _selectedRoles.contains(r.id), onSelected: (v) => setState(() { v ? _selectedRoles.add(r.id) : _selectedRoles.remove(r.id); if (_selectedRoleGrantsProtection) _mfaRequired = true; }))).toList()),
        const SizedBox(height: 28),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Padding(padding: EdgeInsets.all(14), child: Text('CREATE USER'))),
      ]),
    ),
  );

  bool get _selectedRoleGrantsProtection => _roles.any(
      (role) => _selectedRoles.contains(role.id) && role.accessAllWorkcentres);

  DropdownMenuItem<String> _item(String value) => DropdownMenuItem(value: value, child: Text(value.replaceAll('_', ' ')));
  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;
  Widget _title(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)));
}
