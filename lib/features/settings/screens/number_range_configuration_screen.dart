import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/number_range_configuration.dart';
import '../services/number_range_configuration_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class NumberRangeConfigurationScreen extends StatefulWidget {
  const NumberRangeConfigurationScreen({super.key});

  @override
  State<NumberRangeConfigurationScreen> createState() => _NumberRangeConfigurationScreenState();
}

class _NumberRangeConfigurationScreenState extends State<NumberRangeConfigurationScreen>
    with SingleTickerProviderStateMixin {
  final NumberRangeConfigurationService _service = NumberRangeConfigurationService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<NumberSequenceConfiguration> _sequences = const [];
  List<DocumentNumberRangeConfiguration> _documentRanges = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(_handleTabChange);
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        _service.getSequences(),
        _service.getDocumentRanges(),
      ]);
      if (!mounted) return;
      setState(() {
        _sequences = result[0] as List<NumberSequenceConfiguration>;
        _documentRanges = result[1] as List<DocumentNumberRangeConfiguration>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  List<NumberSequenceConfiguration> get _filteredSequences {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _sequences;
    return _sequences
        .where((item) => item.seqType.toLowerCase().contains(query) || item.description.toLowerCase().contains(query))
        .toList();
  }

  List<DocumentNumberRangeConfiguration> get _filteredDocumentRanges {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _documentRanges;
    return _documentRanges
        .where((item) => item.object.toLowerCase().contains(query) || (item.prefix ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        title: const Text('Number Range Configuration', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Operational Sequences', icon: Icon(Icons.format_list_numbered_rounded)),
            Tab(text: 'Document Ranges', icon: Icon(Icons.receipt_long_outlined)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () => _tabController.index == 0 ? _showSequenceEditor() : _showDocumentRangeEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Add Sequence' : 'Add Range'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSequenceTab(),
                          _buildDocumentRangeTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _tabController.index == 0 ? 'Search sequence type or description' : 'Search object or prefix',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.close_rounded)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          filled: true,
          fillColor: const Color(0xfff7f8fa),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceTab() {
    final active = _sequences.where((item) => item.active).length;
    final warning = _sequences.where((item) => item.exhausted || item.lowRange).length;
    final items = _filteredSequences;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _summaryRow([
            _Summary('Configured', _sequences.length.toString(), Icons.numbers_rounded),
            _Summary('Active', active.toString(), Icons.check_circle_outline_rounded),
            _Summary('Need attention', warning.toString(), Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: 14),
          _infoBanner(
            'Operational sequences issue numbers for current modules and device range allocations. '
            'The next number can only move forward, and inactive or exhausted sequences stop new allocations.',
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _emptyState('No operational sequences match your search.')
          else
            ...items.map(_sequenceCard),
        ],
      ),
    );
  }

  Widget _sequenceCard(NumberSequenceConfiguration item) {
    final status = item.exhausted
        ? const _Status('EXHAUSTED', Colors.red)
        : !item.active
            ? const _Status('INACTIVE', Colors.grey)
            : item.lowRange
                ? const _Status('LOW RANGE', Colors.orange)
                : const _Status('ACTIVE', Colors.green);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: item.exhausted || item.lowRange ? Colors.orange.shade200 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.seqType, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(item.description, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _metric('Start', _number(item.startNo)),
                _metric('Next', _number(item.nextNo)),
                _metric('Next formatted', item.nextFormattedNumber ?? _number(item.nextNo)),
                _metric('Format', '${item.prefix ?? ''}${item.prefix?.isNotEmpty == true ? (item.separator ?? '') : ''}${item.paddingLength > 0 ? List.filled(item.paddingLength, '0').join() : '#'}'),
                _metric('End', _number(item.endNo)),
                _metric('Remaining', _number(item.remainingNumbers)),
                _metric('Device block', _number(item.defaultAllocationSize)),
                _metric('Warning at', _number(item.warningThreshold)),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showAllocations(item),
                  icon: const Icon(Icons.devices_other_rounded),
                  label: const Text('Allocations'),
                ),
                TextButton.icon(
                  onPressed: () => _showAudit('SEQUENCE', item.seqType),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Audit'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _showSequenceEditor(existing: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentRangeTab() {
    final active = _documentRanges.where((item) => item.active).length;
    final items = _filteredDocumentRanges;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _summaryRow([
            _Summary('Configured', _documentRanges.length.toString(), Icons.receipt_long_outlined),
            _Summary('Currently valid', active.toString(), Icons.event_available_outlined),
            _Summary('Expired/Future', (_documentRanges.length - active).toString(), Icons.event_busy_outlined),
          ]),
          const SizedBox(height: 14),
          _infoBanner(
            'Document ranges control numbering for the existing transaction generator, including invoices, quotations, '
            'purchase orders, products, deposits and other legacy document objects.',
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _emptyState('No document number ranges match your search.')
          else
            ...items.map(_documentRangeCard),
        ],
      ),
    );
  }

  Widget _documentRangeCard(DocumentNumberRangeConfiguration item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.object, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                _statusChip(item.active ? const _Status('VALID', Colors.green) : const _Status('NOT VALID', Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Prefix: ${item.prefix?.isNotEmpty == true ? item.prefix : 'None'}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _metric('Start', item.start),
                _metric('Current', item.current),
                _metric('End', item.end),
                _metric('Valid from', _date(item.validFrom)),
                _metric('Valid to', _date(item.validTo)),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showAudit('LEGACY_RANGE', item.object),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Audit'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _showDocumentRangeEditor(existing: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSequenceEditor({NumberSequenceConfiguration? existing}) async {
    final formKey = GlobalKey<FormState>();
    final type = TextEditingController(text: existing?.seqType ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final prefix = TextEditingController(text: existing?.prefix ?? '');
    final separator = TextEditingController(text: existing?.separator ?? '-');
    final padding = TextEditingController(text: (existing?.paddingLength ?? 0).toString());
    final start = TextEditingController(text: (existing?.startNo ?? 1).toString());
    final next = TextEditingController(text: (existing?.nextNo ?? 1).toString());
    final end = TextEditingController(text: (existing?.endNo ?? 9999999999).toString());
    final allocation = TextEditingController(text: (existing?.defaultAllocationSize ?? 1000).toString());
    final warning = TextEditingController(text: (existing?.warningThreshold ?? 1000).toString());
    var active = existing?.active ?? true;
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Operational Sequence' : 'Edit ${existing.seqType}'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: type,
                      enabled: existing == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Sequence Type', hintText: 'e.g. DELIVERY_NOTE'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Description'), validator: _required),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: prefix, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Prefix', hintText: 'e.g. EMP'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: separator, decoration: const InputDecoration(labelText: 'Separator', hintText: '-'))),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(padding, 'Minimum Digits')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                      child: Text('Preview: ${prefix.text.trim().toUpperCase()}${prefix.text.trim().isEmpty ? '' : separator.text}${(int.tryParse(padding.text) ?? 0) > 0 ? next.text.padLeft(int.tryParse(padding.text) ?? 0, '0') : next.text}'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(start, 'Start Number', enabled: existing == null)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(next, 'Next Number')),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(end, 'End Number')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(allocation, 'Default Device Block')),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(warning, 'Warning Threshold')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) => setDialogState(() => active = value),
                      title: const Text('Active'),
                      subtitle: const Text('Inactive sequences cannot issue online numbers or new device ranges.'),
                    ),
                    if (existing != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Text(
                          'Start and sequence type are locked. Increasing the next number skips unused values; decreasing it is blocked to prevent duplicates.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      final body = {
                        'seqType': type.text.trim().toUpperCase().replaceAll(' ', '_'),
                        'description': description.text.trim(),
                        'prefix': prefix.text.trim().isEmpty ? null : prefix.text.trim().toUpperCase(),
                        'separator': prefix.text.trim().isEmpty ? null : separator.text,
                        'paddingLength': int.tryParse(padding.text) ?? 0,
                        'startNo': int.parse(start.text),
                        'nextNo': int.parse(next.text),
                        'endNo': int.parse(end.text),
                        'defaultAllocationSize': int.parse(allocation.text),
                        'warningThreshold': int.parse(warning.text),
                        'active': active,
                        if (existing != null) 'id': existing.id,
                        if (existing != null) 'lockVersion': existing.lockVersion,
                      };
                      try {
                        if (existing == null) {
                          await _service.createSequence(body);
                        } else {
                          await _service.updateSequence(existing.id, body);
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        _showSuccess(existing == null ? 'Number sequence created' : 'Number sequence updated');
                        await _load();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => saving = false);
                        _showError(_cleanError(e));
                      }
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [type, description, prefix, separator, padding, start, next, end, allocation, warning]) {
      controller.dispose();
    }
  }

  Future<void> _showDocumentRangeEditor({DocumentNumberRangeConfiguration? existing}) async {
    final formKey = GlobalKey<FormState>();
    final object = TextEditingController(text: existing?.object ?? '');
    final prefix = TextEditingController(text: existing?.prefix ?? '');
    final start = TextEditingController(text: _trailingDigits(existing?.start) ?? '0000000001');
    final current = TextEditingController(text: _trailingDigits(existing?.current) ?? '0000000000');
    final end = TextEditingController(text: _trailingDigits(existing?.end) ?? '9999999999');
    var validFrom = existing?.validFrom ?? DateTime.now();
    var validTo = existing?.validTo ?? DateTime(9999, 12, 31);
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Document Number Range' : 'Edit ${existing.object}'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: object,
                      enabled: existing == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Object', hintText: 'e.g. DELIVERY-NOTE'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: prefix,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Prefix (optional)', hintText: 'e.g. INV-'),
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      validator: (value) => (value?.trim().length ?? 0) > 10 ? 'Prefix cannot exceed 10 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField(start, 'Start Number')),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(current, 'Current Number', onChanged: (_) => setDialogState(() {}))),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField(end, 'End Number')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _dateButton(
                            label: 'Valid From',
                            value: validFrom,
                            onChanged: (value) => setDialogState(() => validFrom = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateButton(
                            label: 'Valid To',
                            value: validTo,
                            onChanged: (value) => setDialogState(() => validTo = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Preview of the next generated number: ${prefix.text.trim()}${_pad10((int.tryParse(current.text) ?? 0) + 1)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      final body = {
                        'object': object.text.trim().toUpperCase().replaceAll(' ', '-'),
                        'prefix': prefix.text.trim().isEmpty ? null : prefix.text.trim().toUpperCase(),
                        'start': start.text,
                        'current': current.text,
                        'end': end.text,
                        'validFrom': DateFormat('yyyy-MM-dd').format(validFrom),
                        'validTo': DateFormat('yyyy-MM-dd').format(validTo),
                      };
                      try {
                        if (existing == null) {
                          await _service.createDocumentRange(body);
                        } else {
                          await _service.updateDocumentRange(existing.id, body);
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        _showSuccess(existing == null ? 'Document number range created' : 'Document number range updated');
                        await _load();
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => saving = false);
                        _showError(_cleanError(e));
                      }
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [object, prefix, start, current, end]) {
      controller.dispose();
    }
  }

  Future<void> _showAllocations(NumberSequenceConfiguration sequence) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${sequence.seqType} Allocated Ranges'),
        content: SizedBox(
          width: 850,
          height: 480,
          child: FutureBuilder<List<NumberRangeAllocationRecord>>(
            future: _service.getAllocations(seqType: sequence.seqType),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text(_cleanError(snapshot.error!)));
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const Center(child: Text('No device ranges have been allocated for this sequence.'));
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: const Icon(Icons.devices_other_rounded),
                    title: Text('${_number(item.fromNo)} – ${_number(item.toNo)}'),
                    subtitle: Text(
                      'Device ${item.deviceId} • Next local ${_number(item.nextLocalNo)} • ${_dateTime(item.createdAt)}',
                    ),
                    trailing: _statusChip(_Status(item.status, item.status == 'ACTIVE' ? Colors.green : Colors.grey)),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _showAudit(String sourceType, String rangeKey) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$rangeKey Audit Trail'),
        content: SizedBox(
          width: 850,
          height: 500,
          child: FutureBuilder<List<NumberRangeAuditRecord>>(
            future: _service.getAudit(sourceType: sourceType, rangeKey: rangeKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text(_cleanError(snapshot.error!)));
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const Center(child: Text('No configuration changes have been recorded yet.'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    elevation: 0,
                    child: ExpansionTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(item.action, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${_dateTime(item.changedAt)} • ${item.changedBy ?? 'SYSTEM'}'),
                      children: [
                        if (item.previousValue != null) _auditValue('Previous', item.previousValue),
                        _auditValue('New', item.newValue),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Widget _auditValue(String label, dynamic value) {
    String text;
    if (value is String) {
      try {
        text = const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
      } catch (_) {
        text = value;
      }
    } else {
      text = const JsonEncoder.withIndent('  ').convert(value);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label is required';
        if (int.tryParse(value) == null) return 'Enter a valid number';
        return null;
      },
    );
  }

  Widget _dateButton({required String label, required DateTime value, required ValueChanged<DateTime> onChanged}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(9999, 12, 31),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(DateFormat('dd MMM yyyy').format(value)),
      ),
    );
  }

  Widget _summaryRow(List<_Summary> summaries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 700 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: summaries
              .map(
                (summary) => SizedBox(
                  width: width,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(summary.icon, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(summary.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              Text(summary.label, style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusChip(_Status status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required' : null;
  String _number(int value) => NumberFormat.decimalPattern('en_ZA').format(value);
  String _date(DateTime? value) => value == null ? '-' : DateFormat('dd MMM yyyy').format(value);
  String _dateTime(DateTime? value) => value == null ? '-' : DateFormat('dd MMM yyyy HH:mm').format(value.toLocal());
  String _pad10(int value) => value.toString().padLeft(10, '0');

  String? _trailingDigits(String? value) {
    if (value == null) return null;
    return RegExp(r'(\d+)$').firstMatch(value)?.group(1);
  }

  String _cleanError(Object error) => friendlyErrorMessage(error);

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green.shade700));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(message)), backgroundColor: Colors.red.shade700));
  }
}

class _Summary {
  final String label;
  final String value;
  final IconData icon;
  const _Summary(this.label, this.value, this.icon);
}

class _Status {
  final String label;
  final Color color;
  const _Status(this.label, this.color);
}
