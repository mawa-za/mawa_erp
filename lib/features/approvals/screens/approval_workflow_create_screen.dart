import 'package:flutter/material.dart';
import '../models/approval_workflow.dart';
import '../services/approval_workflow_service.dart';

class ApprovalWorkflowCreateScreen extends StatefulWidget {
  final ApprovalWorkflow? workflow;

  const ApprovalWorkflowCreateScreen({super.key, this.workflow});

  @override
  State<ApprovalWorkflowCreateScreen> createState() => _ApprovalWorkflowCreateScreenState();
}

class _ApprovalWorkflowCreateScreenState extends State<ApprovalWorkflowCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedApprovalType = 'CLAIM';
  List<ApprovalStep> _steps = [];
  bool _isSaving = false;

  final List<String> _approvalTypes = ['CLAIM', 'PAYMENT', 'LEAVE'];
  final List<String> _approverTypes = ['ROLE', 'MANAGER', 'USER'];

  @override
  void initState() {
    super.initState();
    if (widget.workflow != null) {
      _nameController.text = widget.workflow!.name;
      _descriptionController.text = widget.workflow!.description;
      _selectedApprovalType = widget.workflow!.approvalType;
      _steps = List.from(widget.workflow!.steps);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(ApprovalStep(
        stepNo: _steps.length + 1,
        stepName: 'Step ${_steps.length + 1}',
        approverType: 'ROLE',
        approverValue: '',
        requiredApprovals: 1,
      ));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      // Re-index steps
      for (int i = 0; i < _steps.length; i++) {
        _steps[i] = ApprovalStep(
          stepNo: i + 1,
          stepName: _steps[i].stepName,
          approverType: _steps[i].approverType,
          approverValue: _steps[i].approverValue,
          requiredApprovals: _steps[i].requiredApprovals,
        );
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one approval step')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final workflow = ApprovalWorkflow(
        id: widget.workflow?.id,
        approvalType: _selectedApprovalType,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        steps: _steps,
      );

      final service = ApprovalWorkflowService();
      if (widget.workflow == null) {
        await service.createWorkflow(workflow);
      } else {
        await service.updateWorkflow(widget.workflow!.id!, workflow);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.workflow == null ? 'Create Workflow' : 'Edit Workflow'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfo(colorScheme),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('APPROVAL STEPS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD STEP'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._steps.asMap().entries.map((entry) => _buildStepCard(entry.key, entry.value, colorScheme)),
            if (_steps.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No steps added yet', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedApprovalType,
              decoration: const InputDecoration(labelText: 'Approval Type', border: OutlineInputBorder()),
              items: _approvalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedApprovalType = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Workflow Name', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int index, ApprovalStep step, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colorScheme.primary,
                  child: Text('${step.stepNo}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: step.stepName,
                    decoration: const InputDecoration(hintText: 'Step Name', isDense: true, border: InputBorder.none),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    onChanged: (val) {
                      _steps[index] = ApprovalStep(
                        stepNo: step.stepNo,
                        stepName: val,
                        approverType: step.approverType,
                        approverValue: step.approverValue,
                        requiredApprovals: step.requiredApprovals,
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeStep(index),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: step.approverType,
                    decoration: const InputDecoration(labelText: 'Approver Type', border: OutlineInputBorder(), isDense: true),
                    items: _approverTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _steps[index] = ApprovalStep(
                          stepNo: step.stepNo,
                          stepName: step.stepName,
                          approverType: val!,
                          approverValue: step.approverValue,
                          requiredApprovals: step.requiredApprovals,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: step.approverValue,
                    decoration: const InputDecoration(labelText: 'Approver Value', border: OutlineInputBorder(), isDense: true),
                    onChanged: (val) {
                      _steps[index] = ApprovalStep(
                        stepNo: step.stepNo,
                        stepName: step.stepName,
                        approverType: step.approverType,
                        approverValue: val,
                        requiredApprovals: step.requiredApprovals,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: step.requiredApprovals.toString(),
              decoration: const InputDecoration(labelText: 'Required Approvals', border: OutlineInputBorder(), isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                final intVal = int.tryParse(val) ?? 1;
                _steps[index] = ApprovalStep(
                  stepNo: step.stepNo,
                  stepName: step.stepName,
                  approverType: step.approverType,
                  approverValue: step.approverValue,
                  requiredApprovals: intVal,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
