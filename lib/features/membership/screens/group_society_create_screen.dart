import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';
import 'group_society_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class GroupSocietyCreateScreen extends StatefulWidget {
  const GroupSocietyCreateScreen({super.key});

  @override
  State<GroupSocietyCreateScreen> createState() => _GroupSocietyCreateScreenState();
}

class _GroupSocietyCreateScreenState extends State<GroupSocietyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _membershipService = MembershipService();
  bool _isSubmitting = false;

  Partner? _selectedPartner;
  final _groupNoController = TextEditingController();
  String _selectedType = 'GROUP';
  final List<String> _typeOptions = ['GROUP', 'SOCIETY', 'BURIAL'];

  Future<List<Partner>> _searchPartners(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching partners: $e');
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a partner organisation')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        "partnerId": _selectedPartner!.id,
        "groupNo": _groupNoController.text.trim(),
        "societyType": _selectedType,
        "status": "ACTIVE",
        "openingBalanceCents": 0
      };

      final response = await _membershipService.createGroupSociety(payload);
      final String? createdId = response['id'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group Society created successfully'), backgroundColor: Colors.green),
        );

        if (createdId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => GroupSocietyDetailScreen(societyId: createdId))
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to create: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('New Group Society'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.business_outlined, 'Select Partner'),
              const SizedBox(height: 12),
              _buildPartnerSelector(),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.assignment_outlined, 'Society Details'),
              const SizedBox(height: 12),
              _buildFormFields(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CREATE GROUP SOCIETY', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerSelector() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SearchAnchor(
              builder: (context, controller) => SearchBar(
                controller: controller,
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                hintText: 'Search Organisation/Group...',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              suggestionsBuilder: (context, controller) async {
                final partners = await _searchPartners(controller.text);
                return partners.map((p) => ListTile(
                  title: Text(p.fullName),
                  subtitle: Text('No: ${p.number} • ${p.type}'),
                  onTap: () {
                    setState(() => _selectedPartner = p);
                    controller.closeView(p.fullName);
                  },
                )).toList();
              },
            ),
            if (_selectedPartner != null) ...[
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.business),
                ),
                title: Text(_selectedPartner!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Partner No: ${_selectedPartner!.number}'),
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedPartner = null),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _groupNoController,
              decoration: const InputDecoration(
                labelText: 'Group Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Society Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New group societies start active with a zero balance. Use Balance Adjustment after creation to load an approved opening balance with supporting documents.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNoController.dispose();
    super.dispose();
  }
}
