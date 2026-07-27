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
      final service = MembershipService();
      
      // Fetch plan, rules, and payouts in parallel using the specific endpoints
      final results = await Future.wait([
        service.getMembershipPlanById(widget.planId),
        service.getPremiumRules(widget.planId),
        service.getClaimPayouts(widget.planId),
      ]);

      final plan = results[0] as MembershipPlan;
      final rules = results[1] as List<MembershipPlanPremiumRule>;
      final payouts = results[2] as List<MembershipPlanClaimPayout>;

      if (mounted) {
        setState(() {
          _plan = plan.copyWith(
            premiumRules: rules,
            claimPayouts: payouts,
          );
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_plan!.name),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
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
            tooltip: 'Edit Plan',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDeletePlan(),
            tooltip: 'Delete Plan',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'PREMIUM RULES'),
            Tab(text: 'BENEFITS'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
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
          _buildSectionHeader(Icons.info_outline, 'GENERAL INFORMATION'),
          const SizedBox(height: 12),
          _buildInfoCard([
            _buildDetailRow(Icons.qr_code, 'Plan Code', _plan!.planCode),
            const Divider(height: 24),
            _buildDetailRow(Icons.description_outlined, 'Description', _plan!.description, isMultiLine: true),
            const Divider(height: 24),
            _buildDetailRow(Icons.payments_outlined, 'Base Premium', 'R ${_plan!.premium.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _buildDetailRow(Icons.people_outline, 'Max Dependents', _plan!.maxDependents.toString()),
            const Divider(height: 24),
            _buildDetailRow(Icons.toggle_on_outlined, 'Status', _plan!.active ? 'ACTIVE' : 'INACTIVE', 
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
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.rule, 'PRICING RULES'),
              TextButton.icon(
                onPressed: () => _showRuleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD RULE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: rules.isEmpty 
            ? _buildEmptyState(Icons.rule, 'No premium rules defined', 'Rules define additional costs based on age and type.')
            : RefreshIndicator(
                onRefresh: _fetchPlanDetails,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _showRuleDialog(rule: rule),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer.withOpacity(0.5),
                          child: Icon(Icons.person_add_alt_1_outlined, color: colorScheme.secondary, size: 20),
                        ),
                        title: Text(
                          rule.dependentType.name.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text('Age range: ${rule.minAge} - ${rule.maxAge} years'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+ R ${rule.additionalPremium.toStringAsFixed(2)}', 
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 15)),
                                if (!rule.active) const Text('INACTIVE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(width: 12),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(Icons.monetization_on_outlined, 'PLAN BENEFITS'),
              TextButton.icon(
                onPressed: () => _showPayoutDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD BENEFIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: payouts.isEmpty 
            ? _buildEmptyState(Icons.volunteer_activism_outlined, 'No benefits defined', 'Define how much is paid out for different claim types.')
            : RefreshIndicator(
                onRefresh: _fetchPlanDetails,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: payouts.length,
                  itemBuilder: (context, index) {
                    final payout = payouts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _showPayoutDialog(payout: payout),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.green, size: 20),
                        ),
                        title: Text(
                          payout.claimType.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text('Recipient: ${payout.dependentType.name.replaceAll('_', ' ')}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('R ${payout.payoutAmount.toStringAsFixed(2)}', 
                              style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.primary, fontSize: 15)),
                            const SizedBox(width: 12),
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isMultiLine = false}) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text('Are you sure you want to delete this membership plan? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await MembershipService().deleteMembershipPlan(widget.planId);
                if (mounted) Navigator.pop(context, true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
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

  void _showRuleDialog({MembershipPlanPremiumRule? rule}) {
    DependentType selectedType = rule?.dependentType ?? DependentType.EXTENDED_FAMILY;
    final minAgeController = TextEditingController(text: rule?.minAge.toString() ?? '0');
    final maxAgeController = TextEditingController(text: rule?.maxAge.toString() ?? '100');
    final premiumController = TextEditingController(text: rule != null ? rule.additionalPremium.toString() : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(rule == null ? 'Add Premium Rule' : 'Edit Premium Rule'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DependentType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Dependent Type', border: OutlineInputBorder()),
                  items: DependentType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.replaceAll('_', ' ')),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minAgeController,
                        decoration: const InputDecoration(labelText: 'Min Age', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: maxAgeController,
                        decoration: const InputDecoration(labelText: 'Max Age', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: premiumController,
                  decoration: const InputDecoration(labelText: 'Additional Premium', prefixText: 'R ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final payload = {
                  'dependentType': selectedType.name,
                  'minAge': int.tryParse(minAgeController.text) ?? 0,
                  'maxAge': int.tryParse(maxAgeController.text) ?? 100,
                  'additionalPremiumCents': ((double.tryParse(premiumController.text) ?? 0.0) * 100).round(),
                  'active': true,
                };
                try {
                  if (rule == null) {
                    await MembershipService().addPremiumRule(widget.planId, payload);
                  } else {
                    await MembershipService().updatePremiumRule(widget.planId, rule.id!, payload);
                  }
                  Navigator.pop(context);
                  _fetchPlanDetails();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(rule == null ? 'ADD' : 'SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutDialog({MembershipPlanClaimPayout? payout}) {
    ClaimType selectedClaimType = payout?.claimType ?? ClaimType.CASH;
    DependentType selectedDependentType = payout?.dependentType ?? DependentType.MAIN_MEMBER;
    final amountController = TextEditingController(text: payout != null ? payout.payoutAmount.toString() : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(payout == null ? 'Add Claim Payout' : 'Edit Claim Payout'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ClaimType>(
                  value: selectedClaimType,
                  decoration: const InputDecoration(labelText: 'Claim Type', border: OutlineInputBorder()),
                  items: ClaimType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedClaimType = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DependentType>(
                  value: selectedDependentType,
                  decoration: const InputDecoration(labelText: 'Recipient Type', border: OutlineInputBorder()),
                  items: DependentType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.replaceAll('_', ' ')),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedDependentType = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Payout Amount', prefixText: 'R ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final payload = {
                  'claimType': selectedClaimType.name,
                  'dependentType': selectedDependentType.name,
                  'payoutAmountCents': ((double.tryParse(amountController.text) ?? 0.0) * 100).round(),
                  'active': true,
                };
                try {
                  if (payout == null) {
                    await MembershipService().addClaimPayout(widget.planId, payload);
                  } else {
                    await MembershipService().updateClaimPayout(widget.planId, payout.id!, payload);
                  }
                  Navigator.pop(context);
                  _fetchPlanDetails();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(payout == null ? 'ADD' : 'SAVE'),
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
