import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../data/funeral_api.dart';
import '../../data/models/pickup_request_dto.dart';
import '../../data/models/complete_pickup_request_dto.dart';
import '../../data/models/arrive_pickup_request_dto.dart';
import '../../../../core/api_client.dart';
import '../../data/models/funeral_enums.dart';
import '../../../partners/models/partner.dart';
import '../widgets/funeral_status_chip.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PickupRequestsPage extends StatefulWidget {
  const PickupRequestsPage({super.key});

  @override
  State<PickupRequestsPage> createState() => _PickupRequestsPageState();
}

class _PickupRequestsPageState extends State<PickupRequestsPage> {
  final _api = FuneralApi();
  final _imagePicker = ImagePicker();
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
        SnackBar(content: Text(friendlyErrorMessage('Error loading employees: $e'))),
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
        SnackBar(content: Text(friendlyErrorMessage('Error loading pickup requests: $e'))),
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
            SnackBar(content: Text(friendlyErrorMessage('Error assigning pickup: $e'))),
          );
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _storageRows(String path, [Map<String, dynamic>? query]) async {
    final response = await ApiClient().get(path, queryParameters: query);
    if (response.statusCode != 200) throw AppException(response.body);
    final decoded = jsonDecode(response.body);
    return decoded is List
        ? decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _uploadInjuryPhotos(String pickupId, List<XFile> photos) async {
    for (final photo in photos) {
      final bytes = await photo.readAsBytes();
      final extension = photo.name.contains('.') ? photo.name.split('.').last : 'jpg';
      final response = await ApiClient().post('/v2/attachment', body: {
        'objectId': pickupId,
        'documentType': 'PICKUP-INJURY-PHOTO',
        'extension': extension,
        'file': base64Encode(bytes),
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Could not upload injury photo ${photo.name}: ${response.body}');
      }
    }
  }

  Future<void> _recordArrival(PickupRequestDto request) async {
    bool injured = false;
    final injuryDetails = TextEditingController();
    final photos = <XFile>[];

    final assessment = await showDialog<_ArrivalAssessment>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit = !injured ||
              (injuryDetails.text.trim().isNotEmpty && photos.isNotEmpty);
          return AlertDialog(
            title: const Text('Driver Arrival Assessment'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confirm arrival at ${request.pickupLocation} and assess the deceased.'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Injuries identified at pickup'),
                      subtitle: const Text('Describe and photograph injuries before recording arrival.'),
                      value: injured,
                      onChanged: (value) => setDialogState(() {
                        injured = value;
                        if (!value) {
                          injuryDetails.clear();
                          photos.clear();
                        }
                      }),
                    ),
                    if (injured) ...[
                      TextField(
                        controller: injuryDetails,
                        maxLines: 3,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Injury Details',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _imagePicker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 85,
                              );
                              if (photo != null) setDialogState(() => photos.add(photo));
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Take Photo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (photo != null) setDialogState(() => photos.add(photo));
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Photo Library'),
                          ),
                        ],
                      ),
                      if (photos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'At least one injury photo is required.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ...photos.asMap().entries.map(
                            (entry) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.image_outlined),
                              title: Text(entry.value.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setDialogState(() => photos.removeAt(entry.key)),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(
                          context,
                          _ArrivalAssessment(
                            corpseInjured: injured,
                            injuryDetails: injured ? injuryDetails.text.trim() : null,
                            photos: List<XFile>.from(photos),
                          ),
                        )
                    : null,
                child: const Text('Record Arrival'),
              ),
            ],
          );
        },
      ),
    );
    injuryDetails.dispose();

    if (assessment == null || request.id == null) return;
    try {
      if (assessment.corpseInjured) {
        await _uploadInjuryPhotos(request.id!, assessment.photos);
      }
      await _api.arriveAtPickupLocation(
        request.id!,
        ArrivePickupRequestDto(
          arrivalTime: DateTime.now(),
          corpseInjured: assessment.corpseInjured,
          injuryDetails: assessment.injuryDetails,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver arrival and injury assessment recorded.')),
      );
      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error recording arrival: $e'))),
        );
      }
    }
  }

  Future<void> _completePickup(PickupRequestDto request) async {
    List<Map<String, dynamic>> warehouses;
    try {
      warehouses = await _storageRows('/v2/storage-configuration/warehouses');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Could not load storage configuration: $e'))),
      );
      return;
    }
    if (!mounted) return;

    String? warehouseId;
    String? locationId;
    String? binId;
    List<Map<String, dynamic>> locations = [];
    List<Map<String, dynamic>> bins = [];
    bool loadingChildren = false;

    final selection = await showDialog<CompletePickupRequestDto>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete Pickup'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select where ${request.deceasedName} will be stored.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: warehouseId,
                  decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
                  items: warehouses.map((row) => DropdownMenuItem(
                    value: row['id']?.toString(),
                    child: Text('${row['code']} - ${row['name']}'),
                  )).toList(),
                  onChanged: loadingChildren ? null : (value) async {
                    setDialogState(() {
                      warehouseId = value;
                      locationId = null;
                      binId = null;
                      locations = [];
                      bins = [];
                      loadingChildren = true;
                    });
                    try {
                      final rows = await _storageRows('/v2/storage-configuration/locations', {'warehouseId': value});
                      setDialogState(() => locations = rows);
                    } finally {
                      setDialogState(() => loadingChildren = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: locationId,
                  decoration: const InputDecoration(labelText: 'Storage Location', border: OutlineInputBorder()),
                  items: locations.map((row) => DropdownMenuItem(
                    value: row['id']?.toString(),
                    child: Text('${row['code']} - ${row['name']}'),
                  )).toList(),
                  onChanged: loadingChildren ? null : (value) async {
                    setDialogState(() {
                      locationId = value;
                      binId = null;
                      bins = [];
                      loadingChildren = true;
                    });
                    try {
                      final rows = await _storageRows('/v2/storage-configuration/bins', {'locationId': value});
                      setDialogState(() => bins = rows);
                    } finally {
                      setDialogState(() => loadingChildren = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: binId,
                  decoration: const InputDecoration(labelText: 'Storage Bin', border: OutlineInputBorder()),
                  items: bins.map((row) => DropdownMenuItem(
                    value: row['id']?.toString(),
                    child: Text('${row['code']} - ${row['name']}'),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => binId = value),
                ),
                if (loadingChildren) const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: warehouseId == null || locationId == null || binId == null
                  ? null
                  : () => Navigator.pop(context, CompletePickupRequestDto(
                        completionTime: DateTime.now(),
                        warehouseId: warehouseId!,
                        storageLocationId: locationId!,
                        storageBinId: binId!,
                      )),
              child: const Text('Complete Pickup'),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return;
    try {
      await _api.completePickup(request.id!, selection);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup completed and checked into the selected storage bin.')),
      );
      _loadRequests();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Error completing pickup: $e'))),
      );
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
                            if (request.status == PickupStatus.ARRIVED ||
                                request.status == PickupStatus.COMPLETED)
                              Text(
                                request.corpseInjured
                                    ? 'Arrival assessment: injuries identified${request.injuryDetails == null || request.injuryDetails!.isEmpty ? '' : ': ${request.injuryDetails}'}'
                                    : 'Arrival assessment: no injuries identified',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                                  ElevatedButton.icon(
                                    onPressed: () => _recordArrival(request),
                                    icon: const Icon(Icons.location_on_outlined),
                                    label: const Text('Arrived at Pickup'),
                                  ),
                                if (request.status == PickupStatus.ARRIVED)
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

class _ArrivalAssessment {
  final bool corpseInjured;
  final String? injuryDetails;
  final List<XFile> photos;

  const _ArrivalAssessment({
    required this.corpseInjured,
    required this.injuryDetails,
    required this.photos,
  });
}
