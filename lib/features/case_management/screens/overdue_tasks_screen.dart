import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_task.dart';
import '../services/case_management_service.dart';
import 'case_detail_screen.dart';

class OverdueTasksScreen extends StatefulWidget {
  const OverdueTasksScreen({super.key});

  @override
  State<OverdueTasksScreen> createState() => _OverdueTasksScreenState();
}

class _OverdueTasksScreenState extends State<OverdueTasksScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  List<CaseTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _caseService.getOverdueTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Overdue Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
    );
  }

  Widget _buildTaskCard(CaseTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: task.caseId)),
        ),
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!) : 'No due date',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(task.assignedTo ?? 'Unassigned', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getPriorityColor(task.priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            task.priority,
            style: TextStyle(color: _getPriorityColor(task.priority), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'URGENT': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'LOW': return Colors.green;
      default: return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No overdue tasks!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('All caught up.', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
