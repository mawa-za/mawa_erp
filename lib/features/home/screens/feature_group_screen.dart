import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/routing/app_routes.dart';
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

    // Some tenants use generic child identifiers such as CLAIMS or PAYMENTS.
    // Resolve them in the context of the group before applying the global
    // registry, otherwise a Funeral Claims card can be mistaken for a
    // Membership Claims card.
    final contextualRoute = _routeForCurrentGroup(wc);
    if (contextualRoute != null) {
      context.push(contextualRoute);
      return;
    }

    // The workcenter id and route key are authoritative. A number of older
    // role configurations still contain stale route paths, so resolving the
    // path first can open an unrelated feature.
    final routeById = WorkcenterRouteRegistry.getRoutePath(wc.id);
    if (routeById != null) {
      context.push(routeById);
      return;
    }

    final routeByKey = WorkcenterRouteRegistry.getRoutePath(wc.routeKey);
    if (routeByKey != null) {
      context.push(routeByKey);
      return;
    }

    final routePath = wc.routePath;
    if (routePath != null && routePath.trim().isNotEmpty) {
      final routeByPath = WorkcenterRouteRegistry.getRoutePath(routePath);
      if (routeByPath != null) {
        context.push(routeByPath);
        return;
      }
      if (routePath.startsWith('/')) {
        context.push(routePath);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${wc.description} feature coming soon')),
    );
  }

  String? _routeForCurrentGroup(Workcenter workcenter) {
    final group = FeatureGroupRegistry.normalize(widget.groupId);
    final identity = [
      workcenter.id,
      workcenter.routeKey,
      workcenter.description,
      workcenter.routePath ?? '',
    ].map(FeatureGroupRegistry.normalize).join('_');

    if (group == FeatureGroupRegistry.normalize('funeral-management')) {
      if (identity.contains('CLAIM')) return AppRoutes.funeralAllClaims;
      if (identity.contains('PAYMENT')) return AppRoutes.funeralPayments;
      if (identity.contains('PICKUP')) return AppRoutes.funeralPickups;
      if (identity.contains('MORTUARY') || identity.contains('CORPSE')) {
        return AppRoutes.funeralMortuary;
      }
      if (identity.contains('PACKAGE')) return AppRoutes.funeralPackageSetup;
      if (identity.contains('SERVICE') ||
          identity.contains('ARRANGEMENT') ||
          identity.contains('REQUEST')) {
        return AppRoutes.funeralServiceRequests;
      }
    }

    if (group == FeatureGroupRegistry.normalize('membership-management')) {
      if (identity.contains('CLAIM')) return AppRoutes.membershipClaims;
      if (identity.contains('PLAN')) return AppRoutes.membershipPlans;
      if (identity.contains('GROUP') || identity.contains('SOCIET')) {
        return AppRoutes.groupSocieties;
      }
      if (identity.contains('MEMBER')) return AppRoutes.memberships;
    }

    if (group == FeatureGroupRegistry.normalize('inventory')) {
      if (identity.contains('PRODUCT')) return AppRoutes.products;
      if (identity.contains('QUOT')) return AppRoutes.inventoryQuotations;
      if (identity.contains('PURCHASE') && identity.contains('ORDER')) {
        return AppRoutes.inventoryPurchaseOrders;
      }
      if (identity.contains('STOCK') && identity.contains('HAND')) {
        return AppRoutes.inventoryStockOnHand;
      }
      if (identity.contains('GOODS') && identity.contains('RECEIPT')) {
        return AppRoutes.inventoryGoodsReceipts;
      }
      if (identity.contains('PUTAWAY')) return AppRoutes.inventoryPutaways;
      if (identity.contains('MOVEMENT')) return AppRoutes.inventoryMovements;
      if (identity.contains('SALES') && identity.contains('ORDER')) {
        return AppRoutes.inventorySalesOrders;
      }
      if (identity.contains('AUDIT')) return AppRoutes.inventoryAudit;
      if (identity.contains('SETUP') || identity.contains('CONFIG')) {
        return AppRoutes.inventorySetup;
      }
    }

    return null;
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
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text(title),
        actions: [IconButton(onPressed: _loadChildren, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _children.isEmpty
                  ? const Center(child: Text('No features are available for your current role.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isFuneral = FeatureGroupRegistry.normalize(
                              widget.groupId,
                            ) ==
                            FeatureGroupRegistry.normalize(
                              'funeral-management',
                            );

                        if (isFuneral) {
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _children.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _workcenterCard(_children[index], compact: true),
                          );
                        }

                        final crossAxisCount =
                            (constraints.maxWidth / 210).floor().clamp(1, 5);
                        return GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.25,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _children.length,
                          itemBuilder: (context, index) =>
                              _workcenterCard(_children[index]),
                        );
                      },
                    ),
    );
  }
  Widget _workcenterCard(Workcenter workcenter, {bool compact = false}) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(compact ? 14 : 18);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _openWorkcenter(workcenter),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: compact
              ? Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withOpacity(0.55),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        _iconFor(workcenter.id),
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        workcenter.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconFor(workcenter.id),
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const Spacer(),
                    Text(
                      workcenter.description,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workcenter.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

}
