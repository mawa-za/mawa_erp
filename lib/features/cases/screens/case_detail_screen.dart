import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_billing_summary.dart';
import '../models/case_note.dart';
import '../models/case_event.dart';
import '../models/case_party.dart';
import '../models/case_invoice_preview.dart';
import '../services/case_management_service.dart';
import '../widgets/case_status_chip.dart';
import '../widgets/case_priority_chip.dart';
import '../widgets/case_trust_account_tab.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  final String? initialTab;
  const CaseDetailScreen({super.key, required this.caseId, this.initialTab});

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
  List<CaseParty> _parties = [];
  CaseInvoicePreview? _invoicePreview;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    if (widget.initialTab != null) {
      _tabController.index = _getTabIndex(widget.initialTab!);
    }
    _loadData();
  }

  int _getTabIndex(String tab) {
    switch (tab.toLowerCase()) {
      case 'overview': return 0;
      case 'tasks': return 1;
      case 'time': return 2;
      case 'disbursements': return 3;
      case 'billing': return 4;
      case 'trust': return 5;
      case 'notes': return 6;
      case 'events': return 7;
      case 'parties': return 8;
      case 'invoice-preview': return 9;
      default: return 0;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final c = await _caseService.getCaseById(widget.caseId);
      final billing = await _caseService.getBillingSummary(widget.caseId);
      final tasks = await _caseService.getTasks(widget.caseId);
      final time = await _caseService.getTimeEntries(widget.caseId);
      final disbursements = await _caseService.getDisbursements(widget.caseId);
      
      // Optional/Newer data
      List<CaseParty> parties = [];
      try { parties = await _caseService.getParties(widget.caseId); } catch (_) {}
      
      CaseInvoicePreview? preview;
      try { preview = await _caseService.getInvoicePreview(widget.caseId); } catch (_) {}

      if (mounted) {
        setState(() {
          _case = c;
          _billingSummary = billing;
          _tasks = tasks;
          _timeEntries = time;
          _disbursements = disbursements;
          _parties = parties;
          _invoicePreview = preview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
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
            Tab(text: 'Parties'),
            Tab(text: 'Invoice Preview'),
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
          _buildPartiesTab(),
          _buildInvoicePreviewTab(),
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

  Widget _buildPartiesTab() {
    if (_parties.isEmpty) return const Center(child: Text('No parties added yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _parties.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          title: Text(_parties[i].partyName),
          subtitle: Text(_parties[i].partyType),
          trailing: const Icon(Icons.person_outline),
        ),
      ),
    );
  }

  Widget _buildInvoicePreviewTab() {
    if (_invoicePreview == null) return const Center(child: Text('No invoice preview available'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice Preview for ${_case?.caseNo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          _buildInfoRow('Total Fees', _formatCents(_invoicePreview!.totalFeesCents)),
          _buildInfoRow('Total Disbursements', _formatCents(_invoicePreview!.totalDisbursementsCents)),
          const Divider(),
          _buildInfoRow('Grand Total', _formatCents(_invoicePreview!.totalInvoiceCents), isBold: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await _caseService.generateInvoice(widget.caseId);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice generated successfully')));
                  _loadData();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                }
              },
              child: const Text('GENERATE INVOICE'),
            ),
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
