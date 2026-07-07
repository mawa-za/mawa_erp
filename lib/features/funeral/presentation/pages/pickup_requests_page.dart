import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/pickup_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../partners/models/partner.dart';
import '../widgets/funeral_status_chip.dart';

class PickupRequestsPage extends StatefulWidget {
  const PickupRequestsPage({super.key});

  @override
  State<PickupRequestsPage> createState() => _PickupRequestsPageState();
}

class _PickupRequestsPageState extends State<PickupRequestsPage> {
  final _api = FuneralApi();
  List<PickupRequestDto> _requests = [];
  List<Partner> _employees = [];
  bool _isLoading = true;
  bool _isLoadingEmployees = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await _api.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingEmployees = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employees: $e')),
      );
    }
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final requests = await _api.getPickupRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pickup requests: $e')),
      );
    }
  }

  String _employeeLabel(Partner employee) {
    final number = employee.number.isNotEmpty ? ' (${employee.number})' : '';
    return '${employee.fullName}$number';
  }

  String _assignedStaffLabel(String staffId) {
    final matches = _employees.where((employee) => employee.id == staffId);
    if (matches.isEmpty) return staffId;
    return _employeeLabel(matches.first);
  }

  Future<void> _assignPickup(PickupRequestDto request) async {
    if (_employees.isEmpty) {
      await _loadEmployees();
    }
    if (!mounted) return;

    String? selectedEmployeeId = request.staffId;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Staff'),
          content: SizedBox(
            width: 420,
            child: _isLoadingEmployees
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _employees.isEmpty
                    ? const Text('No employees found. Please maintain employee records first.')
                    : DropdownButtonFormField<String>(
                        value: selectedEmployeeId != null &&
                                _employees.any((employee) => employee.id == selectedEmployeeId)
                            ? selectedEmployeeId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Employee',
                          hintText: 'Select employee/driver',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: _employees
                            .map(
                              (employee) => DropdownMenuItem<String>(
                                value: employee.id,
                                child: Text(
                                  _employeeLabel(employee),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedEmployeeId = value),
                      ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedEmployeeId == null || selectedEmployeeId!.isEmpty
                  ? null
                  : () => Navigator.pop(context, selectedEmployeeId),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _api.assignPickup(request.id!, result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pickup assigned to ${_assignedStaffLabel(result)}')),
        );
        _loadRequests();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error assigning pickup: $e')),
          );
        }
      }
    }
  }

  Future<void> _completePickup(PickupRequestDto request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Pickup'),
        content: Text('Confirm completion of pickup for ${request.deceasedName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.completePickup(request.id!, DateTime.now());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup completed. Deceased checked into mortuary.')),
          );
        }
        _loadRequests();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing pickup: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Requests'),
        actions: [
          IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No pickup requests found'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/funeral/pickups/new').then((_) {
                          if (mounted) _loadRequests();
                        }),
                        child: const Text('Create New Request'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    request.deceasedName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FuneralStatusChip(status: request.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Location: ${request.pickupLocation}'),
                            Text('Contact: ${request.contactPerson} (${request.contactNumber})'),
                            if (request.staffId != null && request.staffId!.isNotEmpty)
                              Text('Assigned to: ${_assignedStaffLabel(request.staffId!)}'),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (request.status == PickupStatus.PENDING)
                                  TextButton(
                                    onPressed: () => _assignPickup(request),
                                    child: const Text('Assign Staff'),
                                  ),
                                if (request.status == PickupStatus.ASSIGNED)
                                  ElevatedButton(
                                    onPressed: () => _completePickup(request),
                                    child: const Text('Complete Pickup'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/funeral/pickups/new').then((_) {
          if (mounted) _loadRequests();
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}
