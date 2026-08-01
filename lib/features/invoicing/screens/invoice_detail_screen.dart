import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../../../core/api_client.dart';
import '../models/invoice_detail.dart';
import '../../partners/models/partner.dart';
import '../services/invoice_service.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import 'invoice_pdf_preview_screen.dart';
import 'invoice_create_screen.dart' hide Partner;
import 'package:mawa_erp/core/errors/app_error.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _isLoading = true;
  bool _isSendingEmail = false;
  bool _isSubmitting = false;
  InvoiceDetail? _detail;
  Partner? _partner;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInvoiceDetails();
  }

  Future<void> _fetchInvoiceDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient().get('/v2/invoice/${widget.invoiceId}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final detail = InvoiceDetail.fromJson(data);

        setState(() {
          _detail = detail;
        });

        // Fetch full partner details if partnerId is available
        if (detail.customerId != null && detail.customerId!.isNotEmpty) {
          await _fetchPartnerDetails(detail.customerId!);
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = friendlyErrorMessage(
            response.body,
            statusCode: response.statusCode,
            fallback: 'The invoice details could not be loaded. Please try again.',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage('An error occurred: $e');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPartnerDetails(String partnerId) async {
    try {
      final response = await ApiClient().get('/v2/partner/$partnerId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _partner = Partner.fromJson(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching partner details: $e');
    }
  }

  void _handlePrint() {
    if (_detail == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvoicePdfPreviewScreen(
          invoice: _detail!,
          partner: _partner,
        ),
      ),
    );
  }

  Future<void> _handleEmail() async {
    if (_detail == null) return;

    final initialEmail = _partner?.email ?? '';
    final emailController = TextEditingController(text: initialEmail);
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Row(
          children: [
            Icon(Icons.email_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Email invoice',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The invoice PDF will be sent to the address below.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  autofocus: initialEmail.isEmpty,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final candidate = (value ?? '').trim();
                    if (candidate.isEmpty) return 'Enter an email address';
                    if (!candidate.contains('@') || !candidate.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(
                      dialogContext,
                      emailController.text.trim(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, emailController.text.trim());
            },
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Send invoice'),
          ),
        ],
      ),
    );

    emailController.dispose();
    if (email == null) return;

    setState(() => _isSendingEmail = true);
    try {
      await InvoiceService().sendInvoiceEmail(_detail!.id, email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice emailed successfully'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error emailing invoice: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  Future<void> _issueCreditNote() async {
    final detail = _detail;
    if (detail == null) return;

    final maximumCents = (detail.totalCents - detail.creditedCents).clamp(0, detail.totalCents);
    if (maximumCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invoice has already been fully credited.')),
      );
      return;
    }

    final amountController = TextEditingController(
      text: (maximumCents / 100).toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Issue credit note',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Credit amount',
                    prefixText: 'R ',
                    helperText: 'Maximum R ${(maximumCents / 100).toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    if ((amount * 100).round() > maximumCents) {
                      return 'Amount exceeds the remaining invoice value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Explain why this credit note is being issued',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'A reason is required'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, {
                'amountCents': (double.parse(amountController.text.trim()) * 100).round(),
                'reason': reasonController.text.trim(),
              });
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Issue credit note'),
          ),
        ],
      ),
    );

    amountController.dispose();
    reasonController.dispose();
    if (result == null) return;

    try {
      final creditNote = await InvoiceService().issueCreditNote(
        detail.id,
        result['amountCents'] as int,
        result['reason'] as String,
      );
      final id = creditNote['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final pdf = await InvoiceService().getCreditNotePdf(id);
        await Printing.sharePdf(
          bytes: pdf,
          filename: '${creditNote['creditNoteNo'] ?? 'credit-note'}.pdf',
        );
      }
      await _fetchInvoiceDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credit note issued successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Unable to issue credit note: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadCustomerStatement() async {
    final partnerId = _detail?.customerId;
    if (partnerId == null || partnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invoice is not linked to a customer.')),
      );
      return;
    }

    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: DateTime(today.year, today.month - 3, today.day),
        end: today,
      ),
      helpText: 'CUSTOMER STATEMENT PERIOD',
      saveText: 'GENERATE',
    );
    if (range == null) return;

    try {
      final pdf = await InvoiceService().getCustomerStatementPdf(
        partnerId,
        range.start,
        range.end,
      );
      await Printing.sharePdf(
        bytes: pdf,
        filename:
            'customer-statement-${DateFormat('yyyyMMdd').format(range.start)}-${DateFormat('yyyyMMdd').format(range.end)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Unable to generate statement: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForApproval() async {
    if (_detail == null) return;

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final submission = ApprovalSubmission(
        approvalType: 'INVOICE',
        referenceId: _detail!.id,
        referenceNo: _detail!.number,
        title: 'Invoice ${_detail!.number} - ${_partner?.fullName ?? _detail!.customerName} - R ${_detail!.totalAmount.toStringAsFixed(2)}',
        description: 'Approval requested for invoice to ${_partner?.fullName ?? _detail!.customerName} for R ${_detail!.totalAmount.toStringAsFixed(2)}',
        requesterId: userId,
        payloadJson: jsonEncode({
          ..._detail!.toJson(),
          'invoiceNumber': _detail!.number,
          'customerName': _partner?.fullName ?? _detail!.customerName,
          'totalAmountCents': _detail!.totalCents,
          'attachmentObjectIds': [_detail!.id, _detail!.customerId],
        }),
      );

      await ApprovalService().submitApproval(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice submitted for approval successfully')),
        );
        _fetchInvoiceDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to submit for approval: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Invoice Details'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: _detail == null
            ? null
            : compact
                ? [
                    PopupMenuButton<String>(
                      tooltip: 'Invoice actions',
                      onSelected: _handleInvoiceAction,
                      itemBuilder: (context) => _buildInvoiceActionMenu(),
                    ),
                    const SizedBox(width: 8),
                  ]
                : _buildDesktopActions(colorScheme),
      ),
      body: _buildBody(colorScheme),
    );
  }

  List<Widget> _buildDesktopActions(ColorScheme colorScheme) {
    final detail = _detail!;
    return [
      if (detail.status == 'DRAFT' || detail.status == 'NEW')
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitForApproval,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Submit'),
          ),
        ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: 'Email invoice',
        onPressed: _isSendingEmail ? null : _handleEmail,
        icon: _isSendingEmail
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.email_outlined),
      ),
      IconButton(
        tooltip: 'Print invoice',
        onPressed: _handlePrint,
        icon: const Icon(Icons.print_outlined),
      ),
      IconButton(
        tooltip: 'Edit invoice',
        onPressed: _openEditScreen,
        icon: const Icon(Icons.edit_outlined),
      ),
      PopupMenuButton<String>(
        tooltip: 'More actions',
        onSelected: _handleInvoiceAction,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'credit-note',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('Issue credit note'),
            ),
          ),
          const PopupMenuItem(
            value: 'statement',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_balance_wallet_outlined),
              title: Text('Customer statement'),
            ),
          ),
        ],
      ),
      const SizedBox(width: 10),
    ];
  }

  List<PopupMenuEntry<String>> _buildInvoiceActionMenu() {
    final detail = _detail!;
    return [
      if (detail.status == 'DRAFT' || detail.status == 'NEW')
        const PopupMenuItem(
          value: 'submit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.send_rounded),
            title: Text('Submit for approval'),
          ),
        ),
      const PopupMenuItem(
        value: 'email',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.email_outlined),
          title: Text('Email invoice'),
        ),
      ),
      const PopupMenuItem(
        value: 'print',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.print_outlined),
          title: Text('Print invoice'),
        ),
      ),
      const PopupMenuItem(
        value: 'edit',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined),
          title: Text('Edit invoice'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'credit-note',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.receipt_long_outlined),
          title: Text('Issue credit note'),
        ),
      ),
      const PopupMenuItem(
        value: 'statement',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.account_balance_wallet_outlined),
          title: Text('Customer statement'),
        ),
      ),
    ];
  }

  void _handleInvoiceAction(String action) {
    switch (action) {
      case 'submit':
        _submitForApproval();
        break;
      case 'email':
        _handleEmail();
        break;
      case 'print':
        _handlePrint();
        break;
      case 'edit':
        _openEditScreen();
        break;
      case 'credit-note':
        _issueCreditNote();
        break;
      case 'statement':
        _downloadCustomerStatement();
        break;
    }
  }

  Future<void> _openEditScreen() async {
    if (_detail == null) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceCreateScreen(existingInvoice: _detail),
      ),
    );
    if (result == true) {
      _fetchInvoiceDetails();
    }
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 32,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Unable to load invoice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _fetchInvoiceDetails,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_detail == null) {
      return const Center(child: Text('No invoice details found.'));
    }

    final detail = _detail!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 1200
            ? 32.0
            : constraints.maxWidth >= 700
                ? 24.0
                : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInvoiceOverview(detail, colorScheme),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final sideBySide = contentConstraints.maxWidth >= 900;
                      final customer = _buildCustomerCard(detail, colorScheme);
                      final general = _buildGeneralDetailsCard(detail, colorScheme);
                      if (!sideBySide) {
                        return Column(
                          children: [
                            customer,
                            const SizedBox(height: 18),
                            general,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: customer),
                          const SizedBox(width: 18),
                          Expanded(child: general),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildItemsCard(detail, colorScheme),
                  if (detail.payments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildPaymentsCard(detail, colorScheme),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildTotalsCard(detail, colorScheme),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceOverview(
    InvoiceDetail detail,
    ColorScheme colorScheme,
  ) {
    final customerName = _partner?.fullName ?? detail.customerName;
    final outstanding = detail.balanceAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.78),
            colorScheme.primaryContainer.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withOpacity(0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final identity = Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.onPrimary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          detail.number,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _buildStatusChip(detail.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$customerName  •  ${DateFormat('dd MMM yyyy').format(detail.invoiceDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final amount = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                'Invoice total',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'R ${detail.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              if (outstanding != detail.totalAmount || detail.paidAmount > 0) ...[
                const SizedBox(height: 5),
                Text(
                  'Balance due: R ${outstanding.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 20),
                amount,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 24),
              amount,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerCard(
    InvoiceDetail detail,
    ColorScheme colorScheme,
  ) {
    final customerName = _partner?.fullName ?? detail.customerName;
    final customerNumber = _partner?.number ?? detail.customerNumber;
    final email = _partner?.email ?? '';
    final phone = _partner?.phone ?? '';
    final address = _partner != null && _partner!.addresses.isNotEmpty
        ? '${_partner!.addresses.first.line1}, ${_partner!.addresses.first.city}'
        : '';

    return _buildSectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Customer',
      subtitle: 'The customer linked to this invoice.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (customerNumber.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Customer $customerNumber',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty || address.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            if (email.isNotEmpty)
              _buildContactRow(Icons.email_outlined, email),
            if (phone.isNotEmpty) ...[
              if (email.isNotEmpty) const SizedBox(height: 10),
              _buildContactRow(Icons.phone_outlined, phone),
            ],
            if (address.isNotEmpty) ...[
              if (email.isNotEmpty || phone.isNotEmpty)
                const SizedBox(height: 10),
              _buildContactRow(Icons.location_on_outlined, address),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralDetailsCard(
    InvoiceDetail detail,
    ColorScheme colorScheme,
  ) {
    return _buildSectionCard(
      icon: Icons.description_outlined,
      title: 'Invoice information',
      subtitle: 'Document dates, reference and currency.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            _buildInformationTile(
              'Reference',
              detail.reference.isEmpty ? 'Not provided' : detail.reference,
              Icons.tag_rounded,
            ),
            _buildInformationTile(
              'Invoice date',
              DateFormat('dd MMM yyyy').format(detail.invoiceDate),
              Icons.calendar_month_outlined,
            ),
            _buildInformationTile(
              'Due date',
              detail.dueDate == null
                  ? 'Not specified'
                  : DateFormat('dd MMM yyyy').format(detail.dueDate!),
              Icons.event_available_outlined,
            ),
            _buildInformationTile(
              'Currency',
              detail.currency,
              Icons.payments_outlined,
            ),
          ];

          if (constraints.maxWidth < 520) {
            return Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  fields[i],
                  if (i != fields.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields
                .map(
                  (field) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: field,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildInformationTile(
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(InvoiceDetail detail, ColorScheme colorScheme) {
    final hasDiscount = detail.items.any((item) => item.discountCents > 0);
    return _buildSectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Invoice items',
      subtitle:
          '${detail.items.length} ${detail.items.length == 1 ? 'item' : 'items'} included on this invoice.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: detail.items.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == detail.items.length - 1 ? 0 : 12,
                  ),
                  child: _buildMobileItemCard(
                    entry.key,
                    entry.value,
                    colorScheme,
                  ),
                );
              }).toList(),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                children: [
                  _buildItemTableHeader(hasDiscount, colorScheme),
                  ...detail.items.asMap().entries.map(
                        (entry) => _buildDesktopItemRow(
                          entry.key,
                          entry.value,
                          hasDiscount,
                          colorScheme,
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemTableHeader(
    bool hasDiscount,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
      child: Row(
        children: [
          const SizedBox(
            width: 36,
            child: Text('#', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const Expanded(
            flex: 6,
            child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(
            width: 80,
            child: Text(
              'QTY',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 18),
          const SizedBox(
            width: 130,
            child: Text(
              'UNIT PRICE',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (hasDiscount) ...[
            const SizedBox(width: 18),
            const SizedBox(
              width: 110,
              child: Text(
                'DISCOUNT',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const SizedBox(width: 18),
          const SizedBox(
            width: 140,
            child: Text(
              'TOTAL',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopItemRow(
    int index,
    InvoiceItem item,
    bool hasDiscount,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.7)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.productCode.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.productCode,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _formatQuantity(item.quantity),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 130,
            child: Text(
              item.showAmount ? 'R ${item.unitPrice.toStringAsFixed(2)}' : '—',
              textAlign: TextAlign.right,
            ),
          ),
          if (hasDiscount) ...[
            const SizedBox(width: 18),
            SizedBox(
              width: 110,
              child: Text(
                item.discountCents > 0
                    ? '- R ${(item.discountCents / 100).toStringAsFixed(2)}'
                    : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: item.discountCents > 0 ? colorScheme.error : null,
                ),
              ),
            ),
          ],
          const SizedBox(width: 18),
          SizedBox(
            width: 140,
            child: Text(
              item.showAmount ? 'R ${item.lineTotal.toStringAsFixed(2)}' : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(
    int index,
    InvoiceItem item,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (item.productCode.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.productCode,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildItemMetric('Quantity', _formatQuantity(item.quantity)),
              _buildItemMetric(
                'Unit price',
                item.showAmount ? 'R ${item.unitPrice.toStringAsFixed(2)}' : '—',
              ),
              if (item.discountCents > 0)
                _buildItemMetric(
                  'Discount',
                  '- R ${(item.discountCents / 100).toStringAsFixed(2)}',
                  color: colorScheme.error,
                ),
              _buildItemMetric(
                'Line total',
                item.showAmount ? 'R ${item.lineTotal.toStringAsFixed(2)}' : '—',
                emphasised: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemMetric(
    String label,
    String value, {
    Color? color,
    bool emphasised = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasised ? 14 : 12,
            fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
            color: color ?? (emphasised ? colorScheme.primary : null),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsCard(
    InvoiceDetail detail,
    ColorScheme colorScheme,
  ) {
    return _buildSectionCard(
      icon: Icons.payments_outlined,
      title: 'Payment history',
      subtitle:
          '${detail.payments.length} ${detail.payments.length == 1 ? 'payment has' : 'payments have'} been allocated.',
      child: Column(
        children: detail.payments.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == detail.payments.length - 1 ? 0 : 10,
            ),
            child: _buildPaymentRow(entry.value, colorScheme),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentRow(
    InvoicePayment payment,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentMethod,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('dd MMM yyyy, HH:mm').format(payment.paymentDate)}${payment.referenceNo.isEmpty ? '' : '  •  ${payment.referenceNo}'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'R ${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(
    InvoiceDetail detail,
    ColorScheme colorScheme,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.75)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', detail.subtotalAmount),
            const SizedBox(height: 10),
            _buildTotalRow('VAT', detail.vatAmount),
            if (detail.discountAmount > 0) ...[
              const SizedBox(height: 10),
              _buildTotalRow(
                'Discount',
                detail.discountAmount,
                negative: true,
                color: colorScheme.error,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            _buildTotalRow(
              'Invoice total',
              detail.totalAmount,
              emphasised: true,
              color: colorScheme.primary,
            ),
            if (detail.paidAmount > 0) ...[
              const SizedBox(height: 10),
              _buildTotalRow(
                'Payments received',
                detail.paidAmount,
                negative: true,
                color: Colors.green,
              ),
            ],
            if (detail.creditedAmount > 0) ...[
              const SizedBox(height: 10),
              _buildTotalRow(
                'Credit notes',
                detail.creditedAmount,
                negative: true,
                color: Colors.deepOrange,
              ),
            ],
            if (detail.paidAmount > 0 ||
                detail.creditedAmount > 0 ||
                detail.balanceCents != detail.totalCents) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
              _buildTotalRow(
                'Balance due',
                detail.balanceAmount,
                emphasised: true,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double value, {
    bool negative = false,
    bool emphasised = false,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasised ? 14 : 12,
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w500,
            color: emphasised ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 18),
        Text(
          '${negative ? '- ' : ''}R ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasised ? 18 : 13,
            fontWeight: emphasised ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'NEW':
        return Colors.blue;
      case 'DRAFT':
        return Colors.blueGrey;
      case 'AWAITING-APPROVAL':
      case 'AWAITING_APPROVAL':
        return Colors.orange;
      case 'CREDITED':
        return Colors.deepOrange;
      case 'PARTIALLY_CREDITED':
      case 'PARTIALLY-CREDITED':
        return Colors.amber.shade800;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Text(
        status.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.45,
        ),
      ),
    );
  }
}
