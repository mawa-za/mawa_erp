import 'package:flutter/material.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import 'membership_plan_create_screen.dart';

class MembershipPlanDetailScreen extends StatefulWidget {
  final String planId;

  const MembershipPlanDetailScreen({super.key, required this.planId});

  @override
  State<MembershipPlanDetailScreen> createState() => _MembershipPlanDetailScreenState();
}

class _MembershipPlanDetailScreenState extends State<MembershipPlanDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  MembershipPlan? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPlanDetails();
  }

  Future<void> _fetchPlanDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plan = await MembershipService().getMembershipPlanById(widget.planId);
      if (mounted) {
        setState(() {
          _plan = plan;
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Plan not found'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchPlanDetails, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(_plan!.name),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => MembershipPlanCreateScreen(plan: _plan)),
              );
              if (result == true) {
                _fetchPlanDetails();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDeletePlan(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Premium Rules'),
            Tab(text: 'Claim Payouts'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(colorScheme),
          _buildPremiumRulesTab(colorScheme),
          _buildClaimPayoutsTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard([
            _buildDetailRow('Plan Code', _plan!.planCode),
            const Divider(),
            _buildDetailRow('Description', _plan!.description),
            const Divider(),
            _buildDetailRow('Monthly Premium', 'R ${_plan!.premium.toStringAsFixed(2)}'),
            const Divider(),
            _buildDetailRow('Max Dependents', _plan!.maxDependents.toString()),
            const Divider(),
            _buildDetailRow('Status', _plan!.active ? 'ACTIVE' : 'INACTIVE', 
                valueColor: _plan!.active ? Colors.green : Colors.red),
          ]),
        ],
      ),
    );
  }

  Widget _buildPremiumRulesTab(ColorScheme colorScheme) {
    final rules = _plan!.premiumRules ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rules for additional dependents', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              TextButton.icon(
                onPressed: () => _showAddRuleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rule'),
              ),
            ],
          ),
        ),
        Expanded(
          child: rules.isEmpty 
            ? _buildEmptyState(Icons.rule, 'No premium rules defined')
            : RefreshIndicator(
                onRefresh: _fetchPlanDetails,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        title: Text(rule.dependentType.name.replaceAll('_', ' ')),
                        subtitle: Text('Age: ${rule.minAge} - ${rule.maxAge} years'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+R ${rule.additionalPremium.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                if (!rule.active) const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => _deleteRule(rule.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildClaimPayoutsTab(ColorScheme colorScheme) {
    final payouts = _plan!.claimPayouts ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Benefit payout configurations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              TextButton.icon(
                onPressed: () => _showAddPayoutDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Payout'),
              ),
            ],
          ),
        ),
        Expanded(
          child: payouts.isEmpty 
            ? _buildEmptyState(Icons.monetization_on_outlined, 'No claim payouts defined')
            : RefreshIndicator(
                onRefresh: _fetchPlanDetails,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: payouts.length,
                  itemBuilder: (context, index) {
                    final payout = payouts[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        title: Text(payout.claimType.name),
                        subtitle: Text('For: ${payout.dependentType.name.replaceAll('_', ' ')}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('R ${payout.payoutAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => _deletePayout(payout.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text('Are you sure you want to delete this membership plan? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await MembershipService().deleteMembershipPlan(widget.planId);
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRule(String ruleId) async {
    try {
      await MembershipService().deletePremiumRule(widget.planId, ruleId);
      _fetchPlanDetails();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deletePayout(String payoutId) async {
    try {
      await MembershipService().deleteClaimPayout(widget.planId, payoutId);
      _fetchPlanDetails();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddRuleDialog() {
    DependentType selectedType = DependentType.EXTENDED_FAMILY;
    final minAgeController = TextEditingController(text: '0');
    final maxAgeController = TextEditingController(text: '100');
    final premiumController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Premium Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DependentType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Dependent Type'),
                  items: DependentType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.replaceAll('_', ' ')),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                TextField(
                  controller: minAgeController,
                  decoration: const InputDecoration(labelText: 'Min Age'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: maxAgeController,
                  decoration: const InputDecoration(labelText: 'Max Age'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: premiumController,
                  decoration: const InputDecoration(labelText: 'Additional Premium', prefixText: 'R '),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'dependentType': selectedType.name,
                  'minAge': int.tryParse(minAgeController.text) ?? 0,
                  'maxAge': int.tryParse(maxAgeController.text) ?? 100,
                  'additionalPremiumCents': ((double.tryParse(premiumController.text) ?? 0.0) * 100).round(),
                  'active': true,
                };
                try {
                  await MembershipService().addPremiumRule(widget.planId, payload);
                  Navigator.pop(context);
                  _fetchPlanDetails();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPayoutDialog() {
    ClaimType selectedClaimType = ClaimType.CASH;
    DependentType selectedDependentType = DependentType.MAIN_MEMBER;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Claim Payout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ClaimType>(
                  value: selectedClaimType,
                  decoration: const InputDecoration(labelText: 'Claim Type'),
                  items: ClaimType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedClaimType = v!),
                ),
                DropdownButtonFormField<DependentType>(
                  value: selectedDependentType,
                  decoration: const InputDecoration(labelText: 'Recipient Type'),
                  items: DependentType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.replaceAll('_', ' ')),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedDependentType = v!),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Payout Amount', prefixText: 'R '),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'claimType': selectedClaimType.name,
                  'dependentType': selectedDependentType.name,
                  'payoutAmountCents': ((double.tryParse(amountController.text) ?? 0.0) * 100).round(),
                  'active': true,
                };
                try {
                  await MembershipService().addClaimPayout(widget.planId, payload);
                  Navigator.pop(context);
                  _fetchPlanDetails();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
