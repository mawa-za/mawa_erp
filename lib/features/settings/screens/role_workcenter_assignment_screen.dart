import 'package:flutter/material.dart';
import '../../../core/routing/feature_group_registry.dart';
import '../../home/models/workcenter.dart';
import '../models/role.dart';
import '../services/role_service.dart';

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
  Map<String, int> _positions = {};
  String? _error;

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
          _assignedWorkcenterIds = assigned.map((w) => w.id).toSet();
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
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }


  List<Workcenter> _displayWorkcenters() {
    final List<Workcenter> display = [];
    final Set<String> groupedChildIds = {};

    for (final group in FeatureGroupRegistry.groups) {
      final children = _allWorkcenters.where((wc) => group.matches(wc.id) && !FeatureGroupRegistry.isGroupId(wc.id)).toList();
      if (children.isEmpty) continue;
      groupedChildIds.addAll(children.map((wc) => wc.id));
      final firstPosition = children.map((wc) => _positions[wc.id] ?? wc.position).fold<int>(
        _positions[children.first.id] ?? children.first.position,
        (previous, current) => current < previous ? current : previous,
      );
      display.add(Workcenter(
        id: group.id,
        description: group.title,
        defaultFunction: '',
        path: group.routePath,
        position: firstPosition,
        routeKey: group.id,
        routePath: group.routePath,
        isFeatureGroup: true,
        childWorkcenterIds: children.map((wc) => wc.id).toList(),
      ));
      display.addAll(children.map((wc) => Workcenter(
            id: wc.id,
            description: '   ${wc.description}',
            defaultFunction: wc.defaultFunction,
            path: wc.path,
            position: wc.position,
            routeKey: wc.routeKey,
            routePath: wc.routePath,
            iconKey: wc.iconKey,
            childWorkcenterIds: wc.childWorkcenterIds,
          )));
    }

    display.addAll(_allWorkcenters.where((wc) => !groupedChildIds.contains(wc.id) && !FeatureGroupRegistry.isGroupId(wc.id)));
    return display;
  }

  bool _isGroupSelected(Workcenter group) {
    if (!group.isFeatureGroup || group.childWorkcenterIds.isEmpty) return false;
    return group.childWorkcenterIds.any(_assignedWorkcenterIds.contains);
  }

  void _toggleGroup(Workcenter group, bool selected) {
    for (final childId in group.childWorkcenterIds) {
      if (selected) {
        _assignedWorkcenterIds.add(childId);
      } else {
        _assignedWorkcenterIds.remove(childId);
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

      await _roleService.assignWorkcentersToRole(widget.role.id, assignments);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workcenters assigned successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Assign: ${widget.role.description}'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _saveAssignments,
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Builder(builder: (context) {
                  final displayWorkcenters = _displayWorkcenters();
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayWorkcenters.length,
                    itemBuilder: (context, index) {
                      final wc = displayWorkcenters[index];
                      final isSelected = wc.isFeatureGroup ? _isGroupSelected(wc) : _assignedWorkcenterIds.contains(wc.id);
                      return Card(
                        elevation: 0,
                        color: wc.isFeatureGroup ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.18) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: wc.isFeatureGroup ? Theme.of(context).colorScheme.primary.withOpacity(0.25) : Colors.grey.shade200),
                        ),
                        margin: EdgeInsets.only(bottom: wc.isFeatureGroup ? 10 : 6, left: wc.isFeatureGroup ? 0 : 20),
                        child: CheckboxListTile(
                          value: isSelected,
                          title: Text(wc.description, style: TextStyle(fontWeight: wc.isFeatureGroup ? FontWeight.w800 : FontWeight.w600)),
                          subtitle: Text(wc.isFeatureGroup ? 'Feature group: selects available child features' : 'ID: ${wc.id}'),
                          secondary: !wc.isFeatureGroup && isSelected
                            ? SizedBox(
                                width: 60,
                                child: TextFormField(
                                  initialValue: _positions[wc.id]?.toString() ?? (index + 1).toString(),
                                  decoration: const InputDecoration(labelText: 'Pos', isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final pos = int.tryParse(val) ?? 1;
                                    _positions[wc.id] = pos;
                                  },
                                ),
                              )
                            : null,
                          onChanged: (val) {
                            setState(() {
                              if (wc.isFeatureGroup) {
                                _toggleGroup(wc, val == true);
                              } else if (val == true) {
                                _assignedWorkcenterIds.add(wc.id);
                              } else {
                                _assignedWorkcenterIds.remove(wc.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                }),
    );
  }
}
