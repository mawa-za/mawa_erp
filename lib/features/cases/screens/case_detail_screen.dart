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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _caseService.getCaseById(widget.caseId),
        _caseService.getBillingSummary(widget.caseId).then((json) => CaseBillingSummary.fromJson(json)),
      ]);
      if (!mounted) return;
      setState(() {
        _case = results[0] as LegalCase;
        _billingSummary = results[1] as CaseBillingSummary;
        _isLoading = false;
      });
      _onTabChanged(_tabController.index);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await _userService.getUsers();
      if (mounted) setState(() => _users = users);
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
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);
    try {
      final tasks = await _caseService.getTasks(widget.caseId);
      if (mounted) setState(() => _tasks = tasks);
    } finally {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _fetchTimeEntries() async {
    if (!mounted) return;
    setState(() => _isLoadingTime = true);
    try {
      final entries = await _caseService.getTimeEntries(widget.caseId);
      if (mounted) setState(() => _timeEntries = entries);
    } finally {
      if (mounted) setState(() => _isLoadingTime = false);
    }
  }

  Future<void> _fetchDisbursements() async {
    if (!mounted) return;
    setState(() => _isLoadingDisbursements = true);
    try {
      final disbursements = await _caseService.getDisbursements(widget.caseId);
      if (mounted) setState(() => _disbursements = disbursements);
    } finally {
      if (mounted) setState(() => _isLoadingDisbursements = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_case == null) {
      return const Scaffold(body: Center(child: Text('Case not found')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_case!.caseNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(_case!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
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
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          _buildBillingSummaryGrid(),
          const SizedBox(height: 24),
          _buildDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CLIENT PARTNER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(_case!.clientPartnerId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          const Divider(height: 48),
          Row(
            children: [
              _buildInfoItem(Icons.assignment_ind_outlined, 'ASSIGNED TO', _case!.assignedTo ?? 'Unassigned'),
              _buildInfoItem(Icons.account_balance_outlined, 'COURT', _case!.courtName ?? 'Not Specified'),
              _buildInfoItem(Icons.event_note_outlined, 'NEXT APPEARANCE', _case!.nextAppearanceDate != null ? DateFormat('MMM dd, yyyy').format(_case!.nextAppearanceDate!) : 'None'),
              _buildInfoItem(Icons.calendar_today_outlined, 'OPENED DATE', _case!.openedDate != null ? DateFormat('MMM dd, yyyy').format(_case!.openedDate!) : 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBillingSummaryGrid() {
    if (_billingSummary == null) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 5 : (width > 800 ? 3 : 2);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildSummaryCard('Total Fees', _billingSummary!.formattedTotalFees, Colors.blue, Icons.payments_outlined),
        _buildSummaryCard('Disbursements', _billingSummary!.formattedTotalDisbursements, Colors.orange, Icons.receipt_long_outlined),
        _buildSummaryCard('Total Billable', _billingSummary!.formattedTotalBillable, Colors.deepPurple, Icons.summarize_outlined),
        _buildSummaryCard('Total Billed', _billingSummary!.formattedTotalBilled, Colors.green, Icons.check_circle_outline_rounded),
        _buildSummaryCard('Outstanding', _billingSummary!.formattedBalance, Colors.red, Icons.account_balance_wallet_outlined),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              const Text('CASE DESCRIPTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_case!.description ?? 'No description provided.', style: TextStyle(color: Colors.grey[700], height: 1.5)),
          const Divider(height: 48),
          _buildDetailRow('Case Type', _case!.caseType, Icons.category_outlined),
          _buildDetailRow('Category', _case!.caseCategory ?? 'N/A', Icons.label_outline_rounded),
          _buildDetailRow('Court Case No', _case!.courtCaseNo ?? 'N/A', Icons.tag_rounded),
          _buildDetailRow('Forum Type', _case!.forumType ?? 'N/A', Icons.meeting_room_outlined),
          _buildDetailRow('Billing Type', _case!.billingType, Icons.receipt_long_outlined),
          _buildDetailRow('Rate', _case!.billingType == 'HOURLY' ? 'R ${(_case!.hourlyRateCents/100).toStringAsFixed(2)}/hr' : (_case!.billingType == 'FIXED_FEE' ? 'R ${(_case!.fixedFeeCents/100).toStringAsFixed(2)} Fixed' : 'N/A'), Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  // --- Tasks Tab ---
  Widget _buildTasksTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingTasks
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyStateWidget('No tasks found', Icons.check_circle_outline_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
        heroTag: 'add_task',
      ),
    );
  }

  Widget _buildTaskCard(CaseTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(task.dueDate != null ? DateFormat('MMM dd, yyyy').format(task.dueDate!) : 'No deadline', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(width: 12),
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(task.assignedTo ?? 'Unassigned', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: task.status,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              items: ['TODO', 'IN_PROGRESS', 'WAITING', 'COMPLETED', 'CANCELLED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (newStatus) {
                if (newStatus != null) _updateTaskStatus(task.id, newStatus);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _updateTaskStatus(String taskId, String status) async {
    try {
      await _caseService.updateTaskStatus(taskId, UpdateCaseTaskStatusRequest(status: status));
      _fetchTasks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Task Title', Icons.title_rounded, TextField(controller: titleCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'What needs to be done?'))),
                const SizedBox(height: 16),
                _buildDialogField('Priority', Icons.priority_high_rounded, 
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: priority,
                      items: ['LOW', 'NORMAL', 'HIGH', 'URGENT'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => priority = val!),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                _buildDialogField('Assign To', Icons.person_outline_rounded,
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: assignedTo,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unassigned')),
                        ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))),
                      ],
                      onChanged: (val) => setState(() => assignedTo = val),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                _buildDialogField('Due Date', Icons.event_rounded,
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2101));
                      if (picked != null) setState(() => dueDate = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(dueDate != null ? DateFormat('MMM dd, yyyy').format(dueDate!) : 'Select Date', style: TextStyle(color: dueDate == null ? Colors.grey : Colors.black)),
                    ),
                  )
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Time Tab ---
  Widget _buildTimeTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingTime
          ? const Center(child: CircularProgressIndicator())
          : _timeEntries.isEmpty
              ? _buildEmptyStateWidget('No time entries tracked', Icons.timer_outlined)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                        columns: const [
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Minutes', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _timeEntries.map((e) => DataRow(cells: [
                          DataCell(Text(DateFormat('MMM dd').format(e.entryDate))),
                          DataCell(SizedBox(width: 150, child: Text(e.description, overflow: TextOverflow.ellipsis))),
                          DataCell(Text('${e.minutes}m')),
                          DataCell(Text(e.formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: e.billed ? Colors.green[50] : Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                            child: Text(e.billed ? 'BILLED' : 'PENDING', style: TextStyle(color: e.billed ? Colors.green[700] : Colors.orange[700], fontWeight: FontWeight.bold, fontSize: 9)),
                          )),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTimeEntryDialog,
        icon: const Icon(Icons.timer_rounded),
        label: const Text('Capture Time'),
        heroTag: 'add_time',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Capture Time', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('Description', Icons.description_outlined, TextField(controller: descCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'What did you work on?'))),
              const SizedBox(height: 16),
              _buildDialogField('Duration (Minutes)', Icons.schedule_rounded, TextField(controller: minCtrl, decoration: const InputDecoration(border: InputBorder.none), keyboardType: TextInputType.number)),
              const SizedBox(height: 16),
              _buildDialogField('Date', Icons.event_rounded,
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2101));
                    if (picked != null) setState(() => date = picked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(DateFormat('MMM dd, yyyy').format(date)),
                  ),
                )
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                await _caseService.createTimeEntry(widget.caseId, CreateCaseTimeEntryRequest(
                  entryDate: date,
                  userId: '', // Current user ID logic should be here
                  description: descCtrl.text,
                  minutes: int.tryParse(minCtrl.text) ?? 0,
                  hourlyRateCents: _case!.hourlyRateCents,
                ));
                if (mounted) Navigator.pop(context);
                _fetchTimeEntries();
                _caseService.getBillingSummary(widget.caseId).then((json) => setState(() => _billingSummary = CaseBillingSummary.fromJson(json)));
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disbursements Tab ---
  Widget _buildDisbursementsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingDisbursements
          ? const Center(child: CircularProgressIndicator())
          : _disbursements.isEmpty
              ? _buildEmptyStateWidget('No disbursements recorded', Icons.receipt_long_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _disbursements.length,
                  itemBuilder: (context, index) {
                    final d = _disbursements[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Icon(Icons.receipt_rounded, color: Colors.blue[700], size: 20)),
                        title: Text(d.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${d.disbursementType} • ${DateFormat('MMM dd, yyyy').format(d.disbursementDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        trailing: Text(d.formattedAmount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDisbursementDialog,
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('Add Expense'),
        heroTag: 'add_disb',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Disbursement', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Type', Icons.category_outlined,
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: type,
                      items: ['SHERIFF', 'COURT_FEE', 'TRAVEL', 'PRINTING', 'POSTAGE', 'ADVOCATE', 'EXPERT', 'OTHER'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => type = val!),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                _buildDialogField('Description', Icons.description_outlined, TextField(controller: descCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Travel to High Court'))),
                const SizedBox(height: 16),
                _buildDialogField('Amount (Rand)', Icons.payments_outlined, TextField(controller: amtCtrl, decoration: const InputDecoration(border: InputBorder.none, prefixText: 'R '), keyboardType: TextInputType.number)),
                const SizedBox(height: 16),
                _buildDialogField('Date', Icons.event_rounded,
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2101));
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(DateFormat('MMM dd, yyyy').format(date)),
                    ),
                  )
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                await _caseService.createDisbursement(widget.caseId, CreateCaseDisbursementRequest(
                  disbursementDate: date,
                  disbursementType: type,
                  description: descCtrl.text,
                  amountCents: ((double.tryParse(amtCtrl.text) ?? 0) * 100).round(),
                ));
                if (mounted) Navigator.pop(context);
                _fetchDisbursements();
                _caseService.getBillingSummary(widget.caseId).then((json) => setState(() => _billingSummary = CaseBillingSummary.fromJson(json)));
              },
              child: const Text('Add Expense'),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[100]!),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _buildBillingDetailRow('Total Time Spent', '${_billingSummary!.totalTimeMinutes} mins', Icons.timer_outlined),
                _buildBillingDetailRow('Unbilled Time', '${_billingSummary!.unbilledTimeMinutes} mins', Icons.more_time_rounded),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                _buildBillingDetailRow('Total Fees', _billingSummary!.formattedTotalFees, Icons.payments_outlined),
                _buildBillingDetailRow('Unbilled Fees', _billingSummary!.formattedUnbilledFees, Icons.pending_actions_rounded),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                _buildBillingDetailRow('Total Disbursements', _billingSummary!.formattedTotalDisbursements, Icons.receipt_long_outlined),
                _buildBillingDetailRow('Unbilled Disbursements', _billingSummary!.formattedUnbilledDisbursements, Icons.money_off_rounded),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                _buildBillingDetailRow('TOTAL BILLABLE', _billingSummary!.formattedTotalBillable, Icons.summarize_rounded, bold: true, color: Colors.deepPurple),
                _buildBillingDetailRow('TOTAL BILLED', _billingSummary!.formattedTotalBilled, Icons.check_circle_rounded, color: Colors.green),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                _buildBillingDetailRow('OUTSTANDING BALANCE', _billingSummary!.formattedBalance, Icons.account_balance_wallet_rounded, color: Colors.red, bold: true, large: true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 250,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _caseService.recalculateBilling(widget.caseId);
                final json = await _caseService.getBillingSummary(widget.caseId);
                setState(() => _billingSummary = CaseBillingSummary.fromJson(json));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RECALCULATE BILLING'),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailRow(String label, String value, IconData icon, {Color? color, bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: large ? 20 : 15, fontWeight: bold || large ? FontWeight.w900 : FontWeight.bold, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _buildDialogField(String label, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateWidget(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
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

  Widget _buildPriorityChip(String priority) {
    Color color = Colors.blue;
    switch (priority) {
      case 'URGENT': color = Colors.red; break;
      case 'HIGH': color = Colors.orange; break;
      case 'NORMAL': color = Colors.blue; break;
      case 'LOW': color = Colors.green; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(priority, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // --- Placeholder Tabs ---
  Widget _buildNotesTab() {
    return _buildEmptyStateWidget('Notes Module coming soon', Icons.notes_rounded);
  }

  Widget _buildEventsTab() {
    return _buildEmptyStateWidget('Events Module coming soon', Icons.event_rounded);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
