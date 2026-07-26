import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models/field_option.dart';
import '../../core/services/field_service.dart';

class CompanyFormConfigurationScreen extends StatefulWidget {
  const CompanyFormConfigurationScreen({super.key});

  @override
  State<CompanyFormConfigurationScreen> createState() => _CompanyFormConfigurationScreenState();
}

class _CompanyFormConfigurationScreenState extends State<CompanyFormConfigurationScreen> {
  List<Map<String, dynamic>> _forms = [];
  List<FieldOption> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient().get('/v2/company-forms', queryParameters: {'activeOnly': false}),
        FieldService().getOptionsByField('COMPANY-FORM-CATEGORY'),
      ]);
      final response = results[0] as dynamic;
      if (response.statusCode != 200) throw Exception(response.body);
      final decoded = jsonDecode(response.body);
      if (mounted) setState(() {
        _forms = (decoded as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _categories = results[1] as List<FieldOption>;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load form configuration: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: existing?['form_code']?.toString() ?? '');
    final title = TextEditingController(text: existing?['title']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    String? category = existing?['category']?.toString();
    PlatformFile? selectedFile;

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Upload Company Form' : 'Upload New Version'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: code,
                      readOnly: existing != null,
                      decoration: const InputDecoration(labelText: 'Form Code', helperText: 'Uploading the same code replaces the published version.'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Title'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
                    TextFormField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((option) => DropdownMenuItem(value: option.code, child: Text(option.description))).toList(),
                      onChanged: (value) => setDialogState(() => category = value),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(withData: true, allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'], type: FileType.custom);
                        if (result != null) setDialogState(() => selectedFile = result.files.single);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(selectedFile?.name ?? 'Select form file'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate() && selectedFile?.bytes != null) Navigator.pop(context, true);
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || selectedFile?.bytes == null) return;
    try {
      final extension = selectedFile!.extension ?? selectedFile!.name.split('.').last;
      final response = await ApiClient().post('/v2/company-forms', body: {
        'formCode': code.text.trim().toUpperCase(),
        'title': title.text.trim(),
        'description': description.text.trim(),
        'category': category,
        'fileName': selectedFile!.name,
        'extension': extension,
        'file': base64Encode(selectedFile!.bytes!),
      });
      if (response.statusCode != 200 && response.statusCode != 201) throw Exception(response.body);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company form published. Existing versions with this code were replaced.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deactivate(Map<String, dynamic> form) async {
    final response = await ApiClient().delete('/v2/company-forms/${form['id']}');
    if (response.statusCode != 204 && response.statusCode != 200) throw Exception(response.body);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Forms Configuration')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _upload(), icon: const Icon(Icons.upload_file), label: const Text('Upload Form')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _forms.length,
              itemBuilder: (_, index) {
                final form = _forms[index];
                final active = form['active'] == true || form['active'] == 1;
                return Card(child: ListTile(
                  title: Text('${form['title']} (${form['form_code']})'),
                  subtitle: Text('${form['category']} • Version ${form['version_no']} • ${active ? 'Published' : 'Inactive'}'),
                  trailing: Wrap(children: [
                    IconButton(onPressed: () => _upload(form), tooltip: 'Upload new version', icon: const Icon(Icons.upload_file)),
                    if (active) IconButton(onPressed: () => _deactivate(form), tooltip: 'Unpublish', icon: const Icon(Icons.visibility_off_outlined)),
                  ]),
                ));
              },
            ),
    );
  }
}
