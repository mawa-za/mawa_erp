import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class StorageConfigurationScreen extends StatefulWidget {
  const StorageConfigurationScreen({super.key});

  @override
  State<StorageConfigurationScreen> createState() => _StorageConfigurationScreenState();
}

class _StorageConfigurationScreenState extends State<StorageConfigurationScreen> {
  List<Map<String, dynamic>> warehouses = [];
  List<Map<String, dynamic>> locations = [];
  List<Map<String, dynamic>> bins = [];
  List<Map<String, dynamic>> locationTypes = [];
  String? warehouseId;
  String? locationId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<List<Map<String, dynamic>>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final response = await ApiClient().get(path, queryParameters: query);
    if (response.statusCode != 200) throw AppException(response.body);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _initialise() async {
    setState(() => loading = true);
    try {
      await _loadLocationTypes();
      warehouses = await _get(
        '/v2/storage-configuration/warehouses',
        {'activeOnly': false},
      );
      if (warehouseId != null &&
          !warehouses.any((row) => row['id'].toString() == warehouseId)) {
        warehouseId = null;
      }
      await _loadLocations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Could not load storage configuration: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadLocationTypes() async {
    locationTypes = await _get(
      '/v2/storage-configuration/location-types',
      {'activeOnly': false},
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadWarehouses() async {
    warehouses = await _get(
      '/v2/storage-configuration/warehouses',
      {'activeOnly': false},
    );
    if (warehouseId != null &&
        !warehouses.any((row) => row['id'].toString() == warehouseId)) {
      warehouseId = null;
    }
    await _loadLocations();
  }

  Future<void> _loadLocations() async {
    locations = warehouseId == null
        ? []
        : await _get(
            '/v2/storage-configuration/locations',
            {'warehouseId': warehouseId, 'activeOnly': false},
          );
    if (locationId != null &&
        !locations.any((row) => row['id'].toString() == locationId)) {
      locationId = null;
    }
    await _loadBins();
    if (mounted) setState(() {});
  }

  Future<void> _loadBins() async {
    bins = locationId == null
        ? []
        : await _get(
            '/v2/storage-configuration/bins',
            {'locationId': locationId, 'activeOnly': false},
          );
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>?> _editDialog(
    String title,
    Map<String, dynamic>? current, {
    bool showCapacity = false,
    bool showStorageType = false,
  }) async {
    final code = TextEditingController(text: current?['code']?.toString() ?? '');
    final name = TextEditingController(text: current?['name']?.toString() ?? '');
    final description = TextEditingController(
      text: current?['description']?.toString() ?? '',
    );
    final capacity = TextEditingController(
      text: current?['capacity']?.toString() ?? '',
    );
    final currentType = current?['storage_type']?.toString();
    final selectableTypes = locationTypes
        .where(
          (row) =>
              _truth(row['active']) || row['code']?.toString() == currentType,
        )
        .toList();
    String? selectedStorageType;
    if (selectableTypes.any((row) => row['code']?.toString() == currentType)) {
      selectedStorageType = currentType;
    } else {
      for (final type in selectableTypes) {
        if (type['code']?.toString() == 'GENERAL_STORAGE') {
          selectedStorageType = 'GENERAL_STORAGE';
          break;
        }
      }
    }
    bool active = current == null || _truth(current['active']);
    final key = GlobalKey<FormState>();

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: Form(
              key: key,
              child: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: code,
                        decoration: const InputDecoration(labelText: 'Code'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      if (showStorageType)
                        DropdownButtonFormField<String>(
                          value: selectedStorageType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Storage Location Type',
                            helperText:
                                'Controls stock availability, putaway, picking and reservation behaviour.',
                          ),
                          items: selectableTypes
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type['code']?.toString(),
                                  child: Text(
                                    '${type['name']} (${type['code']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => selectedStorageType = value,
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Storage type is required'
                              : null,
                        ),
                      if (showCapacity)
                        TextFormField(
                          controller: capacity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Capacity'),
                        ),
                      TextFormField(
                        controller: description,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: active,
                        onChanged: (value) => setDialogState(() => active = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  Navigator.pop(context, {
                    if (current?['id'] != null) 'id': current!['id'],
                    'code': code.text.trim().toUpperCase(),
                    'name': name.text.trim(),
                    'description': description.text.trim(),
                    'active': active,
                    if (showStorageType) 'storageType': selectedStorageType,
                    if (showCapacity && capacity.text.trim().isNotEmpty)
                      'capacity': int.tryParse(capacity.text.trim()),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      code.dispose();
      name.dispose();
      description.dispose();
      capacity.dispose();
    }
  }

  Future<Map<String, dynamic>?> _editLocationTypeDialog(
    Map<String, dynamic>? current,
  ) async {
    final code = TextEditingController(text: current?['code']?.toString() ?? '');
    final name = TextEditingController(text: current?['name']?.toString() ?? '');
    final purpose = TextEditingController(
      text: current?['purpose']?.toString() ?? '',
    );
    final displayOrder = TextEditingController(
      text: current?['display_order']?.toString() ?? '100',
    );
    final key = GlobalKey<FormState>();
    final systemManaged = _truth(current?['system_managed']);

    bool availableForSale = _truth(current?['available_for_sale']);
    bool availableForIssue = _truth(current?['available_for_issue']);
    bool allowPutaway = _truth(current?['allow_putaway']);
    bool allowPicking = _truth(current?['allow_picking']);
    bool allowReservation = _truth(current?['allow_reservation']);
    bool allowNegativeStock = _truth(current?['allow_negative_stock']);
    bool requiresBatch = _truth(current?['requires_batch']);
    bool requiresExpiryDate = _truth(current?['requires_expiry_date']);
    bool requiresSerialNumber = _truth(current?['requires_serial_number']);
    bool requiresQualityRelease = _truth(current?['requires_quality_release']);
    bool restrictedAccess = _truth(current?['restricted_access']);
    bool temporaryLocation = _truth(current?['temporary_location']);
    bool active = current == null || systemManaged || _truth(current?['active']);

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              current == null ? 'Add Storage Location Type' : 'Edit Storage Location Type',
            ),
            content: Form(
              key: key,
              child: SizedBox(
                width: 720,
                height: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (systemManaged)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This is a system-managed type. Its code and active state are immutable, but its behaviour flags may be configured.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: code,
                        enabled: current == null,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Code',
                          helperText: current == null
                              ? 'Use an immutable uppercase code, for example SPECIAL_STORAGE.'
                              : 'Existing type codes are immutable.',
                        ),
                        validator: (value) {
                          final normalized = value?.trim() ?? '';
                          if (normalized.isEmpty) return 'Code is required';
                          if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(normalized)) {
                            return 'Use letters, numbers and underscores only';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      TextFormField(
                        controller: purpose,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Purpose'),
                      ),
                      TextFormField(
                        controller: displayOrder,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Display Order'),
                        validator: (value) => int.tryParse(value?.trim() ?? '') == null
                            ? 'Enter a valid number'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Inventory Behaviour',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      _flagTile(
                        title: 'Available for sale',
                        value: availableForSale,
                        onChanged: (value) => setDialogState(
                          () => availableForSale = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Available for issue',
                        value: availableForIssue,
                        onChanged: (value) => setDialogState(
                          () => availableForIssue = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Allow putaway',
                        value: allowPutaway,
                        onChanged: (value) => setDialogState(
                          () => allowPutaway = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Allow picking',
                        value: allowPicking,
                        onChanged: (value) => setDialogState(
                          () => allowPicking = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Allow reservation',
                        value: allowReservation,
                        onChanged: (value) => setDialogState(
                          () => allowReservation = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Allow negative stock',
                        value: allowNegativeStock,
                        onChanged: (value) => setDialogState(
                          () => allowNegativeStock = value,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Control Requirements',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      _flagTile(
                        title: 'Requires batch',
                        value: requiresBatch,
                        onChanged: (value) => setDialogState(
                          () => requiresBatch = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Requires expiry date',
                        value: requiresExpiryDate,
                        onChanged: (value) => setDialogState(
                          () => requiresExpiryDate = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Requires serial number',
                        value: requiresSerialNumber,
                        onChanged: (value) => setDialogState(
                          () => requiresSerialNumber = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Requires quality release',
                        value: requiresQualityRelease,
                        onChanged: (value) => setDialogState(
                          () => requiresQualityRelease = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Restricted access',
                        value: restrictedAccess,
                        onChanged: (value) => setDialogState(
                          () => restrictedAccess = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Temporary location',
                        value: temporaryLocation,
                        onChanged: (value) => setDialogState(
                          () => temporaryLocation = value,
                        ),
                      ),
                      _flagTile(
                        title: 'Active',
                        subtitle: systemManaged
                            ? 'System-managed types must remain active.'
                            : null,
                        value: active,
                        onChanged: systemManaged
                            ? null
                            : (value) => setDialogState(() => active = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  Navigator.pop(context, {
                    'code': code.text.trim().toUpperCase(),
                    'name': name.text.trim(),
                    'purpose': purpose.text.trim(),
                    'availableForSale': availableForSale,
                    'availableForIssue': availableForIssue,
                    'allowPutaway': allowPutaway,
                    'allowPicking': allowPicking,
                    'allowReservation': allowReservation,
                    'allowNegativeStock': allowNegativeStock,
                    'requiresBatch': requiresBatch,
                    'requiresExpiryDate': requiresExpiryDate,
                    'requiresSerialNumber': requiresSerialNumber,
                    'requiresQualityRelease': requiresQualityRelease,
                    'restrictedAccess': restrictedAccess,
                    'temporaryLocation': temporaryLocation,
                    'active': systemManaged ? true : active,
                    'displayOrder': int.parse(displayOrder.text.trim()),
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      code.dispose();
      name.dispose();
      purpose.dispose();
      displayOrder.dispose();
    }
  }

  Widget _flagTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _save(String path, Map<String, dynamic> body) async {
    final response = await ApiClient().post(path, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException(response.body);
    }
  }

  Future<void> _maintainLocationType(Map<String, dynamic>? current) async {
    final body = await _editLocationTypeDialog(current);
    if (body == null) return;
    try {
      await _save('/v2/storage-configuration/location-types', body);
      await _loadLocationTypes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage location type saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Could not save storage location type: $e'))),
        );
      }
    }
  }

  Future<void> _showLocationTypes() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Storage Location Types'),
        content: SizedBox(
          width: 760,
          height: 560,
          child: ListView.separated(
            itemCount: locationTypes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final type = locationTypes[index];
              final capabilities = <String>[
                if (_truth(type['available_for_sale'])) 'Sale',
                if (_truth(type['available_for_issue'])) 'Issue',
                if (_truth(type['allow_putaway'])) 'Putaway',
                if (_truth(type['allow_picking'])) 'Picking',
                if (_truth(type['allow_reservation'])) 'Reservation',
                if (_truth(type['requires_batch'])) 'Batch',
                if (_truth(type['requires_expiry_date'])) 'Expiry',
                if (_truth(type['requires_serial_number'])) 'Serial',
                if (_truth(type['requires_quality_release'])) 'Quality release',
                if (_truth(type['temporary_location'])) 'Temporary',
                if (_truth(type['restricted_access'])) 'Restricted',
              ];
              final active = _truth(type['active']);
              final systemManaged = _truth(type['system_managed']);
              return ListTile(
                title: Text('${type['name']} (${type['code']})'),
                subtitle: Text(
                  '${type['purpose'] ?? ''}'
                  '${capabilities.isEmpty ? '' : '\n${capabilities.join(' • ')}'}'
                  '${active ? '' : '\nInactive'}',
                ),
                isThreeLine: capabilities.isNotEmpty || !active,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (systemManaged)
                      const Tooltip(
                        message: 'System code is immutable',
                        child: Icon(Icons.lock_outline),
                      ),
                    IconButton(
                      tooltip: 'Edit type',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _maintainLocationType(type).then((_) {
                          if (mounted) _showLocationTypes();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _maintainLocationType(null).then((_) {
                if (mounted) _showLocationTypes();
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Type'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _truth(dynamic value) {
    if (value == true || value == 1) return true;
    final text = value?.toString().trim().toLowerCase();
    return text == '1' || text == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse & Storage Configuration'),
        actions: [
          TextButton.icon(
            onPressed: locationTypes.isEmpty ? null : _showLocationTypes,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Location Types'),
          ),
          IconButton(onPressed: _initialise, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _column(
                      'Warehouses',
                      warehouses,
                      warehouseId,
                      (id) async {
                        warehouseId = id;
                        locationId = null;
                        await _loadLocations();
                      },
                      () async {
                        final body = await _editDialog('Warehouse', null);
                        if (body != null) {
                          await _save('/v2/storage-configuration/warehouses', body);
                          await _loadWarehouses();
                        }
                      },
                      (row) async {
                        final body = await _editDialog('Warehouse', row);
                        if (body != null) {
                          await _save('/v2/storage-configuration/warehouses', body);
                          await _loadWarehouses();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _column(
                      'Storage Locations',
                      locations,
                      locationId,
                      (id) async {
                        locationId = id;
                        await _loadBins();
                      },
                      warehouseId == null
                          ? null
                          : () async {
                              final body = await _editDialog(
                                'Storage Location',
                                null,
                                showStorageType: true,
                              );
                              if (body != null) {
                                body['warehouseId'] = warehouseId;
                                await _save(
                                  '/v2/storage-configuration/locations',
                                  body,
                                );
                                await _loadLocations();
                              }
                            },
                      (row) async {
                        final body = await _editDialog(
                          'Storage Location',
                          row,
                          showStorageType: true,
                        );
                        if (body != null) {
                          body['warehouseId'] = warehouseId;
                          await _save(
                            '/v2/storage-configuration/locations',
                            body,
                          );
                          await _loadLocations();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _column(
                      'Storage Bins',
                      bins,
                      null,
                      (_) async {},
                      locationId == null
                          ? null
                          : () async {
                              final body = await _editDialog(
                                'Storage Bin',
                                null,
                                showCapacity: true,
                              );
                              if (body != null) {
                                body['locationId'] = locationId;
                                await _save(
                                  '/v2/storage-configuration/bins',
                                  body,
                                );
                                await _loadBins();
                              }
                            },
                      (row) async {
                        final body = await _editDialog(
                          'Storage Bin',
                          row,
                          showCapacity: true,
                        );
                        if (body != null) {
                          body['locationId'] = locationId;
                          await _save(
                            '/v2/storage-configuration/bins',
                            body,
                          );
                          await _loadBins();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _column(
    String title,
    List<Map<String, dynamic>> rows,
    String? selected,
    Future<void> Function(String?) onSelect,
    VoidCallback? onAdd,
    Future<void> Function(Map<String, dynamic>) onEdit,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: onAdd, icon: const Icon(Icons.add)),
              ],
            ),
            const Divider(),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No records configured.'),
              ),
            ...rows.map((row) {
              final isActive = _truth(row['active']);
              final typeName = row['storage_type_name']?.toString();
              final typeCode = row['storage_type']?.toString();
              return ListTile(
                selected: selected == row['id']?.toString(),
                title: Text('${row['code']} - ${row['name']}'),
                subtitle: Text(
                  [
                    if (typeName != null && typeName.isNotEmpty)
                      '$typeName${typeCode == null ? '' : ' ($typeCode)'}',
                    isActive ? 'Active' : 'Inactive',
                  ].join(' • '),
                ),
                onTap: () => onSelect(row['id']?.toString()),
                trailing: IconButton(
                  onPressed: () => onEdit(row),
                  icon: const Icon(Icons.edit_outlined),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
