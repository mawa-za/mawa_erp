import 'package:flutter/material.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';
import 'case_create_screen.dart';
import 'case_detail_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  bool _isLoading = true;
  List<LegalCase> _cases = [];
  
  final _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedClientId;
  String? _selectedAssignedTo;

  final List<String> _statuses = ['ALL', 'OPEN', 'IN_PROGRESS', 'ON_HOLD', 'SETTLED', 'CLOSED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _fetchCases();
  }

  Future<void> _fetchCases() async {
    setState(() => _isLoading = true);
    try {
      final cases = await _caseService.getCases(
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        clientPartnerId: _selectedClientId,
        assignedTo: _selectedAssignedTo,
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading cases: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Case Management'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCases,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(isWide, colorScheme),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _cases.isEmpty 
                ? _buildEmptyState()
                : _buildGridView(isWide, colorScheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const CaseCreateScreen())
        ).then((_) => _fetchCases()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(bool isWide, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isWide ? 300 : double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by case number or title...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _fetchCases(),
            ),
          ),
          _buildDropdownFilter(
            value: _selectedStatus ?? 'ALL',
            items: _statuses,
            onChanged: (val) {
              setState(() => _selectedStatus = val);
              _fetchCases();
            },
          ),
          SizedBox(
            width: isWide ? 200 : double.infinity,
            child: PartnerSearchDropdown(
              role: 'CLIENT',
              label: 'Filter by Client',
              onPartnerSelected: (partner) {
                setState(() => _selectedClientId = partner?.id);
                _fetchCases();
              },
            ),
          ),
          _buildUserFilter(isWide),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildUserFilter(bool isWide) {
    return FutureBuilder(
      future: UserService().getUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
        final users = snapshot.data ?? [];
        return Container(
          width: isWide ? 200 : double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _selectedAssignedTo,
            hint: const Text('Assigned To'),
            underline: const SizedBox(),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Users')),
              ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? ''))),
            ],
            onChanged: (val) {
              setState(() => _selectedAssignedTo = val);
              _fetchCases();
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView(bool isWide, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : 1,
        childAspectRatio: isWide ? 1.6 : 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _cases.length,
      itemBuilder: (context, index) => _buildCaseCard(_cases[index], colorScheme),
    );
  }

  Widget _buildCaseCard(LegalCase c, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: c.id))
        ).then((_) => _fetchCases()),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.caseNo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                  _buildStatusChip(c.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                c.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                c.caseType,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.clientPartnerName ?? 'Unknown Client',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPriorityIndicator(c.priority),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned To', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      Text(c.assignedToName ?? 'Unassigned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      Text(
                        c.balanceFormatted,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status.toUpperCase()) {
      case 'OPEN': color = Colors.blue; break;
      case 'IN_PROGRESS': color = Colors.orange; break;
      case 'CLOSED': color = Colors.green; break;
      case 'SETTLED': color = Colors.teal; break;
      case 'CANCELLED': color = Colors.red; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityIndicator(String priority) {
    Color color = Colors.grey;
    switch (priority.toUpperCase()) {
      case 'URGENT': color = Colors.red; break;
      case 'HIGH': color = Colors.orange; break;
      case 'NORMAL': color = Colors.blue; break;
      case 'LOW': color = Colors.green; break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 14, color: color),
        const SizedBox(width: 2),
        Text(priority, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No cases found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _fetchCases, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
