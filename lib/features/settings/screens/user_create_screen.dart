import 'package:flutter/material.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';

class UserCreateScreen extends StatefulWidget {
  const UserCreateScreen({super.key});

  @override
  State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _cellphoneController = TextEditingController();
  
  String? _selectedPartnerId;
  String _selectedUserType = 'INTERNAL';
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _userTypes = ['INTERNAL', 'ADMIN', 'EXTERNAL'];

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a business partner'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await UserService().createUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        cellphone: _cellphoneController.text.trim(),
        userType: _selectedUserType,
        partnerId: _selectedPartnerId!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create User', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle('Account Details'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Initial Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Contact Information'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cellphoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Cellphone',
                      prefixIcon: Icon(Icons.phone_android_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('User Settings'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedUserType,
                    decoration: const InputDecoration(
                      labelText: 'User Type',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _userTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (v) => setState(() => _selectedUserType = v!),
                  ),
                  const SizedBox(height: 16),
                  PartnerSearchDropdown(
                    role: 'EMPLOYEE',
                    label: 'Business Partner (Employee)',
                    onPartnerSelected: (partner) {
                      setState(() {
                        _selectedPartnerId = partner?.id;
                      });
                    },
                    validator: (partner) => partner == null ? 'Please select a partner' : null,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saveUser,
                    icon: const Icon(Icons.save),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('CREATE USER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.1,
      ),
    );
  }
}
