import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/routing/feature_group_registry.dart';
import '../../../core/routing/workcenter_route_registry.dart';
import '../../../core/services/module_usage_service.dart';
import '../models/workcenter.dart';

class FeatureGroupScreen extends StatefulWidget {
  final String groupId;

  const FeatureGroupScreen({super.key, required this.groupId});

  @override
  State<FeatureGroupScreen> createState() => _FeatureGroupScreenState();
}

class _FeatureGroupScreenState extends State<FeatureGroupScreen> {
  final ModuleUsageService _moduleUsageService = ModuleUsageService();
  bool _loading = true;
  String? _error;
  List<Workcenter> _children = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final group = FeatureGroupRegistry.groupById(widget.groupId);
      if (group == null) {
        throw Exception('Unknown feature group: ${widget.groupId}');
      }

      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getString('selectedRole');
      if (roleId == null || roleId.isEmpty) {
        throw Exception('No selected role found');
      }

      final response = await ApiClient().get('/role/$roleId/workcenter');
      if (response.statusCode != 200) {
        throw Exception('Failed to load role workcenters: ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final all = data.map((json) => Workcenter.fromJson(json)).toList();
      final allowed = all.where((wc) => group.matches(wc.id, wc.description) && !FeatureGroupRegistry.isGroupId(wc.id)).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      if (!mounted) return;
      setState(() {
        _children = allowed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openWorkcenter(Workcenter wc) {
    _moduleUsageService.trackUsage(
      moduleCode: wc.id,
      moduleName: wc.description,
      modulePath: wc.routePath,
      workcenterId: wc.id,
    );

    final routePath = wc.routePath;
    if (routePath != null && routePath.startsWith('/')) {
      context.go(routePath);
      return;
    }

    if (routePath != null && routePath.trim().isNotEmpty) {
      final routeByPath = WorkcenterRouteRegistry.getRoutePath(routePath);
      if (routeByPath != null) {
        context.push(routeByPath);
        return;
      }
    }

    final routeByKey = WorkcenterRouteRegistry.getRoutePath(wc.routeKey);
    if (routeByKey != null) {
      context.push(routeByKey);
      return;
    }

    final routeById = WorkcenterRouteRegistry.getRoutePath(wc.id);
    if (routeById != null) {
      context.push(routeById);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${wc.description} feature coming soon')),
    );
  }

  IconData _iconFor(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('receipt')) return Icons.call_received_outlined;
    if (lower.contains('putaway')) return Icons.compare_arrows_outlined;
    if (lower.contains('stock')) return Icons.inventory_2_outlined;
    if (lower.contains('sales-order')) return Icons.shopping_cart_outlined;
    if (lower.contains('invoice')) return Icons.description_outlined;
    if (lower.contains('payment')) return Icons.account_balance_wallet_outlined;
    if (lower.contains('cashup')) return Icons.point_of_sale_outlined;
    if (lower.contains('funeral')) return Icons.volunteer_activism_outlined;
    if (lower.contains('mortuary')) return Icons.local_hospital_outlined;
    if (lower.contains('pickup')) return Icons.local_shipping_outlined;
    if (lower.contains('claim')) return Icons.request_quote_outlined;
    if (lower.contains('calendar') || lower.contains('appointment')) return Icons.event_available_outlined;
    if (lower.contains('customer') || lower.contains('client') || lower.contains('partner')) return Icons.people_alt_outlined;
    if (lower.contains('supplier')) return Icons.local_shipping_outlined;
    if (lower.contains('employee')) return Icons.badge_outlined;
    if (lower.contains('setting') || lower.contains('config')) return Icons.settings_outlined;
    if (lower.contains('api') || lower.contains('queue')) return Icons.integration_instructions_outlined;
    return Icons.apps_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final group = FeatureGroupRegistry.groupById(widget.groupId);
    final title = group?.title ?? 'Feature Group';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(onPressed: _loadChildren, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _children.isEmpty
                  ? const Center(child: Text('No features are available for your current role.'))
                  : LayoutBuilder(builder: (context, constraints) {
                      final crossAxisCount = (constraints.maxWidth / 210).floor().clamp(1, 5);
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.25,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          final wc = _children[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openWorkcenter(wc),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(_iconFor(wc.id), size: 32, color: Theme.of(context).colorScheme.primary),
                                    const Spacer(),
                                    Text(wc.description, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(wc.id, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
    );
  }
}
