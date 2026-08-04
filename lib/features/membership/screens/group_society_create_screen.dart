import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/product_lookup.dart';
import '../../../core/services/product_lookup_service.dart';
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
  final _productService = ProductLookupService();
  bool _isSubmitting = false;
  bool _isLoadingProducts = true;
  String? _productLoadError;

  final _groupNameController = TextEditingController();
  final _groupNoController = TextEditingController();
  List<ProductLookup> _products = const [];
  String? _selectedProductId;
  String _selectedType = 'GROUP';
  final List<String> _typeOptions = ['GROUP', 'SOCIETY', 'BURIAL'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productLoadError = null;
    });
    try {
      final products = await _productService.getProducts(
        type: 'GROUP-SOCIETY',
        forceRefresh: true,
        strictType: true,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _selectedProductId = products.length == 1 ? products.first.id : null;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _selectedProductId = null;
        _productLoadError = friendlyErrorMessage(error);
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Group Society product')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'groupName': _groupNameController.text.trim(),
        'productId': _selectedProductId,
        'groupNo': _groupNoController.text.trim(),
        'societyType': _selectedType,
        'status': 'ACTIVE',
        'openingBalanceCents': 0,
      };

      final response = await _membershipService.createGroupSociety(payload);
      final String? createdId = response['id']?.toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group Society and Group Partner created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (createdId != null && createdId.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GroupSocietyDetailScreen(societyId: createdId),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Failed to create: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildSectionHeader(Icons.groups_outlined, 'Group Partner'),
              const SizedBox(height: 12),
              _buildGroupPartnerFields(),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.assignment_outlined, 'Society Details'),
              const SizedBox(height: 12),
              _buildSocietyFields(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSubmitting || _isLoadingProducts || _products.isEmpty
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'CREATE GROUP SOCIETY',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildGroupPartnerFields() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _groupNameController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: const InputDecoration(
              labelText: 'Group / Society Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Group / society name is required'
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'A GROUP-type Business Partner will be created automatically and linked to this Group Society.',
          ),
        ],
      ),
    );
  }

  Widget _buildSocietyFields() {
    return _card(
      child: Column(
        children: [
          TextFormField(
            controller: _groupNoController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Group Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _buildProductField(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Society Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _typeOptions
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _selectedType = value!),
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
    );
  }

  Widget _buildProductField() {
    if (_isLoadingProducts) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircularProgressIndicator(),
        title: Text('Loading Group Society products...'),
      );
    }
    if (_productLoadError != null || _products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _productLoadError ?? 'No active Group Society products were found.',
              style: TextStyle(color: Colors.amber.shade900),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload Products'),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedProductId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Group Society Product',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory_2_outlined),
      ),
      items: _products
          .map(
            (product) => DropdownMenuItem(
              value: product.id,
              child: Text('${product.code} - ${product.description}'),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedProductId = value),
      validator: (value) => value == null || value.isEmpty ? 'Select a product' : null,
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupNoController.dispose();
    super.dispose();
  }
}
