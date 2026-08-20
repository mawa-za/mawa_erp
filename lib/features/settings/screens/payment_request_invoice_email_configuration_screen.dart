import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../../../core/api_client.dart';
import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';

class PaymentRequestInvoiceEmailConfigurationScreen extends StatefulWidget {
  const PaymentRequestInvoiceEmailConfigurationScreen({super.key});

  @override
  State<PaymentRequestInvoiceEmailConfigurationScreen> createState() =>
      _PaymentRequestInvoiceEmailConfigurationScreenState();
}

class _PaymentRequestInvoiceEmailConfigurationScreenState
    extends State<PaymentRequestInvoiceEmailConfigurationScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _recipients = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _deliverySummary = {};
  List<FieldOption> _documentTypeOptions = const [];
  Set<String> _selectedDocumentTypes = {'SUPPLIER-INVOICE'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recipients.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _api.get('/v2/payment-request/invoice-email/configuration'),
        FieldService().getOptionsByField('DOCUMENT-TYPE-PAYMENT-REQUEST'),
      ]);
      final response = results[0];
      if (response.statusCode != 200) throw AppException(response.body);
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final options = (results[1] as List<FieldOption>)
          .where((option) => option.code.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.description.compareTo(b.description));
      final selected = _readDocumentTypes(data);
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true || data['enabled'] == 1;
        _recipients.text = data['recipient_emails']?.toString() ?? '';
        _subject.text = data['subject_template']?.toString() ??
            'Approved supplier invoice payment request {{requestNo}}';
        _body.text = data['body_message']?.toString() ?? '';
        _documentTypeOptions = options;
        _selectedDocumentTypes =
            selected.isEmpty ? {'SUPPLIER-INVOICE'} : selected;
        _deliverySummary = data['deliverySummary'] is Map
            ? Map<String, dynamic>.from(data['deliverySummary'] as Map)
            : {};
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                'Failed to load invoice email settings: $error',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> _readDocumentTypes(Map<String, dynamic> data) {
    final result = <String>{};
    final dynamic listValue = data['documentTypes'];
    if (listValue is List) {
      for (final value in listValue) {
        final code = value?.toString().trim().toUpperCase() ?? '';
        if (code.isNotEmpty) result.add(code);
      }
    } else {
      final raw = data['document_types']?.toString() ?? '';
      for (final value in raw.split(RegExp(r'[,;\n\r]+'))) {
        final code = value.trim().toUpperCase();
        if (code.isNotEmpty) result.add(code);
      }
    }
    return result;
  }

  String _documentTypeLabel(String code) {
    for (final option in _documentTypeOptions) {
      if (option.code.toUpperCase() == code.toUpperCase()) {
        return option.description.trim().isEmpty
            ? option.code
            : option.description;
      }
    }
    return code;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_enabled && _selectedDocumentTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one document type to email.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final documentTypes = _selectedDocumentTypes.toList()..sort();
      final response = await _api.put(
        '/v2/payment-request/invoice-email/configuration',
        body: {
          'enabled': _enabled,
          'recipientEmails': _recipients.text.trim(),
          'subjectTemplate': _subject.text.trim(),
          'bodyMessage': _body.text.trim(),
          'documentTypes': documentTypes,
        },
      );
      if (response.statusCode != 200) throw AppException(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice email configuration saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage('Unable to save configuration: $error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runBackfill() async {
    final limit = TextEditingController(text: '250');
    bool retryFailed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Run approved invoice email backfill'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This sends configured documents for previously approved Supplier Invoice payment requests. Requests previously skipped because email was not configured or the attachment was missing are reconsidered automatically. Already-sent requests are skipped.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum requests for this run',
                    helperText: 'Between 1 and 1 000',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: retryFailed,
                  title: const Text('Retry failed email deliveries'),
                  onChanged: (value) =>
                      setDialogState(() => retryFailed = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Run backfill'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final parsedLimit = int.tryParse(limit.text) ?? 250;
    try {
      final response = await _api.post(
        '/v2/payment-request/invoice-email/backfill',
        queryParameters: {
          'limit': parsedLimit.clamp(1, 1000),
          'retryFailed': retryFailed,
        },
      );
      if (response.statusCode != 200) throw AppException(response.body);
      final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      await _load();
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Backfill completed'),
            content: Text(
              'Processed: ${result['processed'] ?? 0}\n'
              'Sent: ${result['sent'] ?? 0}\n'
              'Skipped: ${result['skipped'] ?? 0}\n'
              'Failed: ${result['failed'] ?? 0}'
              '${(result['processed'] ?? 0) == 0 ? '\n\nNo eligible approved Supplier Invoice payment requests were found. Already-sent requests are excluded; enable Retry failed email deliveries only for genuine FAILED attempts.' : ''}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Backfill failed: $error')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Request Invoice Email')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: SwitchListTile(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      title: const Text('Email approved supplier invoices'),
                      subtitle: const Text(
                        'After approval, all attachments matching the selected document types are emailed to the configured recipients. Payment approval is not rolled back if email delivery fails.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recipients,
                    decoration: const InputDecoration(
                      labelText: 'Recipient email addresses',
                      helperText:
                          'Separate multiple addresses with commas or semicolons.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_enabled) return null;
                      return value == null || value.trim().isEmpty
                          ? 'At least one recipient is required when enabled'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Document types to include',
                      helperText:
                          'All attachments matching the selected payment-request document types will be emailed.',
                      border: OutlineInputBorder(),
                    ),
                    child: _documentTypeOptions.isEmpty
                        ? const Text(
                            'No payment request document types are configured.',
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _documentTypeOptions.map((option) {
                              final code = option.code.trim().toUpperCase();
                              return FilterChip(
                                label: Text(_documentTypeLabel(code)),
                                selected: _selectedDocumentTypes.contains(code),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedDocumentTypes.add(code);
                                    } else {
                                      _selectedDocumentTypes.remove(code);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Email subject',
                      helperText:
                          'Available fields: {{requestNo}}, {{invoiceNo}}, {{supplierName}}',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Subject is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Additional message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save configuration'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _runBackfill,
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('Run once-off backfill'),
                      ),
                    ],
                  ),
                  if (_deliverySummary.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Delivery summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _deliverySummary.entries
                          .map(
                            (entry) =>
                                Chip(label: Text('${entry.key}: ${entry.value}')),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
