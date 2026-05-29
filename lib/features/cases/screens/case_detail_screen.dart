import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../models/case_task.dart';
import '../models/case_time_entry.dart';
import '../models/case_disbursement.dart';
import '../models/case_billing_summary.dart';
import '../services/case_management_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/models/user.dart';

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
  List<User> _users = [];
  
  bool _isLoading = true;
  bool _isLoadingTasks = false;
  bool _isLoadingTime = false;
  bool _isLoadingDisbursements = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadInitialData();
    _fetchUsers();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _onTabChanged(_tabController.index);
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _caseService.getCaseById(widget.caseId),
        _caseService.getBillingSummary(widget.caseId),
      ]);
      setState(() {
        _case = results[0] as LegalCase;
        _billingSummary = results[1] as CaseBillingSummary;
        _isLoading = false;
      });
      _onTabChanged(_tabController.index);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      _users = await _userService.getUsers();
    } catch (_) {}
  }

  void _onTabChanged(int index) {
    switch (index) {
      case 1: _fetchTasks(); break;
      case 2: _fetchTimeEntries(); break;
      case 3: _fetchDisbursements(); break;
    }
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      _tasks = await _caseService.getTasks(widget.caseId);
    } finally {
      setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _fetchTimeEntries() async {
    setState(() => _isLoadingTime = true);
    try {
      _timeEntries = await _caseService.getTimeEntries(widget.caseId);
    } finally {
      setState(() => _isLoadingTime = false);
    }
  }

  Future<void> _fetchDisbursements() async {
    setState(() => _isLoadingDisbursements = true);
    try {
      _disbursements = await _caseService.getDisbursements(widget.caseId);
    } finally {
      setState(() => _isLoadingDisbursements = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_case == null) {
      return const Scaffold(body: Center(child: Text('Case not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_case!.caseNo}: ${_case!.title}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildBillingSummaryCards(),
          const SizedBox(height: 24),
          _buildDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_case!.caseNo, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(_case!.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusChip(_case!.status),
                    const SizedBox(width: 8),
                    _buildPriorityChip(_case!.priority),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                _buildInfoItem(Icons.person, 'Client ID', _case!.clientPartnerId),
                _buildInfoItem(Icons.assignment_ind, 'Assigned To', _case!.assignedTo ?? 'Unassigned'),
                _buildInfoItem(Icons.gavel, 'Court', _case!.courtName ?? 'N/A'),
                _buildInfoItem(Icons.calendar_today, 'Next Date', _case!.nextAppearanceDate != null ? DateFormat('yyyy-MM-dd').format(_case!.nextAppearanceDate!) : 'None'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBillingSummaryCards() {
    if (_billingSummary == null) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: [
        _buildSummaryCard('Total Fees', _billingSummary!.formattedTotalFees, Colors.blue),
        _buildSummaryCard('Disbursements', _billingSummary!.formattedTotalDisbursements, Colors.orange),
        _buildSummaryCard('Billable', _billingSummary!.formattedTotalBillable, Colors.purple),
        _buildSummaryCard('Billed', _billingSummary!.formattedTotalBilled, Colors.green),
        _buildSummaryCard('Balance', _billingSummary!.formattedBalance, Colors.red),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Case Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_case!.description ?? 'No description provided.'),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _buildDetailRow('Case Type', _case!.caseType)),
                Expanded(child: _buildDetailRow('Category', _case!.caseCategory ?? 'N/A')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDetailRow('Opened Date', _case!.openedDate != null ? DateFormat('yyyy-MM-dd').format(_case!.openedDate!) : 'N/A')),
                Expanded(child: _buildDetailRow('Court Case No', _case!.courtCaseNo ?? 'N/A')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDetailRow('Billing Type', _case!.billingType)),
                Expanded(child: _buildDetailRow('Rate', _case!.billingType == 'HOURLY' ? 'R ${(_case!.hourlyRateCents/100).toStringAsFixed(2)}/hr' : 'N/A')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- Tasks Tab ---
  Widget _buildTasksTab() {
    return Scaffold(
      body: _isLoadingTasks
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No tasks found'))
              : ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(task.title),
                        subtitle: Text('Due: ${task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!) : 'N/A'} • Assigned: ${task.assignedTo ?? 'Unassigned'}'),
                        trailing: DropdownButton<String>(
                          value: task.status,
                          underline: const SizedBox.shrink(),
                          items: ['TODO', 'IN_PROGRESS', 'WAITING', 'COMPLETED', 'CANCELLED'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) _updateTaskStatus(task.id, newStatus);
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        mini: true,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _updateTaskStatus(String taskId, String status) async {
    try {
      await _caseService.updateTaskStatus(taskId, UpdateCaseTaskStatusRequest(status: status));
      _fetchTasks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    String priority = 'NORMAL';
    String? assignedTo;
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['LOW', 'NORMAL', 'HIGH', 'URGENT'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setState(() => priority = val!),
                ),
                DropdownButtonFormField<String?>(
                  value: assignedTo,
                  decoration: const InputDecoration(labelText: 'Assign To'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned')),
                    ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))),
                  ],
                  onChanged: (val) => setState(() => assignedTo = val),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2101));
                    if (picked != null) setState(() => dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due Date'),
                    child: Text(dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : 'Select Date'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                await _caseService.createTask(widget.caseId, CreateCaseTaskRequest(
                  title: titleCtrl.text,
                  priority: priority,
                  assignedTo: assignedTo,
                  dueDate: dueDate,
                ));
                if (mounted) Navigator.pop(context);
                _fetchTasks();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Time Tab ---
  Widget _buildTimeTab() {
    return Scaffold(
      body: _isLoadingTime
          ? const Center(child: CircularProgressIndicator())
          : _timeEntries.isEmpty
              ? const Center(child: Text('No time entries found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Minutes')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: _timeEntries.map((e) => DataRow(cells: [
                      DataCell(Text(DateFormat('yyyy-MM-dd').format(e.entryDate))),
                      DataCell(Text(e.description)),
                      DataCell(Text(e.minutes.toString())),
                      DataCell(Text(e.formattedAmount)),
                      DataCell(Text(e.billed ? 'BILLED' : 'UNBILLED', style: TextStyle(color: e.billed ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10))),
                    ])).toList(),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTimeEntryDialog,
        mini: true,
        child: const Icon(Icons.timer),
      ),
    );
  }

  void _showAddTimeEntryDialog() {
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '30');
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Capture Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Minutes'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2101));
                  if (picked != null) setState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(DateFormat('yyyy-MM-dd').format(date)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _caseService.createTimeEntry(widget.caseId, CreateCaseTimeEntryRequest(
                  entryDate: date,
                  userId: '', // Should be current user
                  description: descCtrl.text,
                  minutes: int.tryParse(minCtrl.text) ?? 0,
                  hourlyRateCents: _case!.hourlyRateCents,
                ));
                if (mounted) Navigator.pop(context);
                _fetchTimeEntries();
                _caseService.getBillingSummary(widget.caseId).then((s) => setState(() => _billingSummary = s));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disbursements Tab ---
  Widget _buildDisbursementsTab() {
    return Scaffold(
      body: _isLoadingDisbursements
          ? const Center(child: CircularProgressIndicator())
          : _disbursements.isEmpty
              ? const Center(child: Text('No disbursements found'))
              : ListView.builder(
                  itemCount: _disbursements.length,
                  itemBuilder: (context, index) {
                    final d = _disbursements[index];
                    return ListTile(
                      title: Text(d.description),
                      subtitle: Text('${d.disbursementType} • ${DateFormat('yyyy-MM-dd').format(d.disbursementDate)}'),
                      trailing: Text(d.formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDisbursementDialog,
        mini: true,
        child: const Icon(Icons.receipt_long),
      ),
    );
  }

  void _showAddDisbursementDialog() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String type = 'OTHER';
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Disbursement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['SHERIFF', 'COURT_FEE', 'TRAVEL', 'PRINTING', 'POSTAGE', 'ADVOCATE', 'EXPERT', 'OTHER'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => type = val!),
                ),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount (Rand)'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2101));
                    if (picked != null) setState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('yyyy-MM-dd').format(date)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _caseService.createDisbursement(widget.caseId, CreateCaseDisbursementRequest(
                  disbursementDate: date,
                  disbursementType: type,
                  description: descCtrl.text,
                  amountCents: (double.tryParse(amtCtrl.text) ?? 0 * 100).round(),
                ));
                if (mounted) Navigator.pop(context);
                _fetchDisbursements();
                _caseService.getBillingSummary(widget.caseId).then((s) => setState(() => _billingSummary = s));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Billing Tab ---
  Widget _buildBillingTab() {
    if (_billingSummary == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBillingDetailRow('Total Time', '${_billingSummary!.totalTimeMinutes} mins'),
          _buildBillingDetailRow('Unbilled Time', '${_billingSummary!.unbilledTimeMinutes} mins'),
          const Divider(),
          _buildBillingDetailRow('Total Fees', _billingSummary!.formattedTotalFees),
          _buildBillingDetailRow('Unbilled Fees', _billingSummary!.formattedUnbilledFees),
          const Divider(),
          _buildBillingDetailRow('Total Disbursements', _billingSummary!.formattedTotalDisbursements),
          _buildBillingDetailRow('Unbilled Disbursements', _billingSummary!.formattedUnbilledDisbursements),
          const Divider(),
          _buildBillingDetailRow('Total Billable', _billingSummary!.formattedTotalBillable, bold: true),
          _buildBillingDetailRow('Total Billed', _billingSummary!.formattedTotalBilled, color: Colors.green),
          _buildBillingDetailRow('Balance Outstanding', _billingSummary!.formattedBalance, color: Colors.red, bold: true),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await _caseService.recalculateBilling(widget.caseId);
              final s = await _caseService.getBillingSummary(widget.caseId);
              setState(() => _billingSummary = s);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Recalculate Billing'),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  // --- Notes & Events (Placeholders) ---
  Widget _buildNotesTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notes, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Notes Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Consultations, Court Notes, and Internal Notes will appear here.'),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Events Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Hearings, Trials, Deadlines and Reminders will appear here.'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.blue, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact);
  }

  Widget _buildPriorityChip(String priority) {
    return Chip(label: Text(priority, style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.orange, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
