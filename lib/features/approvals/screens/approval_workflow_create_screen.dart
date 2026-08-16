import 'package:flutter/material.dart';
import '../models/approval_workflow.dart';
import '../services/approval_workflow_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

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
  bool _active = true;
  bool _autoApprove = false;

  final List<String> _approvalTypes = [
    'ADDITIONAL_MEMBERSHIP',
    'CASHUP',
    'CLAIM',
    'CLAIM_CASH',
    'CLAIM_TOMBSTONE',
    'CLAIM_FUNERAL',
    'CLAIM_COMBINATION',
    'CLAIM_GROCERY',
    'EMPLOYEE_BANKING_DETAILS',
    'EMPLOYEE_HIRE',
    'EMPLOYEE_REHIRE',
    'EMPLOYEE_REINSTATEMENT',
    'EMPLOYEE_SUSPENSION',
    'EMPLOYEE_TERMINATION',
    'FUNERAL_COVER_STATUS_CHANGE',
    'FUNERAL_UNDERWRITING',
    'GROUP_SOCIETY_BALANCE_ADJUSTMENT',
    'GROUP_SOCIETY_FUNERAL_CLAIM',
    'GROUP_SOCIETY_STATUS_CHANGE',
    'INVOICE',
    'JOURNAL',
    'LEAVE',
    'LEAVE_BALANCE_ADJUSTMENT',
    'MEMBERSHIP_DEPENDENT_CHANGE',
    'MEMBERSHIP_PLAN_CHANGE',
    'MEMBERSHIP_TRANSFER',
    'PAYMENT',
    'PAYMENT_REQUEST',
    'PAYROLL_BATCH',
    'PREMIUM_PAYMENT_DELETION',
    'PURCHASE_ORDER',
    'CUSTOMER_REFUND',
    'SUPPLIER_BANKING_DETAILS',
    'SUPPLIER_INVOICE',
    'SUPPLIER_ONBOARDING',
  ];
  
  final List<String> _approverTypes = ['USER', 'ROLE', 'GROUP', 'MANAGER'];

  @override
  void initState() {
    super.initState();
    if (widget.workflow != null) {
      _nameController.text = widget.workflow!.name;
      _descriptionController.text = widget.workflow!.description;
      _selectedApprovalType = widget.workflow!.approvalType;
      _steps = List.from(widget.workflow!.steps);
      _active = widget.workflow!.active;
      _autoApprove = widget.workflow!.autoApprove;
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
        approvers: [
          ApprovalWorkflowStepApprover(
            approverType: 'ROLE',
            approverValue: '',
          )
        ],
        requiredApprovals: 1,
      ));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      // Re-index steps
      for (int i = 0; i < _steps.length; i++) {
        final current = _steps[i];
        _steps[i] = ApprovalStep(
          id: current.id,
          stepNo: i + 1,
          stepName: current.stepName,
          approvalMode: current.approvalMode,
          active: current.active,
          approvers: current.approvers,
          requiredApprovals: current.requiredApprovals,
        );
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_autoApprove && _steps.isEmpty) {
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
        active: _active,
        autoApprove: _autoApprove,
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
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
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
                Text(_autoApprove ? 'APPROVAL STEPS (OPTIONAL IN AUTO MODE)' : 'APPROVAL STEPS', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
            SearchableDropdownFormField<String>(
              value: _selectedApprovalType,
              decoration: const InputDecoration(labelText: 'Approval Type', border: OutlineInputBorder()),
              items: _approvalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: widget.workflow != null
                  ? null
                  : (val) => setState(() => _selectedApprovalType = val!),
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
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active workflow'),
              subtitle: const Text('Requests use this workflow when it is active.'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto approve'),
              subtitle: const Text(
                'Create the approval request and audit actions, then approve it automatically without waiting for an approver.',
              ),
              value: _autoApprove,
              onChanged: (value) => setState(() => _autoApprove = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int index, ApprovalStep step, ColorScheme colorScheme) {
    final approvers = step.approvers.isEmpty
        ? [ApprovalWorkflowStepApprover(approverType: 'ROLE', approverValue: '')]
        : step.approvers;

    void updateStep({
      String? stepName,
      List<ApprovalWorkflowStepApprover>? updatedApprovers,
      int? requiredApprovals,
    }) {
      setState(() {
        _steps[index] = ApprovalStep(
          id: step.id,
          stepNo: step.stepNo,
          stepName: stepName ?? step.stepName,
          approvalMode: step.approvalMode,
          active: step.active,
          approvers: updatedApprovers ?? step.approvers,
          requiredApprovals: requiredApprovals ?? step.requiredApprovals,
        );
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    onChanged: (val) => updateStep(stepName: val),
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
            Text('Approvers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              step.requiredApprovals <= 1
                  ? 'Alternative approvers (OR): any one matching entry below can approve this step.'
                  : 'Any configured approver may action this step; ${step.requiredApprovals} distinct approvals are required before it completes.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ...approvers.asMap().entries.map((entry) {
              final approverIndex = entry.key;
              final approver = entry.value;
              final approverType = _approverTypes.contains(approver.approverType)
                  ? approver.approverType
                  : _approverTypes.first;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownFormField<String>(
                        value: approverType,
                        decoration: InputDecoration(
                          labelText: approvers.length > 1 ? 'Approver ${approverIndex + 1} Type' : 'Approver Type',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _approverTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final updated = List<ApprovalWorkflowStepApprover>.from(approvers);
                          updated[approverIndex] = ApprovalWorkflowStepApprover(
                            id: approver.id,
                            approverType: val,
                            approverValue: approver.approverValue,
                            approverName: approver.approverName,
                            active: approver.active,
                          );
                          updateStep(updatedApprovers: updated);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('workflow-step-${step.stepNo}-approver-$approverIndex-${approver.id ?? 'new'}'),
                        initialValue: approver.approverValue,
                        decoration: InputDecoration(
                          labelText: approver.approverType == 'ROLE' ? 'Role' : 'Approver Value',
                          hintText: approver.approverType == 'ROLE' ? 'e.g. DIRECTOR' : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                        onChanged: (val) {
                          final updated = List<ApprovalWorkflowStepApprover>.from(approvers);
                          updated[approverIndex] = ApprovalWorkflowStepApprover(
                            id: approver.id,
                            approverType: approver.approverType,
                            approverValue: val,
                            approverName: approver.approverName,
                            active: approver.active,
                          );
                          _steps[index] = ApprovalStep(
                            id: step.id,
                            stepNo: step.stepNo,
                            stepName: step.stepName,
                            approvalMode: step.approvalMode,
                            active: step.active,
                            approvers: updated,
                            requiredApprovals: step.requiredApprovals,
                          );
                        },
                      ),
                    ),
                    if (approvers.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Remove approver',
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () {
                          final updated = List<ApprovalWorkflowStepApprover>.from(approvers)..removeAt(approverIndex);
                          final required = step.requiredApprovals > updated.length ? updated.length : step.requiredApprovals;
                          updateStep(updatedApprovers: updated, requiredApprovals: required < 1 ? 1 : required);
                        },
                      ),
                    ],
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                final updated = List<ApprovalWorkflowStepApprover>.from(approvers)
                  ..add(ApprovalWorkflowStepApprover(approverType: 'ROLE', approverValue: ''));
                updateStep(updatedApprovers: updated);
              },
              icon: const Icon(Icons.add),
              label: const Text('ADD ALTERNATIVE APPROVER'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: step.requiredApprovals.toString(),
              decoration: const InputDecoration(
                labelText: 'Required Approvals',
                helperText: 'Set to 1 for ROLE 1 OR ROLE 2. Increase only when more than one approval is required.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed < 1) return 'Must be at least 1';
                if (parsed > approvers.length) return 'Cannot exceed configured approvers (${approvers.length})';
                return null;
              },
              onChanged: (val) {
                final intVal = int.tryParse(val) ?? 1;
                _steps[index] = ApprovalStep(
                  id: step.id,
                  stepNo: step.stepNo,
                  stepName: step.stepName,
                  approvalMode: step.approvalMode,
                  active: step.active,
                  approvers: step.approvers,
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
