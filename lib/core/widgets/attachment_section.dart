import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../api_client.dart';
import '../models/attachment.dart';
import '../models/field_option.dart';
import '../services/field_service.dart';

class AttachmentSection extends StatefulWidget {
  final String objectId;
  final bool readOnly;
  final String documentTypeField;
  
  const AttachmentSection({
    super.key, 
    required this.objectId,
    this.readOnly = false,
    this.documentTypeField = 'DOCUMENT-TYPE',
  });

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
      final response = await ApiClient().get('/v2/attachment?objectId=${widget.objectId}');
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

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file;
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png': return Icons.image;
      case 'doc':
      case 'docx': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Future<void> _uploadAttachment() async {
    try {
      final List<FieldOption> docTypes = await FieldService().getOptionsByField(widget.documentTypeField);
      
      if (!mounted) return;

      FieldOption? selectedDocType;
      String? base64Content;
      String? fileName;
      String? extension;

      final bool? shouldUpload = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.attach_file_rounded, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                const Text('Add Attachment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Container(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DOCUMENT TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FieldOption>(
                    decoration: InputDecoration(
                      hintText: 'Select category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: docTypes.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.description, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (value) => setDialogState(() => selectedDocType = value),
                  ),
                  const SizedBox(height: 24),
                  const Text('FILE SELECTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (fileName != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_getFileIcon(extension), color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName!,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (extension != null)
                                  Text(
                                    extension!.toUpperCase(),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
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
                    InkWell(
                      onTap: () async {
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Tap to select a file', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('PDF, Image, or Word document', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: (selectedDocType != null && base64Content != null) 
                  ? () => Navigator.pop(context, true) 
                  : null,
                child: const Text('UPLOAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      );

      if (shouldUpload == true && selectedDocType != null && base64Content != null) {
        setState(() => _isUploading = true);
        
        final payload = {
          'objectId': widget.objectId,
          'documentType': selectedDocType!.code,
          'extension': extension,
          'file': base64Content,
        };

        final response = await ApiClient().post('/v2/attachment', body: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _loadAttachments();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Attachment uploaded successfully'),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          throw Exception('Failed to upload: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showImagePreview(Uint8List bytes, Attachment att, String base64String) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(att.description, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () => _downloadOrOpenFile(bytes, att, base64String),
                      tooltip: 'Download',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfPreview(Uint8List bytes, Attachment att) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(att.description),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
          body: PdfPreview(
            build: (format) async => bytes,
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  Future<void> _downloadOrOpenFile(Uint8List bytes, Attachment att, String base64String) async {
    try {
      if (kIsWeb) {
        final mimeType = _getMimeType(att.extension);
        final url = 'data:$mimeType;base64,$base64String';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
        } else {
          throw 'Could not launch $url';
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${att.id}.${att.extension}');
        await file.writeAsBytes(bytes);
        final result = await OpenFilex.open(file.path);
        
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading attachment: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _viewAttachment(Attachment attachment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text('Fetching document...', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await ApiClient().get('/v2/attachment/${attachment.id}');
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final base64String = response.body.replaceAll('"', '');
        final bytes = base64Decode(base64String);
        final ext = attachment.extension.toLowerCase();

        if (['jpg', 'jpeg', 'png'].contains(ext)) {
          _showImagePreview(bytes, attachment, base64String);
        } else if (ext == 'pdf') {
          _showPdfPreview(bytes, attachment);
        } else {
          _downloadOrOpenFile(bytes, attachment, base64String);
        }
      } else {
        throw Exception('Failed to fetch document: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure loading is closed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing attachment: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
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
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Attachments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (!widget.readOnly)
              if (_isUploading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton.icon(
                  onPressed: _uploadAttachment,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('No attachments found', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final att = _attachments[index];
              final bool isPdf = att.extension.toLowerCase() == 'pdf';
              final bool isImg = ['jpg', 'jpeg', 'png'].contains(att.extension.toLowerCase());
              
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isPdf ? Colors.red : (isImg ? Colors.orange : Colors.blue)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : (isImg ? Icons.image_rounded : Icons.insert_drive_file_rounded),
                      color: isPdf ? Colors.red.shade700 : (isImg ? Colors.orange.shade700 : Colors.blue.shade700),
                      size: 20,
                    ),
                  ),
                  title: Text(att.description, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text('By ${att.uploadedBy} • ${att.uploadDate}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blueGrey),
                  ),
                  onTap: () => _viewAttachment(att),
                ),
              );
            },
          ),
      ],
    );
  }
}
