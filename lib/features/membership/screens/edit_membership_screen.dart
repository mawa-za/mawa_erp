import 'package:flutter/material.dart';
import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../models/membership_detail.dart';
import '../widgets/membership_plan_dropdown.dart';
import '../services/membership_service.dart';

class EditMembershipScreen extends StatefulWidget {
  final MembershipDetail membership;
  const EditMembershipScreen({super.key, required this.membership});

  @override
  State<EditMembershipScreen> createState() => _EditMembershipScreenState();
}

class _EditMembershipScreenState extends State<EditMembershipScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingStatuses = true;

  late String _status;
  late String _planId;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime? _joinDate;
  List<FieldOption> _statusOptions = [];

  @override
  void initState() {
    super.initState();
    _status = widget.membership.status;
    _planId = widget.membership.planId;
    _startDate = widget.membership.startDate != null ? DateTime.tryParse(widget.membership.startDate!) : null;
    _endDate = widget.membership.endDate != null ? DateTime.tryParse(widget.membership.endDate!) : null;
    _joinDate = widget.membership.joinDate != null ? DateTime.tryParse(widget.membership.joinDate!) : null;
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final options = await FieldService().getOptionsByField('MEMBERSHIP-STATUS');
      if (!mounted) return;
      setState(() {
        _statusOptions = options;
        if (_statusOptions.every((o) => o.code != _status) && _status.isNotEmpty) {
          _statusOptions = [
            FieldOption(field: 'MEMBERSHIP-STATUS', code: _status, type: 'SYSTEM', description: _status, validFrom: '', validTo: ''),
            ..._statusOptions,
          ];
        }
        _isLoadingStatuses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusOptions = ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'CANCELLED']
            .map((s) => FieldOption(field: 'MEMBERSHIP-STATUS', code: s, type: 'SYSTEM', description: s, validFrom: '', validTo: ''))
            .toList();
        _isLoadingStatuses = false;
      });
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'id': widget.membership.id,
        'memberId': widget.membership.memberId,
        'membershipNo': widget.membership.membershipNo,
        'status': _status,
        'planId': _planId,
        'startDate': _startDate?.toIso8601String().split('T')[0] ?? widget.membership.startDate,
        'endDate': _endDate?.toIso8601String().split('T')[0] ?? widget.membership.endDate,
        'joinDate': _joinDate?.toIso8601String().split('T')[0] ?? widget.membership.joinDate,
      }..removeWhere((_, value) => value == null);

      await MembershipService().updateMembership(widget.membership.id, payload);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership updated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Edit Membership'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _statusOptions.any((o) => o.code == _status) ? _status : null,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: const Icon(Icons.info_outline, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: _isLoadingStatuses
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      isExpanded: true,
                      items: _statusOptions
                          .map((opt) => DropdownMenuItem(value: opt.code, child: Text(opt.description.isEmpty ? opt.code : opt.description)))
                          .toList(),
                      onChanged: _isLoadingStatuses ? null : (v) => setState(() => _status = v ?? _status),
                      validator: (v) => v == null || v.isEmpty ? 'Status is required' : null,
                    ),
                    const SizedBox(height: 16),
                    MembershipPlanDropdown(
                      value: _planId,
                      onChanged: (plan) => setState(() => _planId = plan!.id),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Changing the plan updates the membership plan used for future premiums and claims.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _update,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
