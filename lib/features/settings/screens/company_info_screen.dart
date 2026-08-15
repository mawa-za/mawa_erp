import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../../../core/models/setting.dart';
import '../../../core/services/setting_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CompanyInfoScreen extends StatefulWidget {
  final bool isReadOnly;
  const CompanyInfoScreen({super.key, this.isReadOnly = false});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  List<int>? _logoBytes;
  bool _isUploadingLogo = false;
  
  final Map<String, TextEditingController> _controllers = {
    'NAME': TextEditingController(),
    'REGISTRATION-NUMBER': TextEditingController(),
    'VAT-NUMBER': TextEditingController(),
    'FSP-NUMBER': TextEditingController(),
    'EMAIL': TextEditingController(),
    'PHONE': TextEditingController(),
    'ADDRESS-LINE-1': TextEditingController(),
    'ADDRESS-LINE-2': TextEditingController(),
    'SUBURB': TextEditingController(),
    'CITY': TextEditingController(),
    'POSTAL-CODE': TextEditingController(),
    'WEBSITE': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final settings = await SettingService().getSettings();
      final tenantSettings = settings.where((s) => s.type == 'TENANT').toList();
      
      for (var setting in tenantSettings) {
        if (_controllers.containsKey(setting.attribute)) {
          _controllers[setting.attribute]!.text = setting.value;
        }
      }

      await _loadLogo();
    } catch (e) {
      debugPrint('Error loading company info: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLogo() async {
    try {
      final response = await ApiClient().get(
        '/v2/company-logo/content',
        accept: 'image/*',
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() => _logoBytes = response.bodyBytes);
      } else if (response.statusCode == 204) {
        setState(() => _logoBytes = null);
      }
    } catch (e) {
      debugPrint('Error loading company logo: $e');
    }
  }

  Future<void> _selectAndUploadLogo() async {
    if (_isUploadingLogo || widget.isReadOnly) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read the selected image.')),
        );
      }
      return;
    }

    final lowerName = file.name.toLowerCase();
    final contentType = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() => _isUploadingLogo = true);
    try {
      final response = await ApiClient().postMultipartBytes(
        '/v2/company-logo',
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
      );
      if (response.statusCode != 200) {
        String message = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}
        throw AppException(message);
      }
      if (!mounted) return;
      await _loadLogo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company logo updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Unable to upload company logo: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      for (var entry in _controllers.entries) {
        await SettingService().updateSetting('TENANT', entry.key, entry.value.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company information updated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error saving info: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Company Information', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (!_isLoading && !widget.isReadOnly)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveCompanyInfo,
              icon: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.check),
              label: const Text('SAVE'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoHeader(),
                  const SizedBox(height: 16),
                  _buildSectionCard('General Details', [
                    _buildTextField('NAME', 'Company Name', Icons.business, validator: (v) => v!.isEmpty ? 'Required' : null),
                    _buildTextField('REGISTRATION-NUMBER', 'Registration Number', Icons.app_registration),
                    _buildTextField('VAT-NUMBER', 'VAT Number', Icons.percent),
                    _buildTextField('FSP-NUMBER', 'FSP Number', Icons.verified_user_outlined),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionCard('Contact Info', [
                    _buildTextField('EMAIL', 'Email Address', Icons.email_outlined),
                    _buildTextField('PHONE', 'Phone Number', Icons.phone_outlined),
                    _buildTextField('WEBSITE', 'Website', Icons.language_outlined),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionCard('Address', [
                    _buildTextField('ADDRESS-LINE-1', 'Address Line 1', Icons.location_on_outlined),
                    _buildTextField('ADDRESS-LINE-2', 'Address Line 2', Icons.location_on_outlined),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('SUBURB', 'Suburb', null)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('CITY', 'City', null)),
                      ],
                    ),
                    _buildTextField('POSTAL-CODE', 'Postal Code', Icons.mark_as_unread_outlined),
                  ]),
                  const SizedBox(height: 16),
                  _buildLogoUploadCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLogoHeader() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _logoBytes != null
                  ? Image.memory(Uint8List.fromList(_logoBytes!), fit: BoxFit.contain)
                  : Icon(Icons.business, size: 60, color: Colors.grey[400]),
            ),
          ),
          if (!widget.isReadOnly)
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                  onPressed: _isUploadingLogo ? null : _selectAndUploadLogo,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.image_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Company logo', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Attach a PNG or JPG image only (maximum 300 KB). MAWA places the logo inside a 400 × 400 pixel square frame. '
                    'Larger images are shrunk proportionally to fit without cropping or distortion.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!widget.isReadOnly)
              FilledButton.icon(
                onPressed: _isUploadingLogo ? null : _selectAndUploadLogo,
                icon: _isUploadingLogo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploadingLogo ? 'Uploading...' : 'Choose image'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
            const Divider(height: 24),
            ...children.expand((widget) => [widget, const SizedBox(height: 12)]).toList()..removeLast(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String attribute, String label, IconData? icon, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: _controllers[attribute],
      enabled: !widget.isReadOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: widget.isReadOnly ? Colors.grey[100] : Colors.grey[50],
        isDense: true,
      ),
      validator: validator,
      style: const TextStyle(fontSize: 14),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
