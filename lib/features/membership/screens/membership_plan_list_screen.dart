import 'package:flutter/material.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import 'membership_plan_create_screen.dart';

class MembershipPlanListScreen extends StatefulWidget {
  const MembershipPlanListScreen({super.key});

  @override
  State<MembershipPlanListScreen> createState() => _MembershipPlanListScreenState();
}

class _MembershipPlanListScreenState extends State<MembershipPlanListScreen> {
  bool _isLoading = true;
  List<MembershipPlan> _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plans = await MembershipService().getMembershipPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Membership Plans'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchPlans,
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const MembershipPlanCreateScreen()),
          );
          if (result == true) {
            _fetchPlans();
          }
        },
        label: const Text('New Plan'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Failed to load plans', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchPlans, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No membership plans found', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Create your first plan to start linking members', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return _buildPlanCard(plan, colorScheme);
      },
    );
  }

  Widget _buildPlanCard(MembershipPlan plan, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: plan.active ? Colors.transparent : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (!plan.active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('INACTIVE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(plan.description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoTag(Icons.payments_outlined, 'R ${plan.premium.toStringAsFixed(2)}', colorScheme.primary),
                const SizedBox(width: 12),
                _buildInfoTag(Icons.people_outline_rounded, 'Max ${plan.maxDependents}', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
