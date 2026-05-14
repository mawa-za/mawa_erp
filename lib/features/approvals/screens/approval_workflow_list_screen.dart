import 'package:flutter/material.dart';
import '../models/approval_workflow.dart';
import '../services/approval_workflow_service.dart';
import 'approval_workflow_create_screen.dart';

class ApprovalWorkflowListScreen extends StatefulWidget {
  const ApprovalWorkflowListScreen({super.key});

  @override
  State<ApprovalWorkflowListScreen> createState() => _ApprovalWorkflowListScreenState();
}

class _ApprovalWorkflowListScreenState extends State<ApprovalWorkflowListScreen> {
  final ApprovalWorkflowService _service = ApprovalWorkflowService();
  bool _isLoading = true;
  List<ApprovalWorkflow> _workflows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWorkflows();
  }

  Future<void> _fetchWorkflows() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _service.getWorkflows();
      if (mounted) {
        setState(() {
          _workflows = response.content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Approval Workflows', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWorkflows,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchWorkflows, child: const Text('Retry')),
                    ],
                  ),
                )
              : _workflows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No workflows configured', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _workflows.length,
                      itemBuilder: (context, index) {
                        final workflow = _workflows[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(workflow.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(workflow.description),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        workflow.approvalType,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${workflow.steps.length} steps',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ApprovalWorkflowCreateScreen(workflow: workflow),
                                ),
                              );
                              if (result == true) _fetchWorkflows();
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ApprovalWorkflowCreateScreen(),
            ),
          );
          if (result == true) _fetchWorkflows();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
