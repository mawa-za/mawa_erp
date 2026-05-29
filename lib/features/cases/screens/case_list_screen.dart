import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    setState(() => _isLoading = true);
    try {
      final cases = await _caseService.getCases();
      setState(() {
        _cases = cases;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cases: $e')),
        );
      }
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
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCases,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCases.isEmpty
                    ? const Center(child: Text('No cases found'))
                    : isTablet ? _buildDataTable() : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateCaseScreen()),
          );
          if (result == true) {
            _fetchCases();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by case number or title...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedStatus == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = null;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                ..._statuses.map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = selected ? status : null;
                          _applyFilters();
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _filteredCases.length,
      itemBuilder: (context, index) {
        final c = _filteredCases[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text('${c.caseNo}: ${c.title}'),
            subtitle: Text('${c.caseType} • ${c.status} • Balance: ${c.formattedBalance}'),
            trailing: _buildPriorityChip(c.priority),
            onTap: () => _navigateToDetail(c.id),
          ),
        );
      },
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Case No')),
            DataColumn(label: Text('Title')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Assigned To')),
            DataColumn(label: Text('Opened Date')),
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
                DataCell(_buildPriorityChip(c.priority)),
                DataCell(Text(c.assignedTo ?? '-')),
                DataCell(Text(c.openedDate != null ? DateFormat('yyyy-MM-dd').format(c.openedDate!) : '-')),
                DataCell(Text(c.formattedBalance)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigateToDetail(String caseId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: caseId)),
    ).then((_) => _fetchCases());
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status) {
      case 'OPEN': color = Colors.blue; break;
      case 'IN_PROGRESS': color = Colors.orange; break;
      case 'CLOSED': color = Colors.green; break;
      case 'CANCELLED': color = Colors.red; break;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color = Colors.grey;
    switch (priority) {
      case 'URGENT': color = Colors.red; break;
      case 'HIGH': color = Colors.orange; break;
      case 'NORMAL': color = Colors.blue; break;
      case 'LOW': color = Colors.green; break;
    }
    return Chip(
      label: Text(priority, style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
