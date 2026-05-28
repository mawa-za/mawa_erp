import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/user_service.dart';
import '../models/case_task.dart';
import '../services/case_management_service.dart';

class CaseTasksTab extends StatefulWidget {
  final String caseId;
  const CaseTasksTab({super.key, required this.caseId});

  @override
  State<CaseTasksTab> createState() => _CaseTasksTabState();
}

class _CaseTasksTabState extends State<CaseTasksTab> {
  final CaseManagementService _caseService = CaseManagementService();
  List<CaseTask> _tasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tasks = await _caseService.getTasks(widget.caseId);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await _caseService.updateTaskStatus(taskId, UpdateCaseTaskStatusRequest(status: newStatus));
      _fetchTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'NORMAL';
    DateTime? dueDate;
    String? assignedTo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: ['LOW', 'NORMAL', 'HIGH', 'URGENT'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setDialogState(() => priority = val!),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(dueDate == null ? 'Select Due Date' : 'Due: ${DateFormat('yyyy-MM-dd').format(dueDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
                _buildUserDropdown(assignedTo, (val) => setDialogState(() => assignedTo = val)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                try {
                  await _caseService.createTask(
                    widget.caseId,
                    CreateCaseTaskRequest(
                      title: titleController.text,
                      description: descController.text,
                      priority: priority,
                      assignedTo: assignedTo,
                      dueDate: dueDate,
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchTasks();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDropdown(String? value, ValueChanged<String?> onChanged) {
    return FutureBuilder(
      future: UserService().getUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final users = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          value: value,
          items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? ''))).toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(labelText: 'Assign To'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_tasks.length} Tasks', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return _buildTaskTile(task);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(CaseTask task) {
    return ListTile(
      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned: ${task.assignedToName ?? 'Unassigned'} • Priority: ${task.priority}'),
          if (task.dueDate != null)
            Text('Due: ${DateFormat('dd MMM yyyy').format(task.dueDate!)}',
              style: TextStyle(color: task.dueDate!.isBefore(DateTime.now()) ? Colors.red : Colors.grey)),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (val) => _updateTaskStatus(task.id, val),
        itemBuilder: (context) => ['TODO', 'IN_PROGRESS', 'WAITING', 'COMPLETED', 'CANCELLED']
            .map((s) => PopupMenuItem(value: s, child: Text(s)))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(task.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor(task.status)),
          ),
          child: Text(task.status, style: TextStyle(color: _getStatusColor(task.status), fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'TODO': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'WAITING': return Colors.purple;
      case 'COMPLETED': return Colors.green;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }
}
