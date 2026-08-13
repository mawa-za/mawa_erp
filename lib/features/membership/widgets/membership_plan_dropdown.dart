import 'package:flutter/material.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class MembershipPlanDropdown extends StatefulWidget {
  final String? value;
  final ValueChanged<MembershipPlan?> onChanged;
  final String? Function(String?)? validator;

  const MembershipPlanDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  State<MembershipPlanDropdown> createState() => _MembershipPlanDropdownState();
}

class _MembershipPlanDropdownState extends State<MembershipPlanDropdown> {
  List<MembershipPlan>? _plans;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final response = await MembershipService().getMembershipPlans();
      if (mounted) {
        setState(() {
          _plans = response.content.where((p) => p.active).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Loading Plans...', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return InkWell(
        onTap: _loadPlans,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Error loading plans', style: TextStyle(color: colorScheme.error, fontSize: 14))),
              Icon(Icons.refresh, color: colorScheme.error, size: 20),
            ],
          ),
        ),
      );
    }

    final plans = _plans ?? [];
    final currentPlanId = plans.any((p) => p.id == widget.value) 
        ? widget.value 
        : null;

    return SearchableDropdownFormField<String>(
      key: ValueKey(widget.value),
      value: currentPlanId,
      decoration: InputDecoration(
        labelText: 'Select Membership Plan',
        prefixIcon: Icon(Icons.card_membership_rounded, size: 20, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      selectedItemBuilder: (BuildContext context) {
        return plans.map((plan) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              plan.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: plans.map((plan) {
        return DropdownMenuItem(
          value: plan.id,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(plan.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'R ${plan.premium.toStringAsFixed(2)} / month • Max ${plan.maxDependents} deps',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (plan.id == widget.value)
                  Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) {
          widget.onChanged(null);
          return;
        }
        final selected = plans.firstWhere((p) => p.id == id);
        widget.onChanged(selected);
      },
      validator: widget.validator,
      isExpanded: true,
      itemHeight: 64,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Colors.white,
    );
  }
}
