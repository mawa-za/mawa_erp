import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../api_client.dart';
import '../models/attachment.dart';
import '../models/field_option.dart';
import '../services/field_service.dart';

class AttachmentSection extends StatefulWidget {
  final String objectId;
  const AttachmentSection({super.key, required this.objectId});

  @override
  State<AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends State<AttachmentSection> {
  List<Attachment> _attachments = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiClient().get('/attachment?objectId=${widget.objectId}');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('content')) {
          data = decoded['content'];
        } else {
          data = [];
        }

        if (mounted) {
          setState(() {
            _attachments = data.map((json) => Attachment.fromJson(Map<String, dynamic>.from(json))).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading attachments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadAttachment() async {
    try {
      final List<FieldOption> docTypes = await FieldService().getOptionsByField('DOCUMENT-TYPE');
      
      if (!mounted) return;

      FieldOption? selectedDocType;
      String? base64Content;
      String? fileName;
      String? extension;

      final bool? shouldUpload = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Attachment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FieldOption>(
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: docTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.description),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedDocType = value),
                ),
                const SizedBox(height: 16),
                if (fileName != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setDialogState(() {
                            fileName = null;
                            base64Content = null;
                            extension = null;
                          }),
                        )
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                        withData: true,
                      );

                      if (result != null && result.files.single.bytes != null) {
                        setDialogState(() {
                          fileName = result.files.single.name;
                          extension = result.files.single.extension;
                          base64Content = base64Encode(result.files.single.bytes!);
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Select File'),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: (selectedDocType != null && base64Content != null) 
                  ? () => Navigator.pop(context, true) 
                  : null,
                child: const Text('UPLOAD'),
              ),
            ],
          ),
        ),
      );

      if (shouldUpload == true && selectedDocType != null && base64Content != null) {
        setState(() => _isUploading = true);
        
        final payload = {
          'objectId': widget.objectId,
          'documentType': selectedDocType!.toJson(),
          'extension': extension,
          'content': base64Content,
        };

        final response = await ApiClient().post('/attachment', body: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _loadAttachments();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attachment uploaded successfully')),
            );
          }
        } else {
          throw Exception('Failed to upload: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _viewAttachment(Attachment attachment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiClient().get('/attachment/${attachment.id}');
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final base64String = response.body.replaceAll('"', '');
        final bytes = base64Decode(base64String);

        if (kIsWeb) {
          final mimeType = _getMimeType(attachment.extension);
          final url = 'data:$mimeType;base64,$base64String';
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
          } else {
            throw 'Could not launch $url';
          }
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/${attachment.id}.${attachment.extension}');
          await file.writeAsBytes(bytes);
          await OpenFilex.open(file.path);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure loading is closed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing attachment: $e')),
        );
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Attachments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_isUploading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                onPressed: _uploadAttachment,
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                tooltip: 'Add Attachment',
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_attachments.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No attachments found', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final att = _attachments[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    att.extension.toLowerCase() == 'pdf' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                    color: att.extension.toLowerCase() == 'pdf' ? Colors.red : Colors.blue,
                  ),
                  title: Text(att.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('Uploaded by ${att.uploadedBy} on ${att.uploadDate}', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.visibility_outlined, size: 20),
                  onTap: () => _viewAttachment(att),
                ),
              );
            },
          ),
      ],
    );
  }
}
