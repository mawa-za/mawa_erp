import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../models/approval_workflow.dart';
import '../services/approval_workflow_service.dart';
import 'approval_workflow_create_screen.dart';

class ApprovalWorkflowListScreen extends StatefulWidget {
  const ApprovalWorkflowListScreen({super.key});

  @override
  State<ApprovalWorkflowListScreen> createState() =>
      _ApprovalWorkflowListScreenState();
}

class _ApprovalWorkflowListScreenState
    extends State<ApprovalWorkflowListScreen> {
  final ApprovalWorkflowService _service = ApprovalWorkflowService();
  final Set<String> _updatingWorkflowIds = <String>{};

  bool _isLoading = true;
  List<ApprovalWorkflow> _allWorkflows = [];
  List<ApprovalWorkflow> _workflows = [];
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
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
      if (!mounted) return;

      response.sort(
        (a, b) => a.approvalType.compareTo(b.approvalType),
      );
      setState(() {
        _allWorkflows = response;
        _applyStatusFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _applyStatusFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _workflows = _allWorkflows.where((workflow) {
      final statusMatches = switch (_selectedStatus) {
        'ACTIVE' => workflow.active,
        'INACTIVE' => !workflow.active,
        _ => true,
      };
      if (!statusMatches) return false;
      if (query.isEmpty) return true;
      return [workflow.name, workflow.description, workflow.approvalType]
          .join(' ')
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _setWorkflowActive(
    ApprovalWorkflow workflow,
    bool active,
  ) async {
    final id = workflow.id;
    if (id == null || _updatingWorkflowIds.contains(id)) return;

    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate approval workflow?'),
          content: Text(
            'New ${workflow.name.toLowerCase()} requests will be '
            'auto-approved while this workflow is inactive. Requests already '
            'in progress will continue through their current approval steps.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DEACTIVATE'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _updatingWorkflowIds.add(id));
    try {
      if (active) {
        await _service.activateWorkflow(id);
      } else {
        await _service.deactivateWorkflow(id);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? '${workflow.name} activated'
                : '${workflow.name} deactivated',
          ),
        ),
      );
      await _fetchWorkflows();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingWorkflowIds.remove(id));
      }
    }
  }

  Widget _buildStatusFilter() {
    const statuses = ['ALL', 'ACTIVE', 'INACTIVE'];
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statuses[index];
          return ChoiceChip(
            label: Text(status),
            selected: _selectedStatus == status,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _selectedStatus = status;
              _applyStatusFilter();
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Approval Workflows',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWorkflows,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search workflows',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _applyStatusFilter();
              }),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchWorkflows,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _workflows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No workflows configured',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _workflows.length,
                            itemBuilder: (context, index) {
                              final workflow = _workflows[index];
                              final id = workflow.id;
                              final isUpdating = id != null &&
                                  _updatingWorkflowIds.contains(id);

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    workflow.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(workflow.description),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  colorScheme.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              workflow.approvalType,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: workflow.active
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              workflow.active
                                                  ? 'ACTIVE'
                                                  : 'INACTIVE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: workflow.active
                                                    ? Colors.green.shade800
                                                    : Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${workflow.steps.length} steps',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: isUpdating
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Tooltip(
                                          message: workflow.active
                                              ? 'Deactivate workflow'
                                              : 'Activate workflow',
                                          child: Switch.adaptive(
                                            value: workflow.active,
                                            onChanged: id == null
                                                ? null
                                                : (value) =>
                                                    _setWorkflowActive(
                                                      workflow,
                                                      value,
                                                    ),
                                          ),
                                        ),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ApprovalWorkflowCreateScreen(
                                          workflow: workflow,
                                        ),
                                      ),
                                    );
                                    if (result == true) _fetchWorkflows();
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
