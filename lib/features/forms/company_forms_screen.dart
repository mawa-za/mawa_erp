import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';

class CompanyFormsScreen extends StatefulWidget {
  const CompanyFormsScreen({super.key});

  @override
  State<CompanyFormsScreen> createState() => _CompanyFormsScreenState();
}

class _CompanyFormsScreenState extends State<CompanyFormsScreen> {
  List<Map<String, dynamic>> _forms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ApiClient().get('/v2/company-forms');
      if (response.statusCode != 200) throw Exception(response.body);
      final decoded = jsonDecode(response.body);
      if (mounted) setState(() {
        _forms = (decoded as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load forms: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _download(Map<String, dynamic> form) async {
    final response = await ApiClient().get(
      '/v2/company-forms/${form['id']}/download',
      accept: 'application/octet-stream',
    );
    if (response.statusCode != 200) throw Exception(response.body);
    return response.bodyBytes;
  }

  Future<void> _preview(Map<String, dynamic> form) async {
    final extension = (form['extension'] ?? '').toString().toLowerCase();
    if (extension != 'pdf') {
      await _share(form);
      return;
    }
    final bytes = await _download(form);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(form['title']?.toString() ?? 'Form Preview')),
        body: PdfPreview(
          build: (_) async => bytes,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
        ),
      ),
    ));
  }

  Future<void> _share(Map<String, dynamic> form) async {
    try {
      final bytes = await _download(form);
      await Printing.sharePdf(
        bytes: bytes,
        filename: form['file_name']?.toString() ?? '${form['form_code']}.${form['extension']}',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _print(Map<String, dynamic> form) async {
    try {
      if ((form['extension'] ?? '').toString().toLowerCase() != 'pdf') {
        throw Exception('Printing is available for PDF forms. Download this file to print it with its native application.');
      }
      final bytes = await _download(form);
      await Printing.layoutPdf(name: form['title']?.toString() ?? 'Company Form', onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Forms'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _forms.isEmpty
              ? const Center(child: Text('No company forms have been published.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _forms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final form = _forms[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                        title: Text(form['title']?.toString() ?? form['form_code'].toString()),
                        subtitle: Text('${form['category']} • Version ${form['version_no']}\n${form['description'] ?? ''}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'preview') _preview(form);
                            if (action == 'download') _share(form);
                            if (action == 'print') _print(form);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'preview', child: Text('Preview')),
                            PopupMenuItem(value: 'download', child: Text('Download')),
                            PopupMenuItem(value: 'print', child: Text('Print')),
                          ],
                        ),
                        onTap: () => _preview(form),
                      ),
                    );
                  },
                ),
    );
  }
}
