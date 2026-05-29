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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cases = await _caseService.getCases();
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
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: const Color(0xFFF8F9FD),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(colorScheme),
          SliverToBoxAdapter(
            child: _buildFilterSection(colorScheme),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : _filteredCases.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : isTablet 
                        ? SliverToBoxAdapter(child: _buildDataTable())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildCaseCard(_filteredCases[index]),
                              childCount: _filteredCases.length,
                            ),
                          ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Case', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        elevation: 4,
      ),
    );
  }

  Widget _buildSliverAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Case Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.gavel_rounded, size: 140, color: Colors.white.withOpacity(0.1)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchCases,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFilterSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search by case number or title...',
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedStatus = val ? status : null;
            _applyFilters();
          });
        },
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? colorScheme.primary : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        checkmarkColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? colorScheme.primary : Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildCaseCard(LegalCase c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(c.id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Text(c.caseNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  _buildPrettyStatusChip(c.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(c.caseType, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(width: 16),
                  Icon(Icons.flag_outlined, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  _buildPrettyPriorityText(c.priority),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: Colors.blue[50], child: Icon(Icons.person, size: 14, color: Colors.blue[700])),
                      const SizedBox(width: 8),
                      Text(c.assignedTo ?? 'Unassigned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Text(c.formattedBalance, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F9)),
          dataRowMaxHeight: 70,
          columns: const [
            DataColumn(label: Text('Case Info', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Assigned', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredCases.map((c) {
            return DataRow(
              onSelectChanged: (_) => _navigateToDetail(c.id),
              cells: [
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.caseNo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )),
                DataCell(Text(c.caseType)),
                DataCell(_buildPrettyStatusChip(c.status)),
                DataCell(_buildPrettyPriorityText(c.priority)),
                DataCell(Text(c.assignedTo ?? '-')),
                DataCell(Text(c.formattedBalance, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPrettyStatusChip(String status) {
    Color color = Colors.blue;
    switch (status) {
      case 'OPEN': color = Colors.blue; break;
      case 'IN_PROGRESS': color = Colors.orange; break;
      case 'CLOSED': color = Colors.green; break;
      case 'CANCELLED': color = Colors.red; break;
      case 'SETTLED': color = Colors.purple; break;
      case 'ON_HOLD': color = Colors.amber; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPrettyPriorityText(String priority) {
    Color color = Colors.blue;
    switch (priority) {
      case 'URGENT': color = Colors.red; break;
      case 'HIGH': color = Colors.orange; break;
      case 'LOW': color = Colors.green; break;
      default: color = Colors.blue;
    }
    return Text(priority, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('No cases found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Try searching for something else or add a new case', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _navigateToDetail(String caseId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: caseId)),
    ).then((_) => _fetchCases());
  }
}
