import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_billing_summary.dart';
import '../models/case_note.dart';
import '../models/case_event.dart';
import '../services/case_management_service.dart';
import '../widgets/case_status_chip.dart';
import '../widgets/case_priority_chip.dart';
import '../widgets/case_trust_account_tab.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> with SingleTickerProviderStateMixin {
  final CaseManagementService _caseService = CaseManagementService();
  late TabController _tabController;
  
  LegalCase? _case;
  CaseBillingSummary? _billingSummary;
  List<CaseTask> _tasks = [];
  List<CaseTimeEntry> _timeEntries = [];
  List<CaseDisbursement> _disbursements = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final c = await _caseService.getCaseById(widget.caseId);
      final billing = await _caseService.getBillingSummary(widget.caseId);
      final tasks = await _caseService.getTasks(widget.caseId);
      final time = await _caseService.getTimeEntries(widget.caseId);
      final disbursements = await _caseService.getDisbursements(widget.caseId);

      if (mounted) {
        setState(() {
          _case = c;
          _billingSummary = billing;
          _tasks = tasks;
          _timeEntries = time;
          _disbursements = disbursements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatCents(int cents) {
    return NumberFormat.currency(symbol: 'R ', locale: 'en_ZA').format(cents / 100);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_case == null) return const Scaffold(body: Center(child: Text('Case not found')));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_case!.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Time'),
            Tab(text: 'Disbursements'),
            Tab(text: 'Billing'),
            Tab(text: 'Trust Account'),
            Tab(text: 'Notes'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTasksTab(),
          _buildTimeTab(),
          _buildDisbursementsTab(),
          _buildBillingTab(),
          CaseTrustAccountTab(caseId: widget.caseId),
          const Center(child: Text('Notes - Coming Soon')),
          const Center(child: Text('Events - Coming Soon')),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('Case Details', [
            _buildInfoRow('Case No', _case!.caseNo),
            _buildInfoRow('Status', _case!.status, isStatus: true),
            _buildInfoRow('Priority', _case!.priority, isPriority: true),
            _buildInfoRow('Type', _case!.caseType),
            _buildInfoRow('Assigned To', _case!.assignedTo ?? 'Unassigned'),
          ]),
          const SizedBox(height: 16),
          _buildInfoCard('Financial Summary', [
            _buildInfoRow('Balance', _formatCents(_case!.balanceCents), isBold: true),
            _buildInfoRow('Total Fees', _formatCents(_case!.totalFeesCents)),
            _buildInfoRow('Total Disbursements', _formatCents(_case!.totalDisbursementsCents)),
          ]),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text(_tasks[i].title),
          subtitle: Text('Status: ${_tasks[i].status}'),
          trailing: Checkbox(
            value: _tasks[i].status == 'COMPLETED',
            onChanged: (val) async {
              await _caseService.updateTaskStatus(_tasks[i].id, val! ? 'COMPLETED' : 'TODO');
              _loadData();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _timeEntries.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text(_timeEntries[i].description),
          subtitle: Text('${_timeEntries[i].minutes} mins'),
          trailing: Text(_formatCents(_timeEntries[i].amountCents), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildDisbursementsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _disbursements.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text(_disbursements[i].description),
          trailing: Text(_formatCents(_disbursements[i].amountCents), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBillingTab() {
    if (_billingSummary == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow('Total Billable', _formatCents(_billingSummary!.totalBillableCents), isBold: true),
          _buildInfoRow('Unbilled Fees', _formatCents(_billingSummary!.unbilledFeesCents)),
          _buildInfoRow('Unbilled Disbursements', _formatCents(_billingSummary!.unbilledDisbursementsCents)),
          const Divider(),
          _buildInfoRow('Outstanding Balance', _formatCents(_billingSummary!.balanceCents), isBold: true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await _caseService.recalculateBilling(widget.caseId);
              _loadData();
            },
            child: const Text('Recalculate Billing'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false, bool isPriority = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          if (isStatus) CaseStatusChip(status: value)
          else if (isPriority) CasePriorityChip(priority: value)
          else Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
