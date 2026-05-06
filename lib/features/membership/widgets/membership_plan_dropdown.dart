import 'package:flutter/material.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';

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
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TextFormField(
        decoration: _inputDecoration('Loading Plans...').copyWith(
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        readOnly: true,
      );
    }

    if (_error != null) {
      return TextFormField(
        decoration: _inputDecoration('Error loading plans').copyWith(
          suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlans),
        ),
        readOnly: true,
      );
    }

    final plans = _plans ?? [];
    final currentPlan = plans.any((p) => p.id == widget.value) 
        ? plans.firstWhere((p) => p.id == widget.value) 
        : null;

    return DropdownButtonFormField<String>(
      value: currentPlan?.id,
      decoration: _inputDecoration('Select Membership Plan'),
      items: plans.map((plan) {
        return DropdownMenuItem(
          value: plan.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(plan.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                'Premium: R ${(plan.premiumCents / 100).toStringAsFixed(2)} • Max Dependents: ${plan.maxDependents}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (id) {
        final selected = plans.firstWhere((p) => p.id == id);
        widget.onChanged(selected);
      },
      validator: widget.validator,
      isExpanded: true,
      itemHeight: 60,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
