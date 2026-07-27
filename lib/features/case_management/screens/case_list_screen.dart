import 'package:flutter/material.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';
import 'case_detail_screen.dart';
import 'create_case_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  List<LegalCase> _cases = [];
  List<LegalCase> _filteredCases = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedStatus;

  final List<String> _statuses = [
    'OPEN',
    'IN_PROGRESS',
    'ON_HOLD',
    'SETTLED',
    'CLOSED',
    'CANCELLED'
  ];

  @override
  void initState() {
    super.initState();
    _fetchCases();
  }

  Future<void> _fetchCases() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cases = await _caseService.getCases();
      cases.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading cases: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredCases = _cases.where((c) {
        final matchesSearch = c.caseNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesStatus = _selectedStatus == null || c.status == _selectedStatus;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Case Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchCases,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(colorScheme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCases.isEmpty
                    ? _buildEmptyState()
                    : isTablet 
                        ? SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: _buildDataTable()))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCases.length,
                            itemBuilder: (context, index) => _buildCaseCard(_filteredCases[index]),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCaseScreen()),
          );
          if (result == true) {
            _fetchCases();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Case', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search by case number or title...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip(null, 'All'),
                ..._statuses.map((s) => _buildStatusFilterChip(s, s)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedStatus = val ? status : null;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildCaseCard(LegalCase c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      borderOnForeground: true,
      child: InkWell(
        onTap: () => _navigateToDetail(c.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.caseNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  _buildStatusChip(c.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(c.caseType, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.assignedTo ?? 'Unassigned', style: const TextStyle(fontSize: 13)),
                  Text(c.formattedBalance, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Case No')),
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Assigned')),
          DataColumn(label: Text('Balance')),
        ],
        rows: _filteredCases.map((c) {
          return DataRow(
            onSelectChanged: (_) => _navigateToDetail(c.id),
            cells: [
              DataCell(Text(c.caseNo)),
              DataCell(Text(c.title)),
              DataCell(Text(c.caseType)),
              DataCell(_buildStatusChip(c.status)),
              DataCell(Text(c.assignedTo ?? '-')),
              DataCell(Text(c.formattedBalance)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.blue[50],
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No cases found'));
  }

  void _navigateToDetail(String caseId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: caseId)),
    ).then((_) => _fetchCases());
  }
}
