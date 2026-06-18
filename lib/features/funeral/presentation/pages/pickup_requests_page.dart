import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/pickup_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../widgets/funeral_status_chip.dart';

class PickupRequestsPage extends StatefulWidget {
  const PickupRequestsPage({super.key});

  @override
  State<PickupRequestsPage> createState() => _PickupRequestsPageState();
}

class _PickupRequestsPageState extends State<PickupRequestsPage> {
  final _api = FuneralApi();
  List<PickupRequestDto> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _api.getPickupRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pickup requests: $e')),
        );
      }
    }
  }

  Future<void> _assignPickup(PickupRequestDto request) async {
    final staffIdController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Staff'),
        content: TextField(
          controller: staffIdController,
          decoration: const InputDecoration(
            labelText: 'Staff ID',
            hintText: 'Enter staff/driver ID',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, staffIdController.text),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _api.assignPickup(request.id!, result);
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
                        onPressed: () => context.push('/funeral/pickups/new').then((_) => _loadRequests()),
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
                              children: [
                                Text(
                                  request.deceasedName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                FuneralStatusChip(status: request.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Location: ${request.pickupLocation}'),
                            Text('Contact: ${request.contactPerson} (${request.contactNumber})'),
                            if (request.staffId != null) Text('Assigned to: ${request.staffId}'),
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
        onPressed: () => context.push('/funeral/pickups/new').then((_) => _loadRequests()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
