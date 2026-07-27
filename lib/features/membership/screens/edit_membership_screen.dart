import 'package:flutter/material.dart';
import '../models/membership_detail.dart';
import '../services/membership_service.dart';
import '../../../core/widgets/app_dropdown.dart';

class EditMembershipScreen extends StatefulWidget {
  final MembershipDetail membership;
  const EditMembershipScreen({super.key, required this.membership});

  @override
  State<EditMembershipScreen> createState() => _EditMembershipScreenState();
}

class _EditMembershipScreenState extends State<EditMembershipScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String _status;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late DateTime? _joinDate;

  @override
  void initState() {
    super.initState();
    _status = widget.membership.status;
    _startDate = widget.membership.startDate != null ? DateTime.tryParse(widget.membership.startDate!) : null;
    _endDate = widget.membership.endDate != null ? DateTime.tryParse(widget.membership.endDate!) : null;
    _joinDate = widget.membership.joinDate != null ? DateTime.tryParse(widget.membership.joinDate!) : null;
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final payload = widget.membership.toJson();
      payload['status'] = _status;
      payload['startDate'] = _startDate?.toIso8601String().split('T')[0];
      payload['endDate'] = _endDate?.toIso8601String().split('T')[0];
      payload['joinDate'] = _joinDate?.toIso8601String().split('T')[0];
      payload['updatedAt'] = DateTime.now().toUtc().toIso8601String();

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  AppDropdownField(
                    field: 'MEMBERSHIP-STATUS',
                    label: 'Status',
                    icon: Icons.info_outline,
                    value: _status,
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Membership Plan',
                      border: OutlineInputBorder(),
                      helperText: 'Use Change Plan on Membership Details. Plan changes require approval.',
                    ),
                    child: Text(widget.membership.planId),
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
