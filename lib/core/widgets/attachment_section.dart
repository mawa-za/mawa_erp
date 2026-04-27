import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/attachment.dart';

class AttachmentSection extends StatefulWidget {
  final String objectId;
  const AttachmentSection({super.key, required this.objectId});

  @override
  State<AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends State<AttachmentSection> {
  List<Attachment> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('/attachment?objectId=${widget.objectId}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _attachments = data.map((json) => Attachment.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading attachments: $e');
    } finally {
      setState(() => _isLoading = false);
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
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final base64String = response.body.replaceAll('"', '');
        _showAttachmentDialog(attachment, base64String);
      }
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint('Error viewing attachment: $e');
    }
  }

  void _showAttachmentDialog(Attachment attachment, String base64Data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(attachment.description),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 16),
              Text('File type: ${attachment.extension.toUpperCase()}'),
              const SizedBox(height: 8),
              const Text('Attachment viewing (PDF/Image) implementation depends on device platform plugins.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
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
            Text(
              '${_attachments.length} files',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
