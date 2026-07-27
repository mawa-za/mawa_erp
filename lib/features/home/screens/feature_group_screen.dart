import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/feature_group_registry.dart';
import '../../../core/routing/workcenter_route_registry.dart';
import '../../../core/routing/workcenter_card_descriptions.dart';
import '../../../core/services/module_usage_service.dart';
import '../../../core/services/tenant_experience_service.dart';
import '../../../core/theme/mawa_design.dart';
import '../../../core/widgets/mawa_ui.dart';
import '../../approvals/services/approval_workflow_service.dart';
import '../models/workcenter.dart';
import '../models/tenant_experience.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FeatureGroupScreen extends StatefulWidget {
  final String groupId;

  const FeatureGroupScreen({super.key, required this.groupId});

  @override
  State<FeatureGroupScreen> createState() => _FeatureGroupScreenState();
}

class _FeatureGroupScreenState extends State<FeatureGroupScreen> {
  final ModuleUsageService _moduleUsageService = ModuleUsageService();
  final ApprovalWorkflowService _approvalWorkflowService = ApprovalWorkflowService();
  final TenantExperienceService _tenantExperienceService = TenantExperienceService();
  bool _loading = true;
  String? _error;
  List<Workcenter> _children = [];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _gridView = true;
  TenantExperienceGroup? _experienceGroup;
  String _groupTitle = 'Workcenter';
  String _groupDescription = 'Open a feature to continue.';

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
      TenantExperience? experience;
      try {
        experience = await _tenantExperienceService.getExperience();
      } catch (_) {
        // Industry presentation is additive. Legacy grouping remains available
        // if configuration refresh is temporarily unavailable.
      }

      final fallbackGroup = FeatureGroupRegistry.groupById(widget.groupId);
      final canonicalGroupId = FeatureGroupRegistry.canonicalGroupId(widget.groupId);
      final experienceGroup = experience?.groupByCode(canonicalGroupId) ??
          experience?.groupByCode(widget.groupId);
      if (experienceGroup == null && fallbackGroup == null) {
        throw AppException('Unknown feature group: ${widget.groupId}');
      }

      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getString('selectedRole');
      if (roleId == null || roleId.isEmpty) {
        throw AppException('No selected role found');
      }

