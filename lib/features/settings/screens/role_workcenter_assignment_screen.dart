import 'package:flutter/material.dart';
import '../../home/models/workcenter.dart';
import '../models/role.dart';
import '../services/role_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';
import 'package:mawa_erp/core/routing/feature_group_registry.dart';

class RoleWorkcenterAssignmentScreen extends StatefulWidget {
  final Role role;
  const RoleWorkcenterAssignmentScreen({super.key, required this.role});

  @override
  State<RoleWorkcenterAssignmentScreen> createState() => _RoleWorkcenterAssignmentScreenState();
}

class _RoleWorkcenterAssignmentScreenState extends State<RoleWorkcenterAssignmentScreen> {
  final RoleService _roleService = RoleService();
  bool _isLoading = true;
  bool _isSaving = false;
  List<Workcenter> _allWorkcenters = [];
  Set<String> _assignedWorkcenterIds = {};
  Set<String> _originalAssignedWorkcenterIds = {};
  Map<String, int> _positions = {};
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final all = await _roleService.getAllWorkcenters();
      final assigned = await _roleService.getRoleWorkcenters(widget.role.id);
      
      if (mounted) {
        setState(() {
          _allWorkcenters = all;
          _originalAssignedWorkcenterIds = assigned.map((w) => w.id).toSet();
          _assignedWorkcenterIds = assigned
              .where((workcenter) =>
                  !FeatureGroupRegistry.isGroupId(workcenter.id))
              .map((workcenter) => workcenter.id)
              .toSet();
          _positions = {for (var w in assigned) w.id: w.position};
          // Initialize positions for unassigned ones to their current index or something
          for (var i = 0; i < _allWorkcenters.length; i++) {
            if (!_positions.containsKey(_allWorkcenters[i].id)) {
              _positions[_allWorkcenters[i].id] = i + 1;
            }
          }
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

  Future<void> _saveAssignments() async {
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> assignments = _allWorkcenters
          .where((wc) => _assignedWorkcenterIds.contains(wc.id))
          .map((wc) => {
                'role': widget.role.id,
                'workcenter': wc.id,
                'position': _positions[wc.id] ?? 1,
              })
          .toList();

      final removed = _originalAssignedWorkcenterIds
          .difference(_assignedWorkcenterIds)
          .toList();
      for (final workcenterId in removed) {
        await _roleService.removeWorkcenterFromRole(widget.role.id, workcenterId);
      }

      await _roleService.assignWorkcentersToRole(widget.role.id, assignments);
      _originalAssignedWorkcenterIds = Set<String>.from(_assignedWorkcenterIds);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workcenters assigned successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Workcenter> get _visibleWorkcenters {
    final query = _searchQuery.trim().toLowerCase();
    final assignable = _allWorkcenters
        .where((workcenter) => !FeatureGroupRegistry.isGroupId(workcenter.id));
    if (query.isEmpty) return assignable.toList();
    return assignable.where((workcenter) => [
      workcenter.id,
      workcenter.description,
      FeatureGroupRegistry.configurationGroupForWorkcenter(
            workcenter.id,
            workcenter.description,
          )?.title ?? 'General & Navigation',
      workcenter.routeKey,
      workcenter.routePath ?? '',
    ].join(' ').toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final workcenters = _visibleWorkcenters;
    final grouped = <String, List<Workcenter>>{};
    for (final workcenter in workcenters) {
      final group = FeatureGroupRegistry.configurationGroupForWorkcenter(
        workcenter.id,
        workcenter.description,
      );
      grouped.putIfAbsent(group?.title ?? 'General & Navigation', () => []).add(workcenter);
    }
    final groupNames = grouped.keys.toList()..sort();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Assign: ${widget.role.description}'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: widget.role.accessAllWorkcentres ? null : _saveAssignments,
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: widget.role.accessAllWorkcentres
          ? Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.all_inclusive_rounded, size: 56),
                      SizedBox(height: 16),
                      Text('All workcentres are granted automatically', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 8),
                      Text('This protected role automatically includes current and future workcentres. Individual assignments cannot be changed.'),
                    ],
                  ),
                ),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search workcentres',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupNames.length,
                  itemBuilder: (context, index) {
                    final groupName = groupNames[index];
                    final children = grouped[groupName]!..sort(
                      (left, right) => left.description.compareTo(right.description),
                    );
                    final selectedCount = children
                        .where((item) => _assignedWorkcenterIds.contains(item.id))
                        .length;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        initiallyExpanded: _searchQuery.trim().isNotEmpty || selectedCount > 0,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$selectedCount of ${children.length} workcentres selected'),
                        children: children.map((wc) {
                          final isSelected = _assignedWorkcenterIds.contains(wc.id);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(wc.description),
                            subtitle: Text('ID: ${wc.id}'),
                            secondary: isSelected
                                ? SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      initialValue: _positions[wc.id]?.toString() ?? '1',
                                      decoration: const InputDecoration(labelText: 'Pos', isDense: true),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) => _positions[wc.id] = int.tryParse(value) ?? 1,
                                    ),
                                  )
                                : null,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _assignedWorkcenterIds.add(wc.id);
                              } else {
                                _assignedWorkcenterIds.remove(wc.id);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                    ),
                  ],
                ),
    );
  }
}
