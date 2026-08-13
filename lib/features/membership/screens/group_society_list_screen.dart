import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group_society.dart';
import '../services/membership_service.dart';
import 'group_society_detail_screen.dart';
import 'group_society_create_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class GroupSocietyListScreen extends StatefulWidget {
  const GroupSocietyListScreen({super.key});

  @override
  State<GroupSocietyListScreen> createState() => _GroupSocietyListScreenState();
}

class _GroupSocietyListScreenState extends State<GroupSocietyListScreen> {
  final MembershipService _membershipService = MembershipService();
  List<GroupSociety> _societies = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedStatus;
  final List<String> _statuses = ['ALL', 'ACTIVE', 'DORMANT', 'SUSPENDED', 'INACTIVE'];
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _fetchSocieties();
  }

  Future<void> _fetchSocieties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final societies = await _membershipService.getGroupSocieties(
        status: _selectedStatus,
        societyType: _selectedType,
      );

      societies.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _societies = societies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Group Societies'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSocieties,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget()
                    : _societies.isEmpty
                        ? _buildEmptyWidget()
                        : RefreshIndicator(
                            onRefresh: _fetchSocieties,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _societies.length,
                              itemBuilder: (context, index) {
                                final society = _societies[index];
                                return _buildSocietyCard(society, colorScheme);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GroupSocietyCreateScreen(),
            ),
          );
          if (result == true) _fetchSocieties();
        },
        label: const Text('New Society'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final selected = status == (_selectedStatus ?? 'ALL');
          return ChoiceChip(
            label: Text(status, style: const TextStyle(fontSize: 11)),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _selectedStatus = status == 'ALL' ? null : status);
              _fetchSocieties();
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchSocieties, child: const Text('RETRY')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No societies found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSocietyCard(GroupSociety society, ColorScheme colorScheme) {
    final displayName = society.displayName.isEmpty ? society.groupNo : society.displayName;
    final statusColor = _getStatusColor(society.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GroupSocietyDetailScreen(societyId: society.id),
            ),
          );
          if (result == true) _fetchSocieties();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('No: ${society.groupNo} • ${society.societyType}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusChip(society.status, statusColor),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniInfo('Balance', 'R ${society.availableBalance.toStringAsFixed(2)}', Colors.green),
                  _buildMiniInfo('Total Paid', 'R ${society.totalPaid.toStringAsFixed(2)}', Colors.blue),
                  _buildMiniInfo('Total Claimed', 'R ${society.totalClaimed.toStringAsFixed(2)}', Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDateInfo('Last Payment', society.lastPaymentDate),
                  _buildDateInfo('Last Claim', society.lastClaimDate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildDateInfo(String label, String? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(date ?? 'Never', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE': return Colors.green;
      case 'INACTIVE': return Colors.red;
      case 'DORMANT': return Colors.orange;
      case 'SUSPENDED': return Colors.grey;
      default: return Colors.blue;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Societies'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdownFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Society Type'),
                items: ['GROUP', 'SOCIETY', 'BURIAL'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDialogState(() => _selectedType = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _selectedType = null;
                });
                Navigator.pop(context);
                _fetchSocieties();
              },
              child: const Text('CLEAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _fetchSocieties();
              },
              child: const Text('APPLY'),
            ),
          ],
        ),
      ),
    );
  }
}
