import 'package:flutter/material.dart';
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allWorkcenters.length,
                  itemBuilder: (context, index) {
                    final wc = _allWorkcenters[index];
                    final isSelected = _assignedWorkcenterIds.contains(wc.id);
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: isSelected,
                        title: Text(wc.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('ID: ${wc.id}'),
                        secondary: isSelected 
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
                            if (val == true) {
                              _assignedWorkcenterIds.add(wc.id);
                            } else {
                              _assignedWorkcenterIds.remove(wc.id);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
