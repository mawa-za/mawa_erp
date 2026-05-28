import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../models/case_billing_summary.dart';
import '../services/case_management_service.dart';
import '../widgets/case_overview_tab.dart';
import '../widgets/case_tasks_tab.dart';
import '../widgets/case_time_entries_tab.dart';
import '../widgets/case_disbursements_tab.dart';
import '../widgets/case_billing_tab.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> with SingleTickerProviderStateMixin {
  final CaseManagementService _caseService = CaseManagementService();
  late TabController _tabController;
  
  LegalCase? _legalCase;
  CaseBillingSummary? _billingSummary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _caseService.getCaseById(widget.caseId),
        _caseService.getBillingSummary(widget.caseId),
      ]);

      setState(() {
        _legalCase = results[0] as LegalCase;
        _billingSummary = results[1] as CaseBillingSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _legalCase == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Failed to load case details'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 900;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(_legalCase!.caseNo),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Time'),
            Tab(text: 'Disbursements'),
            Tab(text: 'Billing'),
            Tab(text: 'Notes'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(isWide, colorScheme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CaseOverviewTab(legalCase: _legalCase!),
                CaseTasksTab(caseId: widget.caseId),
                CaseTimeEntriesTab(caseId: widget.caseId, defaultHourlyRate: _legalCase!.hourlyRateCents),
                CaseDisbursementsTab(caseId: widget.caseId),
                CaseBillingTab(caseId: widget.caseId, billingSummary: _billingSummary, onRefresh: _loadData),
                _buildPlaceholderTab('Notes', Icons.note_alt_outlined),
                _buildPlaceholderTab('Events', Icons.event_note_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isWide, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _legalCase!.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        _buildChip(_legalCase!.status, _getStatusColor(_legalCase!.status)),
                        const SizedBox(width: 8),
                        _buildChip(_legalCase!.priority, _getPriorityColor(_legalCase!.priority)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _buildHeaderInfo(Icons.person_outline, 'Client', _legalCase!.clientPartnerName ?? _legalCase!.clientPartnerId ?? 'N/A'),
                        _buildHeaderInfo(Icons.assignment_ind_outlined, 'Assigned', _legalCase!.assignedToName ?? 'Unassigned'),
                        _buildHeaderInfo(Icons.gavel_outlined, 'Court', _legalCase!.courtName ?? 'N/A'),
                        _buildHeaderInfo(Icons.tag, 'Court No', _legalCase!.courtCaseNo ?? 'N/A'),
                        _buildHeaderInfo(Icons.calendar_today_outlined, 'Opened', _legalCase!.openedDate != null ? DateFormat('dd MMM yyyy').format(_legalCase!.openedDate!) : 'N/A'),
                        _buildHeaderInfo(Icons.event_outlined, 'Next Appearance', _legalCase!.nextAppearanceDate != null ? DateFormat('dd MMM yyyy').format(_legalCase!.nextAppearanceDate!) : 'None set'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_billingSummary != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBillingCard('Total Fees', _billingSummary!.totalFeesFormatted, colorScheme.primary),
                  _buildBillingCard('Disbursements', _billingSummary!.totalDisbursementsFormatted, Colors.orange),
                  _buildBillingCard('Total Billable', _billingSummary!.totalBillableFormatted, Colors.blue),
                  _buildBillingCard('Total Billed', _billingSummary!.totalBilledFormatted, Colors.teal),
                  _buildBillingCard('Balance', _billingSummary!.balanceFormatted, Colors.red, isNegative: _billingSummary!.balanceCents > 0),
                  _buildBillingCard('Time Spent', '${_billingSummary!.totalTimeMinutes}m', Colors.purple),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildBillingCard(String label, String value, Color color, {bool isNegative = false}) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isNegative ? Colors.red : color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'CLOSED': return Colors.green;
      case 'SETTLED': return Colors.teal;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'NORMAL': return Colors.blue;
      case 'LOW': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('$title feature coming soon', style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
