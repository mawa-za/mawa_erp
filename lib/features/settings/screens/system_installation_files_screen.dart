import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/files/download_bytes.dart';
import '../../../core/services/access_profile_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class SystemInstallationFilesScreen extends StatefulWidget {
  const SystemInstallationFilesScreen({
    super.key,
    this.allowManage = false,
  });

  final bool allowManage;

  @override
  State<SystemInstallationFilesScreen> createState() =>
      _SystemInstallationFilesScreenState();
}

class _SystemInstallationFilesScreenState
    extends State<SystemInstallationFilesScreen> {
  List<Map<String, dynamic>> _files = const [];
  bool _loading = true;
  bool _canManage = false;
  String? _busyFileId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadManageAccess();
  }

  Future<void> _loadManageAccess() async {
    if (!widget.allowManage) return;
    try {
      final profile = await AccessProfileService().getProfile();
      if (mounted) setState(() => _canManage = profile.allWorkcentres);
    } catch (_) {
      if (mounted) setState(() => _canManage = false);
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response = await ApiClient().get('/v2/system-installation-files');
      if (response.statusCode != 200) {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'Installation files could not be loaded.',
        );
      }
      final decoded = jsonDecode(response.body);
      final files = decoded is List
          ? decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _files = files);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Installation files could not be loaded.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    PlatformFile? selectedFile;

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload installation file'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      helperText: 'Example: Xprinter Windows USB Driver',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      helperText: 'Optional installation or compatibility notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        withData: true,
                      );
                      if (result == null) return;
                      final file = result.files.single;
                      setDialogState(() {
                        selectedFile = file;
                        if (nameController.text.trim().isEmpty) {
                          nameController.text = file.name;
                        }
                      });
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(selectedFile?.name ?? 'Select installation file'),
                  ),
                  if (selectedFile != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatBytes(selectedFile!.size),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a display name.')),
                  );
                  return;
                }
                if (selectedFile?.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a file to upload.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || selectedFile?.bytes == null) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    final file = selectedFile!;
    final displayName = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();

    try {
      final response = await ApiClient().post(
        '/v2/system-installation-files',
        body: {
          'displayName': displayName,
          'description': description,
          'fileName': file.name,
          'extension': file.extension ?? _extensionOf(file.name),
          'file': base64Encode(file.bytes!),
        },
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'Installation file upload failed.',
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation file uploaded successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    setState(() => _busyFileId = id);
    try {
      final response =
          await ApiClient().get('/v2/system-installation-files/$id/download');
      if (response.statusCode != 200) {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'Installation file download failed.',
        );
      }
      final decoded = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final fileName = decoded['fileName']?.toString().trim();
      final extension = decoded['extension']?.toString().trim() ?? '';
      final base64File = decoded['file']?.toString() ?? '';
      if (base64File.isEmpty) throw AppException('Downloaded file was empty.');
      final bytes = base64Decode(base64File);
      final safeName = _safeFileName(
        fileName?.isNotEmpty == true
            ? fileName!
            : '${item['displayName'] ?? 'installation-file'}${extension.isEmpty ? '' : '.$extension'}',
      );

      await downloadBytes(
        bytes: bytes,
        fileName: safeName,
        mimeType: _mimeType(extension),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove installation file?'),
        content: Text(
          'Remove "${item['displayName'] ?? item['fileName'] ?? 'this file'}" from the user download list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyFileId = id);
    try {
      final response =
          await ApiClient().delete('/v2/system-installation-files/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw AppException.fromHttp(
          statusCode: response.statusCode,
          responseBody: response.body,
          fallback: 'Installation file could not be removed.',
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation file removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installation Files'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _upload,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload File'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.install_desktop_outlined, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No installation files available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _canManage
                              ? 'Upload printer drivers, utilities or other installation packages used with MawaERP.'
                              : 'Your administrator has not published any installation packages yet.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _files[index];
                    final id = item['id']?.toString() ?? '';
                    final extension = item['extension']?.toString() ?? '';
                    final busy = _busyFileId == id;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_iconFor(extension)),
                        ),
                        title: Text(
                          item['displayName']?.toString() ??
                              item['fileName']?.toString() ??
                              'Installation file',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((item['description']?.toString().trim() ?? '').isNotEmpty)
                              Text(item['description'].toString()),
                            Text(
                              item['fileName']?.toString() ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    onPressed: () => _download(item),
                                    tooltip: 'Download / open',
                                    icon: const Icon(Icons.download_outlined),
                                  ),
                                  if (_canManage)
                                    IconButton(
                                      onPressed: () => _delete(item),
                                      tooltip: 'Remove',
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
    );
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 && dot < fileName.length - 1
        ? fileName.substring(dot + 1).toLowerCase()
        : '';
  }

  static String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes bytes';
  }

  static IconData _iconFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'exe':
      case 'msi':
        return Icons.install_desktop_outlined;
      case 'zip':
      case '7z':
      case 'rar':
        return Icons.folder_zip_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _mimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'zip':
        return 'application/zip';
      case 'pdf':
        return 'application/pdf';
      case 'msi':
        return 'application/x-msi';
      case 'exe':
        return 'application/vnd.microsoft.portable-executable';
      default:
        return 'application/octet-stream';
    }
  }
}
