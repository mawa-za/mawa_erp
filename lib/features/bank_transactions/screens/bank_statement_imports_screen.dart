import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../../core/files/download_bytes.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import '../bank_transaction_service.dart';

/// Tenant-scoped manual uploads and the shared email/manual processing register.
class BankStatementImportsScreen extends StatefulWidget {
  const BankStatementImportsScreen({super.key});
  @override
  State<BankStatementImportsScreen> createState() => _BankStatementImportsScreenState();
}

class _BankStatementImportsScreenState extends State<BankStatementImportsScreen> {
  final _service = BankTransactionService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _files = [];
  String _source = '';
  String _status = '';
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;
  bool _canUpload = false;
  bool _last = true;
  int _page = 0;

  @override
  void initState() { super.initState(); _load(); _permissions(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _permissions() async {
    final allowed = await _service.canUploadStatements();
    if (mounted) setState(() => _canUpload = allowed);
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() { _loading = true; _error = null; });
    try {
      final page = more ? _page + 1 : 0;
      final response = await _service.statementImports(
        search: _search.text.trim(), source: _source, status: _status, page: page);
      if (!mounted) return;
      setState(() {
        _files = more
          ? [..._files, ...((response['content'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)))]
          : (response['content'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _last = response['last'] == true;
        _page = page;
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom,
      allowedExtensions: const ['csv', 'zip'], withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 5000000) {
      setState(() => _error = 'Select a non-empty CSV/ZIP no larger than 5 MB.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final result = await _service.uploadStatement(fileName: file.name, bytes: bytes);
      if (mounted) setState(() => _notice =
        'File #${result['id']}: ${result['status']} — ${result['importedCount']} new transactions. '
        'Original statement archived in GCS.');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally {
      if (mounted) { setState(() => _busy = false); await _load(); }
    }
  }

  Future<void> _retry(Map<String, dynamic> file) async {
    final id = (file['id'] as num).toInt();
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final result = await _service.retryStatement(id);
      if (mounted) setState(() => _notice =
        'File #$id reprocessed: ${result['status']}; total imported ${result['importedCount']}.');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally {
      if (mounted) { setState(() => _busy = false); await _load(); }
    }
  }

  Future<void> _download(Map<String, dynamic> file) async {
    try {
      final id = (file['id'] as num).toInt();
      final contents = await _service.downloadOriginalStatement(id);
      await downloadBytes(bytes: Uint8List.fromList(contents),
        fileName: file['fileName']?.toString() ?? 'statement.zip',
        mimeType: (file['fileName']?.toString().toLowerCase().endsWith('.zip') ?? false)
          ? 'application/zip' : 'text/csv');
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  Future<void> _history(Map<String, dynamic> file) async {
    try {
      final id = (file['id'] as num).toInt();
      final entries = await _service.statementHistory(id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Processing history · File #$id'),
        content: SizedBox(width: 650, height: 380, child: entries.isEmpty
          ? const Center(child: Text('No processing attempts yet.'))
          : ListView.separated(itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) {
                final a = entries[i];
                return ListTile(
                  leading: _statusIcon(a['status']?.toString() ?? ''),
                  title: Text('Attempt ${a['attemptNumber']} · ${a['status']}'),
                  subtitle: Text('By ${a['attemptedBy']} · '
                    '${AppDateUtils.displayDateTime(a['startedAt'], fallback: '-')}\n'
                    '${a['csvCount']} CSV files, ${a['importedCount']} new transactions, '
                    '${a['failedCsvCount']} failed'
                    '${a['summary'] == null ? '' : '\n${a['summary']}'}'),
                );
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'COMPLETED': return const Icon(Icons.check_circle_outline, color: Colors.green);
      case 'FAILED': case 'STORAGE_FAILED': return const Icon(Icons.error_outline, color: Colors.red);
      case 'PARTIAL': return const Icon(Icons.warning_amber_outlined, color: Colors.orange);
      case 'PROCESSING': return const Icon(Icons.sync);
      default: return const Icon(Icons.inventory_2_outlined);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bank Statement Files & Processing History'), actions: [
      IconButton(onPressed: _busy ? null : () => _load(), icon: const Icon(Icons.refresh), tooltip: 'Refresh history'),
    ]),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Original bank statements from manual uploads and trusted email are stored privately in Google Cloud Storage. '
          'Each file is tracked independently, and failed imports may be retried without duplicating deposits.'),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (_canUpload) FilledButton.icon(onPressed: _busy ? null : _upload,
            icon: const Icon(Icons.upload_file), label: const Text('Upload bank CSV / ZIP')),
          SizedBox(width: 240, child: TextField(controller: _search, onSubmitted: (_) => _load(),
            decoration: const InputDecoration(labelText: 'Filename or uploaded by', prefixIcon: Icon(Icons.search)))),
          DropdownButton<String>(value: _source, items: const [
            DropdownMenuItem(value: '', child: Text('All sources')),
            DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
            DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
          ], onChanged: (v) { setState(() => _source = v ?? ''); _load(); }),
          DropdownButton<String>(value: _status, items: const [
            DropdownMenuItem(value: '', child: Text('All statuses')),
            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
            DropdownMenuItem(value: 'PARTIAL', child: Text('Partial')),
            DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
            DropdownMenuItem(value: 'PROCESSING', child: Text('Processing')),
            DropdownMenuItem(value: 'STORED', child: Text('Stored')),
            DropdownMenuItem(value: 'STORAGE_FAILED', child: Text('Storage failed')),
          ], onChanged: (v) { setState(() => _status = v ?? ''); _load(); }),
          OutlinedButton.icon(onPressed: _loading || _busy ? null : () => _load(),
            icon: const Icon(Icons.search), label: const Text('Search')),
        ]),
        if (!_canUpload && !_loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Upload and retry require the Bank Statement Import permission; '
            'a tenant administrator can grant it under Role Permissions.')),
        const SizedBox(height: 10),
        if (_busy || _loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_notice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_notice!)),
        const SizedBox(height: 8),
        Expanded(child: _files.isEmpty
          ? Center(child: Text(_loading ? 'Loading files...' : 'No bank statement files match the filters.'))
          : ListView.builder(itemCount: _files.length, itemBuilder: (context, index) {
            final f = _files[index];
            final status = f['status']?.toString() ?? '';
            final retryable = status == 'FAILED' || status == 'PARTIAL' || status == 'STORED';
            return Card(child: ListTile(
              leading: _statusIcon(status),
              title: Text('#${f['id']} · ${f['fileName']}'),
              subtitle: Text('${f['source']} / ${f['provider']} · $status · '
                '${AppDateUtils.displayDateTime(f['createdAt'], fallback: '-')}\n'
                'Uploaded by ${f['uploadedBy']} · ${f['csvCount']} CSV, '
                '${f['importedCount']} new transactions, ${f['failedCsvCount']} failed'
                '${f['lastError'] == null ? '' : '\n${f['lastError']}'}'),
              isThreeLine: true,
              trailing: Wrap(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
                if (f['stored'] == true) IconButton(
                  onPressed: () => _download(f), icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download original statement'),
                OutlinedButton(onPressed: () => _history(f), child: const Text('History')),
                if (_canUpload && retryable) OutlinedButton.icon(onPressed: _busy ? null : () => _retry(f),
                  icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ]),
            ));
          })),
        if (!_last) Align(alignment: Alignment.center,
          child: OutlinedButton(onPressed: _loading || _busy ? null : () => _load(more: true),
            child: const Text('Load more'))),
      ])),
  );
}