      final response = await ApiClient().get('/role/$roleId/workcenter');
      if (response.statusCode != 200) {
        throw AppException('Failed to load role workcenters: ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final all = data
          .whereType<Map>()
          .map((json) => Workcenter.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      final allowed = <Workcenter>[];

      if (experienceGroup != null) {
        for (final configured in experienceGroup.workcenters) {
          if (!configured.active) continue;
          final matched = _findConfiguredWorkcenter(all, configured.id);
          if (matched == null) continue;
          allowed.add(
            matched.copyWith(
              position: configured.displayOrder,
              displayLabel: configured.displayLabel.trim().isEmpty
                  ? null
                  : configured.displayLabel,
              cardDescription: configured.description.trim().isEmpty
                  ? null
                  : configured.description,
            ),
          );
        }
      } else if (fallbackGroup != null) {
        allowed.addAll(
          all.where(
            (wc) =>
                fallbackGroup.matches(wc.id, wc.description) &&
                !FeatureGroupRegistry.isGroupId(wc.id),
          ),
        );
      }
      allowed.sort((a, b) => a.position.compareTo(b.position));

      // Active approval workflows are first-class features. Surface each type
      // in the group that owns the business object.
      try {
        final workflows = await _approvalWorkflowService.getActiveWorkflows();
        var nextPosition = allowed.isEmpty
            ? 900
            : allowed.map((item) => item.position).reduce((a, b) => a > b ? a : b) + 1;
        final activeGroupId = experienceGroup?.code ?? fallbackGroup?.id ?? canonicalGroupId;
        for (final workflow in workflows) {
          final type = FeatureGroupRegistry.normalize(workflow.approvalType);
          if (FeatureGroupRegistry.normalize(FeatureGroupRegistry.approvalGroup(type)) !=
              FeatureGroupRegistry.normalize(activeGroupId)) {
            continue;
          }
          if (allowed.any((item) =>
              FeatureGroupRegistry.normalize(item.id) == 'APPROVAL_$type')) {
            continue;
          }
          final label = FeatureGroupRegistry.approvalLabel(type);
          allowed.add(Workcenter(
            id: 'approval-$type',
            description: '$label Approvals',
            defaultFunction: 'APPROVALS',
            path: AppRoutes.approvals,
            position: nextPosition++,
            routeKey: 'APPROVAL_$type',
            routePath:
                '${AppRoutes.approvals}?type=${Uri.encodeQueryComponent(type)}&title=${Uri.encodeQueryComponent('$label Approvals')}',
            iconKey: 'APPROVAL',
            cardDescription: 'Review and process $label approval requests assigned to your role.',
          ));
        }
      } catch (_) {
        // Role workcenters remain usable when workflow discovery is unavailable.
      }

      if (!mounted) return;
      setState(() {
        _experienceGroup = experienceGroup;
        _groupTitle = experienceGroup?.title ?? fallbackGroup?.title ?? 'Workcenter';
        _groupDescription = experienceGroup?.description.trim().isNotEmpty == true
            ? experienceGroup!.description
            : fallbackGroup?.description ?? 'Open a feature to continue.';
        _children = allowed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Workcenter? _findConfiguredWorkcenter(
    List<Workcenter> workcenters,
    String configuredId,
  ) {
    final target = FeatureGroupRegistry.normalize(configuredId);
    for (final workcenter in workcenters) {
      final candidates = <String>{
        FeatureGroupRegistry.normalize(workcenter.id),
        FeatureGroupRegistry.normalize(workcenter.routeKey),
        FeatureGroupRegistry.normalize(workcenter.defaultFunction),
      };
      if (candidates.contains(target)) return workcenter;
    }
    return null;
  }

  void _openWorkcenter(Workcenter wc) {
    _moduleUsageService.trackUsage(
      moduleCode: wc.id,
      moduleName: wc.presentationTitle,
      modulePath: wc.routePath,
      workcenterId: wc.id,
    );

    if (FeatureGroupRegistry.normalize(wc.id).startsWith('APPROVAL_') &&
        wc.routePath != null) {
      context.push(wc.routePath!);
      return;
    }

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
      SnackBar(content: Text('${wc.presentationTitle} feature coming soon')),
    );
  }

  String? _routeForCurrentGroup(Workcenter workcenter) {
    final group = FeatureGroupRegistry.normalize(
      _experienceGroup?.code ?? FeatureGroupRegistry.canonicalGroupId(widget.groupId),
    );
    final identity = [
      workcenter.id,
      workcenter.routeKey,
      workcenter.description,
      workcenter.routePath ?? '',
    ].map(FeatureGroupRegistry.normalize).join('_');

    if (group == FeatureGroupRegistry.normalize('funeral-operations') ||
        group == FeatureGroupRegistry.normalize('funeral-management')) {
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

    if (group == FeatureGroupRegistry.normalize('membership-cover') ||
        group == FeatureGroupRegistry.normalize('membership-management')) {
      if (identity.contains('CLAIM')) return AppRoutes.membershipClaims;
      if (identity.contains('PLAN')) return AppRoutes.membershipPlans;
      if (identity.contains('GROUP') || identity.contains('SOCIET')) {
        return AppRoutes.groupSocieties;
      }

      final memberIdentities = <String>{
        FeatureGroupRegistry.normalize(workcenter.id),
        FeatureGroupRegistry.normalize(workcenter.routeKey),
        FeatureGroupRegistry.normalize(workcenter.description),
      };
      if (memberIdentities.contains('MEMBER') ||
          memberIdentities.contains('MEMBERS')) {
        return '/partners/MEMBER';
      }
      if (identity.contains('MEMBERSHIP')) return AppRoutes.memberships;
    }


    if (group == FeatureGroupRegistry.normalize('people-workplace') ||
        group == FeatureGroupRegistry.normalize('partner-management')) {
      if (identity.contains('LEAVE')) return AppRoutes.employeeRequests;
      if (identity.contains('EMPLOY')) return AppRoutes.employment;
    }

    if (group == FeatureGroupRegistry.normalize('clients-relationships')) {
      if (identity.contains('CLIENT') || identity.contains('PARTNER')) {
        return '/partners/CLIENT';
      }
    }

    if (group == FeatureGroupRegistry.normalize('sales-customers') ||
        group == FeatureGroupRegistry.normalize('sales-management')) {
      if (identity.contains('CUSTOMER') || identity.contains('CLIENT')) {
        return '/partners/CUSTOMER';
      }
      if (identity.contains('QUOT')) return AppRoutes.inventoryQuotations;
      if (identity.contains('SALES') && identity.contains('ORDER')) {
        return AppRoutes.inventorySalesOrders;
      }
    }

    if (group == FeatureGroupRegistry.normalize('procurement-suppliers') ||
        group == FeatureGroupRegistry.normalize('procurement-management')) {
      if (identity.contains('SUPPLIER') && !identity.contains('INVOICE')) {
        return '/partners/SUPPLIER';
      }
      if (identity.contains('PURCHASE') && identity.contains('ORDER')) {
        return AppRoutes.inventoryPurchaseOrders;
      }
      if (identity.contains('GOODS') && identity.contains('RECEIPT')) {
        return AppRoutes.inventoryGoodsReceipts;
      }
    }

    if (group == FeatureGroupRegistry.normalize('legal-practice')) {
      if (identity.contains('CASE') || identity.contains('MATTER')) {
        return AppRoutes.cases;
      }
    }

    if (group == FeatureGroupRegistry.normalize('products-inventory') ||
        group == FeatureGroupRegistry.normalize('inventory')) {
      if (identity.contains('ASSET')) return AppRoutes.assetRegister;
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

  IconData _iconFor(String id, [String? iconKey]) {
    final lower = '${iconKey ?? ''} $id'.toLowerCase();
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
    if (lower.contains('asset')) return Icons.precision_manufacturing_outlined;
    if (lower.contains('employee') || lower.contains('employment')) return Icons.badge_outlined;
    if (lower.contains('setting') || lower.contains('config')) return Icons.settings_outlined;
    if (lower.contains('api') || lower.contains('queue')) return Icons.integration_instructions_outlined;
    return Icons.apps_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final title = _groupTitle;
    final description = _groupDescription;
    final filtered = _children.where((item) {
      if (_query.trim().isEmpty) return true;
      final query = _query.toLowerCase();
      return item.presentationTitle.toLowerCase().contains(query) ||
          (item.cardDescription ?? WorkcenterCardDescriptions.forWorkcenter(
            item.id,
            item.description,
          )).toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: MawaDesign.page,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadChildren,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = MawaDesign.responsivePagePadding(
                      constraints.maxWidth,
                    );
                    return SingleChildScrollView(
                      padding: padding,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MawaPageHeader(
                              title: title,
                              description: description,
                              eyebrow: _groupEyebrow(filtered.length),
                            ),
                            const SizedBox(height: 22),
                            _buildToolbar(),
                            const SizedBox(height: 18),
                            if (_children.isEmpty)
                              const MawaEmptyState(
                                icon: Icons.lock_outline_rounded,
                                title: 'No features available',
                                description:
                                    'No workcenters in this group are assigned to your current role.',
                              )
                            else if (filtered.isEmpty)
                              const MawaEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No matching features',
                                description:
                                    'Try a different feature name or process description.',
                              )
                            else if (_gridView)
                              _buildGrid(filtered)
                            else
                              _buildList(filtered),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _groupEyebrow(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MawaDesign.redSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count ${count == 1 ? 'feature' : 'features'} available',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MawaDesign.redDark,
            ),
      ),
    );
  }

  Widget _buildToolbar() {
    return MawaSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search features in this workcenter',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: MawaDesign.surfaceMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.grid_view_rounded, size: 18),
                tooltip: 'Grid view',
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.view_list_rounded, size: 19),
                tooltip: 'List view',
              ),
            ],
            selected: {_gridView},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _gridView = selection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              side: const WidgetStatePropertyAll(
                BorderSide(color: MawaDesign.borderStrong),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Workcenter> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 224,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _workcenterCard(
        items[index],
        index: index,
      ),
    );
  }

  Widget _buildList(List<Workcenter> items) {
    return MawaSurface(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _workcenterListTile(items[index], index: index),
            if (index < items.length - 1)
              const Divider(indent: 64, endIndent: 12),
          ],
        ],
      ),
    );
  }

  Widget _workcenterCard(Workcenter workcenter, {required int index}) {
    final theme = Theme.of(context);
    final colour = MawaDesign.iconTint(index);
    final description = workcenter.cardDescription ??
        WorkcenterCardDescriptions.forWorkcenter(
          workcenter.id,
          workcenter.description,
        );

    return Card(
      child: InkWell(
        onTap: () => _openWorkcenter(workcenter),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MawaIconBadge(
                    icon: _iconFor(workcenter.id, workcenter.iconKey),
                    color: colour,
                    size: 50,
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: MawaDesign.surfaceMuted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: MawaDesign.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                workcenter.presentationTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: MawaDesign.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open  →',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: MawaDesign.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workcenterListTile(Workcenter workcenter, {required int index}) {
    final theme = Theme.of(context);
    final colour = MawaDesign.iconTint(index);
    return InkWell(
      onTap: () => _openWorkcenter(workcenter),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            MawaIconBadge(
              icon: _iconFor(workcenter.id, workcenter.iconKey),
              color: colour,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workcenter.presentationTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    workcenter.cardDescription ??
                        WorkcenterCardDescriptions.forWorkcenter(
                          workcenter.id,
                          workcenter.description,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MawaDesign.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Open',
              style: theme.textTheme.labelMedium?.copyWith(
                color: MawaDesign.red,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: MawaDesign.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: MawaEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load this workcenter',
            description: _error ?? 'An unexpected error occurred.',
            action: ElevatedButton.icon(
              onPressed: _loadChildren,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
