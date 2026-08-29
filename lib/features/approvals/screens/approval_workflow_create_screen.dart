import 'package:flutter/material.dart';

import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../../employment/services/employment_service.dart';
import '../../settings/models/role.dart';
import '../../settings/services/role_service.dart';
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
  List<Role> _roles = const [];
  List<User> _users = const [];
  List<Map<String, dynamic>> _employments = const [];

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
    'LAYBY_CANCELLATION',
    'LAYBY_REFUND',
    'MEMBERSHIP_DEPENDENT_CHANGE',
    'MEMBERSHIP_PLAN_CHANGE',
    'MEMBERSHIP_PREMIUM_EDIT',
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
    _loadLeaveApproverOptions();
  }

  Future<void> _loadLeaveApproverOptions() async {
    try {
      final values = await Future.wait([
        RoleService().getRoles(),
        UserService().getUsers(),
        EmploymentService().list(),
      ]);
      if (!mounted) return;
      setState(() {
        _roles = List<Role>.from(values[0] as List);
        _users = List<User>.from(values[1] as List);
        _employments = List<Map<String, dynamic>>.from(values[2] as List)
            .where(
              (employment) => const {'ACTIVE', 'SUSPENDED'}.contains(
                (employment['status'] ?? '').toString().toUpperCase(),
              ),
            )
            .toList();
      });
    } catch (_) {
      // The workflow can still be edited; dropdowns will show no selectable values.
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
              final availableApproverTypes = _selectedApprovalType == 'LEAVE'
                  ? const ['ROLE', 'USER']
                  : _approverTypes;
              final approverType = availableApproverTypes.contains(approver.approverType)
                  ? approver.approverType
                  : availableApproverTypes.first;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SearchableDropdownFormField<String>(
                            value: approverType,
                            decoration: InputDecoration(
                              labelText: approvers.length > 1
                                  ? 'Approver ${approverIndex + 1} Type'
                                  : 'Approver Type',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableApproverTypes
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      _selectedApprovalType == 'LEAVE'
                                          ? (t == 'ROLE'
                                              ? 'Role'
                                              : 'Specific employee')
                                          : t,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final updated =
                                  List<ApprovalWorkflowStepApprover>.from(
                                approvers,
                              );
                              updated[approverIndex] =
                                  ApprovalWorkflowStepApprover(
                                id: approver.id,
                                approverType: val,
                                approverValue: _selectedApprovalType == 'LEAVE'
                                    ? ''
                                    : approver.approverValue,
                                approverName: approver.approverName,
                                assignmentScopeType:
                                    approver.assignmentScopeType,
                                assignmentScopeValue:
                                    approver.assignmentScopeValue,
                                active: approver.active,
                              );
                              updateStep(updatedApprovers: updated);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _selectedApprovalType == 'LEAVE'
                              ? _leaveApproverValueField(
                                  approver,
                                  approverType,
                                  approverIndex,
                                  approvers,
                                  step,
                                  index,
                                )
                              : TextFormField(
                                  key: ValueKey(
                                    'workflow-step-${step.stepNo}-approver-$approverIndex-${approver.id ?? 'new'}',
                                  ),
                                  initialValue: approver.approverValue,
                                  decoration: InputDecoration(
                                    labelText: approver.approverType == 'ROLE'
                                        ? 'Role'
                                        : 'Approver Value',
                                    hintText: approver.approverType == 'ROLE'
                                        ? 'e.g. DIRECTOR'
                                        : null,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                  onChanged: (val) {
                                    final updated =
                                        List<ApprovalWorkflowStepApprover>.from(
                                      approvers,
                                    );
                                    updated[approverIndex] =
                                        ApprovalWorkflowStepApprover(
                                      id: approver.id,
                                      approverType: approver.approverType,
                                      approverValue: val,
                                      approverName: approver.approverName,
                                      assignmentScopeType:
                                          approver.assignmentScopeType,
                                      assignmentScopeValue:
                                          approver.assignmentScopeValue,
                                      active: approver.active,
                                    );
                                    _steps[index] = ApprovalStep(
                                      id: step.id,
                                      stepNo: step.stepNo,
                                      stepName: step.stepName,
                                      approvalMode: step.approvalMode,
                                      active: step.active,
                                      approvers: updated,
                                      requiredApprovals:
                                          step.requiredApprovals,
                                    );
                                  },
                                ),
                        ),
                        if (approvers.length > 1) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Remove approver',
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              final updated =
                                  List<ApprovalWorkflowStepApprover>.from(
                                approvers,
                              )..removeAt(approverIndex);
                              final required =
                                  step.requiredApprovals > updated.length
                                      ? updated.length
                                      : step.requiredApprovals;
                              updateStep(
                                updatedApprovers: updated,
                                requiredApprovals: required < 1 ? 1 : required,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    if (_selectedApprovalType == 'LEAVE') ...[
                      const SizedBox(height: 10),
                      _leaveScopeFields(
                        approver,
                        approverIndex,
                        approvers,
                        step,
                        index,
                      ),
                    ],
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                final updated =
                    List<ApprovalWorkflowStepApprover>.from(approvers)
                      ..add(
                        ApprovalWorkflowStepApprover(
                          approverType: 'ROLE',
                          approverValue: '',
                        ),
                      );
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

  Widget _leaveApproverValueField(
    ApprovalWorkflowStepApprover approver,
    String approverType,
    int approverIndex,
    List<ApprovalWorkflowStepApprover> approvers,
    ApprovalStep step,
    int stepIndex,
  ) {
    if (approverType == 'ROLE') {
      return SearchableDropdownFormField<String>(
        value: _roles.any((role) => role.id == approver.approverValue)
            ? approver.approverValue
            : null,
        decoration: const InputDecoration(
          labelText: 'Approver role',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _roles
            .map(
              (role) => DropdownMenuItem(
                value: role.id,
                child: Text(role.description.isEmpty
                    ? role.id
                    : '${role.description} (${role.id})'),
              ),
            )
            .toList(),
        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
        onChanged: (value) => _replaceApprover(
          stepIndex,
          step,
          approvers,
          approverIndex,
          approver,
          approverType: approverType,
          approverValue: value ?? '',
        ),
      );
    }

    final activeEmployeePartnerIds = _employments
        .where((employment) => employment['employee'] is Map)
        .map((employment) => (employment['employee'] as Map)['id']?.toString())
        .whereType<String>()
        .toSet();
    final employeeUsers = _users
        .where(
          (user) =>
              user.status.toUpperCase() == 'ACTIVE' &&
              user.partner != null &&
              activeEmployeePartnerIds.contains(user.partner!.id),
        )
        .toList();
    return SearchableDropdownFormField<String>(
      value: employeeUsers.any((user) => user.id == approver.approverValue)
          ? approver.approverValue
          : null,
      decoration: const InputDecoration(
        labelText: 'Approver employee',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: employeeUsers
          .map(
            (user) => DropdownMenuItem(
              value: user.id,
              child: Text(
                '${user.partner?.fullName ?? user.displayName ?? user.username} • ${user.username}',
              ),
            ),
          )
          .toList(),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      onChanged: (value) => _replaceApprover(
        stepIndex,
        step,
        approvers,
        approverIndex,
        approver,
        approverType: approverType,
        approverValue: value ?? '',
      ),
    );
  }

  Widget _leaveScopeFields(
    ApprovalWorkflowStepApprover approver,
    int approverIndex,
    List<ApprovalWorkflowStepApprover> approvers,
    ApprovalStep step,
    int stepIndex,
  ) {
    const scopeTypes = ['ALL', 'POSITION', 'EMPLOYEE'];
    final scopeType = scopeTypes.contains(approver.assignmentScopeType)
        ? approver.assignmentScopeType
        : 'ALL';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SearchableDropdownFormField<String>(
            value: scopeType,
            decoration: const InputDecoration(
              labelText: 'Employee scope',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All employees')),
              DropdownMenuItem(value: 'POSITION', child: Text('Position')),
              DropdownMenuItem(value: 'EMPLOYEE', child: Text('Specific employee')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _replaceApprover(
                stepIndex,
                step,
                approvers,
                approverIndex,
                approver,
                assignmentScopeType: value,
                assignmentScopeValue: null,
              );
            },
          ),
        ),
        if (scopeType != 'ALL') ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: scopeType == 'POSITION'
                ? _positionScopeField(
                    approver,
                    approverIndex,
                    approvers,
                    step,
                    stepIndex,
                  )
                : _employeeScopeField(
                    approver,
                    approverIndex,
                    approvers,
                    step,
                    stepIndex,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _positionScopeField(
    ApprovalWorkflowStepApprover approver,
    int approverIndex,
    List<ApprovalWorkflowStepApprover> approvers,
    ApprovalStep step,
    int stepIndex,
  ) {
    final positions = <String, String>{};
    for (final employment in _employments) {
      final code = (employment['position'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      final description = (employment['positionDescription'] ?? '').toString().trim();
      positions[code] = description.isEmpty ? code : '$description ($code)';
    }
    return SearchableDropdownFormField<String>(
      value: positions.containsKey(approver.assignmentScopeValue)
          ? approver.assignmentScopeValue
          : null,
      decoration: const InputDecoration(
        labelText: 'Position',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: positions.entries
          .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
          .toList(),
      validator: (value) => value == null || value.isEmpty ? 'Position is required' : null,
      onChanged: (value) => _replaceApprover(
        stepIndex,
        step,
        approvers,
        approverIndex,
        approver,
        assignmentScopeValue: value,
      ),
    );
  }

  Widget _employeeScopeField(
    ApprovalWorkflowStepApprover approver,
    int approverIndex,
    List<ApprovalWorkflowStepApprover> approvers,
    ApprovalStep step,
    int stepIndex,
  ) {
    final employees = _employments.where((employment) {
      final employee = employment['employee'];
      return employee is Map && employee['id'] != null;
    }).toList();
    return SearchableDropdownFormField<String>(
      value: employees.any((employment) {
        final employee = Map<String, dynamic>.from(employment['employee'] as Map);
        return employee['id']?.toString() == approver.assignmentScopeValue;
      })
          ? approver.assignmentScopeValue
          : null,
      decoration: const InputDecoration(
        labelText: 'Employee',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: employees.map((employment) {
        final employee = Map<String, dynamic>.from(employment['employee'] as Map);
        final id = employee['id'].toString();
        final names = [employee['name2'], employee['name3'], employee['name1']]
            .map((value) => (value ?? '').toString().trim())
            .where((value) => value.isNotEmpty)
            .join(' ');
        return DropdownMenuItem(
          value: id,
          child: Text('${names.isEmpty ? 'Employee' : names} • ${employment['employeeNumber'] ?? '-'}'),
        );
      }).toList(),
      validator: (value) => value == null || value.isEmpty ? 'Employee is required' : null,
      onChanged: (value) => _replaceApprover(
        stepIndex,
        step,
        approvers,
        approverIndex,
        approver,
        assignmentScopeValue: value,
      ),
    );
  }

  void _replaceApprover(
    int stepIndex,
    ApprovalStep step,
    List<ApprovalWorkflowStepApprover> approvers,
    int approverIndex,
    ApprovalWorkflowStepApprover approver, {
    String? approverType,
    String? approverValue,
    String? assignmentScopeType,
    String? assignmentScopeValue,
  }) {
    final updated = List<ApprovalWorkflowStepApprover>.from(approvers);
    final nextScopeType = assignmentScopeType ?? approver.assignmentScopeType;
    final scopeTypeChanged = assignmentScopeType != null &&
        assignmentScopeType != approver.assignmentScopeType;
    final nextScopeValue = nextScopeType == 'ALL'
        ? null
        : scopeTypeChanged
            ? assignmentScopeValue
            : (assignmentScopeValue ?? approver.assignmentScopeValue);
    updated[approverIndex] = ApprovalWorkflowStepApprover(
      id: approver.id,
      approverType: approverType ?? approver.approverType,
      approverValue: approverValue ?? approver.approverValue,
      approverName: approver.approverName,
      assignmentScopeType: nextScopeType,
      assignmentScopeValue: nextScopeValue,
      active: approver.active,
    );
    setState(() {
      _steps[stepIndex] = ApprovalStep(
        id: step.id,
        stepNo: step.stepNo,
        stepName: step.stepName,
        approvalMode: step.approvalMode,
        active: step.active,
        approvers: updated,
        requiredApprovals: step.requiredApprovals,
      );
    });
  }

}
