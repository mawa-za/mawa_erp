import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_billing_summary.dart';
import '../models/case_party.dart';
import '../models/case_note.dart';
import '../models/case_event.dart';
import '../services/case_management_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/models/user.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/case_status_chip.dart';
import '../widgets/case_priority_chip.dart';
import '../widgets/add_party_dialog.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/add_note_dialog.dart';
import '../widgets/add_time_entry_dialog.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/add_disbursement_dialog.dart';
import '../widgets/case_billing_cards.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> with SingleTickerProviderStateMixin {
  final CaseManagementService _caseService = CaseManagementService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  
  LegalCase? _case;
  CaseBillingSummary? _billingSummary;
  List<CaseTask> _tasks = [];
  List<CaseTimeEntry> _timeEntries = [];
  List<CaseDisbursement> _disbursements = [];
  List<CaseParty> _parties = [];
  List<CaseNote> _notes = [];
  List<CaseEvent> _events = [];
  List<User> _users = [];
  
  bool _isLoading = true;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadInitialData();
    _fetchUsers();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _refreshCurrentTabData();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _caseService.getCaseById(widget.caseId),
        _caseService.getBillingSummary(widget.caseId),
      ]);
      if (mounted) {
        setState(() {
          _case = results[0] as LegalCase;
          _billingSummary = results[1] as CaseBillingSummary;
          _isLoading = false;
        });
        _refreshCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await _userService.getUsers();
      if (mounted) setState(() => _users = users);
    } catch (_) {}
  }

  void _refreshCurrentTabData() async {
    if (_case == null) return;
    setState(() => _isLoadingData = true);
    try {
      switch (_tabController.index) {
        case 1: _parties = await _caseService.getParties(widget.caseId); break;
        case 2: _tasks = await _caseService.getTasks(widget.caseId); break;
        case 3: _timeEntries = await _caseService.getTimeEntries(widget.caseId); break;
        case 4: _disbursements = await _caseService.getDisbursements(widget.caseId); break;
        case 5: _billingSummary = await _caseService.getBillingSummary(widget.caseId); break;
        case 6: _notes = await _caseService.getNotes(widget.caseId); break;
        case 7: _events = await _caseService.getEvents(widget.caseId); break;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_case == null) return const Scaffold(body: Center(child: Text('Case not found')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_case!.caseNo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(_case!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Parties'),
            Tab(text: 'Tasks'),
            Tab(text: 'Time'),
            Tab(text: 'Disbursements'),
            Tab(text: 'Billing'),
            Tab(text: 'Notes'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildPartiesTab(),
          _buildTasksTab(),
          _buildTimeTab(),
          _buildDisbursementsTab(),
          _buildBillingTab(),
          _buildNotesTab(),
          _buildEventsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCaseHeader(),
          const SizedBox(height: 24),
          if (_billingSummary != null) CaseBillingCards(summary: _billingSummary!),
          const SizedBox(height: 24),
          _buildDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildCaseHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLIENT', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(_case!.clientPartnerId, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    CaseStatusChip(status: _case!.status),
                    const SizedBox(width: 8),
                    CasePriorityChip(priority: _case!.priority),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _headerInfo('ASSIGNED TO', _case!.assignedTo ?? 'Unassigned'),
                _headerInfo('COURT', _case!.courtName ?? 'N/A'),
                _headerInfo('OPENED', Formatters.formatFriendlyDate(_case!.openedDate)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(_case!.description ?? 'No description.'),
            const Divider(height: 32),
            _detailRow('Case Type', _case!.caseType),
            _detailRow('Category', _case!.caseCategory ?? 'N/A'),
            _detailRow('Court Case No', _case!.courtCaseNo ?? 'N/A'),
            _detailRow('Forum Type', _case!.forumType ?? 'N/A'),
            _detailRow('Billing Type', _case!.billingType),
            _detailRow('Rate', _case!.billingType == 'HOURLY' ? Formatters.formatCentsAsRand(_case!.hourlyRateCents) + '/hr' : Formatters.formatCentsAsRand(_case!.fixedFeeCents) + ' Fixed'),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit_outlined), label: const Text('Edit Case')),
                const SizedBox(width: 12),
                if (_case!.status != 'CLOSED')
                  OutlinedButton.icon(
                    onPressed: _showCloseConfirmation,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close Case'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(color: Colors.grey))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Case'),
        content: const Text('Are you sure you want to close this case? This action can be reversed by an administrator.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _caseService.closeCase(_case!.id);
              if (mounted) {
                Navigator.pop(context);
                _loadInitialData();
              }
            },
            child: const Text('Close Case'),
          ),
        ],
      ),
    );
  }

  // --- Parties Tab ---
  Widget _buildPartiesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _parties.length,
        itemBuilder: (context, i) => Card(
          child: ListTile(
            title: Text(_parties[i].partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_parties[i].partyType),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddPartyDialog(_parties[i])),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteParty(_parties[i])),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddPartyDialog(), child: const Icon(Icons.person_add_rounded)),
    );
  }

  void _showAddPartyDialog([CaseParty? party]) async {
    final result = await showDialog(context: context, builder: (context) => AddPartyDialog(caseId: widget.caseId, party: party));
    if (result == true) _refreshCurrentTabData();
  }

  void _deleteParty(CaseParty party) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Party'),
        content: Text('Remove ${party.partyName} from this case?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _caseService.deleteParty(party.id);
      _refreshCurrentTabData();
    }
  }

  // --- Tasks Tab ---
  Widget _buildTasksTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, i) {
          final isOverdue = _tasks[i].dueDate != null && _tasks[i].dueDate!.isBefore(DateTime.now()) && _tasks[i].status != 'COMPLETED';
          return Card(
            child: ListTile(
              title: Text(_tasks[i].title, style: TextStyle(color: isOverdue ? Colors.red : Colors.black, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('Due: ${Formatters.formatFriendlyDate(_tasks[i].dueDate)}'),
              trailing: _buildTaskStatusDropdown(_tasks[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddTaskDialog, child: const Icon(Icons.add_task_rounded)),
    );
  }

  Widget _buildTaskStatusDropdown(CaseTask task) {
    return DropdownButton<String>(
      value: task.status,
      items: ['TODO', 'IN_PROGRESS', 'WAITING', 'COMPLETED', 'CANCELLED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (val) async {
        if (val != null) {
          await _caseService.updateTaskStatus(task.id, UpdateCaseTaskStatusRequest(status: val));
          _refreshCurrentTabData();
        }
      },
    );
  }

  void _showAddTaskDialog() async {
    final result = await showDialog(context: context, builder: (context) => AddTaskDialog(caseId: widget.caseId, users: _users));
    if (result == true) _refreshCurrentTabData();
  }

  // --- Time Tab ---
  Widget _buildTimeTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _timeEntries.length,
        itemBuilder: (context, i) => Card(
          child: ListTile(
            title: Text(_timeEntries[i].description),
            subtitle: Text('${_timeEntries[i].minutes} mins • ${Formatters.formatFriendlyDate(_timeEntries[i].entryDate)}'),
            trailing: Text(_timeEntries[i].formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddTimeEntryDialog, child: const Icon(Icons.timer_rounded)),
    );
  }

  void _showAddTimeEntryDialog() async {
    final result = await showDialog(context: context, builder: (context) => AddTimeEntryDialog(caseId: widget.caseId, tasks: _tasks, users: _users, defaultHourlyRateCents: _case!.hourlyRateCents));
    if (result == true) {
      _refreshCurrentTabData();
      _loadInitialData(); 
    }
  }

  // --- Disbursements Tab ---
  Widget _buildDisbursementsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _disbursements.length,
        itemBuilder: (context, i) => Card(
          child: ListTile(
            title: Text(_disbursements[i].description),
            subtitle: Text(_disbursements[i].disbursementType),
            trailing: Text(_disbursements[i].formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDisbursementDialog, child: const Icon(Icons.receipt_long_rounded)),
    );
  }

  void _showAddDisbursementDialog() async {
    final result = await showDialog(context: context, builder: (context) => AddDisbursementDialog(caseId: widget.caseId));
    if (result == true) {
      _refreshCurrentTabData();
      _loadInitialData();
    }
  }

  // --- Billing Tab ---
  Widget _buildBillingTab() {
    if (_billingSummary == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _billingDetailRow('Total Time Spent', '${_billingSummary!.totalTimeMinutes} mins'),
          _billingDetailRow('Unbilled Time', '${_billingSummary!.unbilledTimeMinutes} mins'),
          const Divider(),
          _billingDetailRow('Total Fees', _billingSummary!.formattedTotalFees),
          _billingDetailRow('Unbilled Fees', _billingSummary!.formattedUnbilledFees),
          const Divider(),
          _billingDetailRow('Total Disbursements', _billingSummary!.formattedTotalDisbursements),
          _billingDetailRow('Unbilled Disbursements', _billingSummary!.formattedUnbilledDisbursements),
          const Divider(),
          _billingDetailRow('TOTAL BILLABLE', _billingSummary!.formattedTotalBillable, bold: true),
          _billingDetailRow('TOTAL BILLED', _billingSummary!.formattedTotalBilled),
          const Divider(thickness: 2),
          _billingDetailRow('OUTSTANDING BALANCE', _billingSummary!.formattedBalance, isTotal: true),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(onPressed: () => _caseService.recalculateBilling(widget.caseId).then((_) => _refreshCurrentTabData()), icon: const Icon(Icons.refresh_rounded), label: const Text('Recalculate')),
              const SizedBox(width: 12),
              ElevatedButton.icon(onPressed: _showInvoicePreview, icon: const Icon(Icons.remove_red_eye_outlined), label: const Text('Invoice Preview')),
              const SizedBox(width: 12),
              ElevatedButton.icon(onPressed: _generateInvoice, icon: const Icon(Icons.receipt_rounded), label: const Text('Generate Invoice')),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvoicePreview() async {
     try {
      final preview = await _caseService.getInvoicePreview(widget.caseId);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Invoice Preview: ${preview.caseNo}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Entries', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...preview.timeEntries.map((e) => ListTile(
                    dense: true,
                    title: Text(e.description),
                    trailing: Text(Formatters.formatCentsAsRand(e.amountCents)),
                  )),
                  const SizedBox(height: 16),
                  const Text('Disbursements', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...preview.disbursements.map((d) => ListTile(
                    dense: true,
                    title: Text(d.description),
                    trailing: Text(Formatters.formatCentsAsRand(d.amountCents)),
                  )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(Formatters.formatCentsAsRand(preview.totalInvoiceCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _generateInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Invoice'),
        content: const Text('This will convert all unbilled time and disbursements into a new invoice. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _caseService.generateInvoice(widget.caseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice generated successfully')));
          _refreshCurrentTabData();
          _loadInitialData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _billingDetailRow(String label, String value, {bool isTotal = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal || bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: FontWeight.bold, color: isTotal ? Colors.red : Colors.black)),
        ],
      ),
    );
  }

  // --- Notes Tab ---
  Widget _buildNotesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notes.length,
        itemBuilder: (context, i) => Card(
          child: ListTile(
            title: Text(_notes[i].title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_notes[i].note),
            leading: Icon(_notes[i].privateNote ? Icons.lock_outline : Icons.notes, color: _notes[i].privateNote ? Colors.orange : Colors.blue),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteNote(_notes[i])),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddNoteDialog, child: const Icon(Icons.note_add_rounded)),
    );
  }

  void _showAddNoteDialog() async {
    final result = await showDialog(context: context, builder: (context) => AddNoteDialog(caseId: widget.caseId));
    if (result == true) _refreshCurrentTabData();
  }

  void _deleteNote(CaseNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Remove this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _caseService.deleteNote(note.id);
      _refreshCurrentTabData();
    }
  }

  // --- Events Tab ---
  Widget _buildEventsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, i) {
          final isCritical = ['HEARING', 'TRIAL', 'DEADLINE'].contains(_events[i].eventType);
          return Card(
            child: ListTile(
              leading: Icon(Icons.event, color: isCritical ? Colors.red : Colors.blue),
              title: Text(_events[i].title, style: TextStyle(fontWeight: isCritical ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${Formatters.formatDateTime(_events[i].startAt)}\n${_events[i].location ?? ""}'),
              trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddEventDialog(_events[i])),
              isThreeLine: true,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddEventDialog(), child: const Icon(Icons.event_available_rounded)),
    );
  }

  void _showAddEventDialog([CaseEvent? event]) async {
    final result = await showDialog(context: context, builder: (context) => AddEventDialog(caseId: widget.caseId, event: event));
    if (result == true) _refreshCurrentTabData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
