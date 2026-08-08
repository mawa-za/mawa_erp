import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_society.dart';
import '../models/group_society_contact.dart';
import '../models/group_society_payment.dart';
import '../services/membership_service.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../settings/services/pos_printing_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class GroupSocietyDetailScreen extends StatefulWidget {
  final String societyId;
  const GroupSocietyDetailScreen({super.key, required this.societyId});

  @override
  State<GroupSocietyDetailScreen> createState() => _GroupSocietyDetailScreenState();
}

class _GroupSocietyDetailScreenState extends State<GroupSocietyDetailScreen> with SingleTickerProviderStateMixin {
  final MembershipService _membershipService = MembershipService();
  final PartnerService _partnerService = PartnerService();

  late TabController _tabController;
  GroupSociety? _society;
  Partner? _partner;
  List<GroupSocietyContact> _contacts = [];
  List<GroupSocietyPayment> _payments = [];
  bool _isLoading = true;
  String? _error;
  int _attachmentCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final society = await _membershipService.getGroupSocietyById(widget.societyId);
      List<GroupSocietyContact> contacts = [];
      List<GroupSocietyPayment> payments = [];

      try {
        final results = await Future.wait([
          _membershipService.getGroupSocietyContacts(widget.societyId),
          _membershipService.getGroupSocietyStatement(widget.societyId),
        ]);
        contacts = results[0] as List<GroupSocietyContact>;
        payments = results[1] as List<GroupSocietyPayment>;
      } catch (e) {
        debugPrint('Error fetching secondary society details: $e');
      }

      if (mounted) {
        setState(() {
          _society = society;
          _contacts = contacts;
          _payments = payments;
          _isLoading = false;
        });

        if (society.partnerAvailable && society.partnerId.isNotEmpty) {
          _partnerService.getPartnerById(society.partnerId).then((p) {
            if (mounted) setState(() => _partner = p);
          }).catchError((e) {
            debugPrint('Error loading partner for society: $e');
            return null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    bool isPrimary = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Representative'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Contact Name')),
                TextFormField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    helperText: 'Enter exactly 10 numeric digits.',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                CheckboxListTile(
                  title: const Text('Primary Contact'),
                  value: isPrimary,
                  onChanged: (v) => setDialogState(() => isPrimary = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final mobileNo = phoneController.text.trim();
                if (mobileNo.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(mobileNo)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mobile Number must be exactly 10 numeric digits.')),
                  );
                  return;
                }
                final payload = {
                  "contactName": nameController.text.trim(),
                  "role": roleController.text.trim(),
                  "mobileNo": mobileNo,
                  "email": emailController.text.trim(),
                  "primaryContact": isPrimary
                };
                try {
                  await _membershipService.addGroupSocietyContact(widget.societyId, payload);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _fetchDetails();
  }

  Future<void> _showAddPaymentDialog() async {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMethod = 'CASH';
    bool submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: const Row(children: [
            CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
            SizedBox(width: 12),
            Expanded(child: Text('Record Group Society Payment')),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (R)', prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: submitting ? null : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Payment Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
                      child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payments_outlined)),
                    items: ['CASH', 'CARD', 'EFT', 'DEBIT_ORDER', 'OTHER']
                        .map((method) => DropdownMenuItem(value: method, child: Text(method.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: submitting ? null : (value) => setDialogState(() => selectedMethod = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference Number')),
                  const SizedBox(height: 12),
                  TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35), borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Group society receipts do not have a premium period. The receipt will be included in the normal cashup.')),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton.icon(
              icon: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(submitting ? 'Recording...' : 'Record & Print'),
              onPressed: submitting ? null : () async {
                final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than zero.')));
                  return;
                }
                setDialogState(() => submitting = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final response = await _membershipService.addGroupSocietyPayment(widget.societyId, {
                    'amountCents': (amount * 100).round(),
                    'paymentDate': DateFormat('yyyy-MM-dd').format(selectedDate),
                    'paymentMethod': selectedMethod,
                    'referenceNo': refController.text.trim(),
                    'notes': notesController.text.trim(),
                    'createdBy': prefs.getString('userId') ?? 'unknown',
                    'deviceId': prefs.getString('deviceId') ?? 'ERP-ONLINE',
                    'terminalId': prefs.getString('terminalId'),
                    'location': prefs.getString('location'),
                  });
                  if (response.receipts.isNotEmpty) {
                    final printFailures = <String>[];
                    for (final receipt in response.receipts) {
                      try {
                        await PosPrintingService().queueReceipt(receipt.id);
                      } catch (_) {
                        printFailures.add(receipt.receiptNo);
                      }
                    }
                    if (printFailures.isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          'Payment recorded. ${printFailures.length} receipt(s) could not be queued for printing.',
                        ),
                      ));
                    }
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  setDialogState(() => submitting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Payment failed: $error'))));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await _fetchDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded and added to cashup.')));
    }
  }

  Future<void> _showAdjustmentDialog() async {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String direction = 'CREDIT';
    bool submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [
            CircleAvatar(child: Icon(Icons.tune_rounded)),
            SizedBox(width: 12),
            Expanded(child: Text('Request Balance Adjustment')),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: direction,
                  decoration: const InputDecoration(labelText: 'Adjustment Direction'),
                  items: const [
                    DropdownMenuItem(value: 'CREDIT', child: Text('Credit — add to balance')),
                    DropdownMenuItem(value: 'DEBIT', child: Text('Debit — reduce balance')),
                  ],
                  onChanged: submitting ? null : (value) => setDialogState(() => direction = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Adjustment Amount (R)', prefixText: 'R '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference Number')),
                const SizedBox(height: 12),
                TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Reason / Notes'), maxLines: 3),
                const SizedBox(height: 12),
                _approvalDocumentNotice('A supporting document must be attached in the Documents tab before this request can be submitted.'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: submitting ? null : () async {
                final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than zero.')));
                  return;
                }
                setDialogState(() => submitting = true);
                try {
                  final attachments = await _membershipService.getGroupSocietyAttachmentIds(widget.societyId);
                  if (attachments.isEmpty) throw AppException('Attach at least one supporting document before submitting the adjustment.');
                  final prefs = await SharedPreferences.getInstance();
                  await _membershipService.adjustGroupSocietyBalance(widget.societyId, {
                    'amountCents': (amount * 100).round(),
                    'adjustmentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    'direction': direction,
                    'referenceNo': refController.text.trim(),
                    'notes': notesController.text.trim(),
                    'requestedBy': prefs.getString('userId') ?? 'unknown',
                    'supportingAttachmentIds': attachments,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  setDialogState(() => submitting = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$error'))));
                }
              },
              icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.approval_outlined),
              label: Text(submitting ? 'Submitting...' : 'Submit for Approval'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await _fetchDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance adjustment submitted for approval.')));
    }
  }

  Widget _approvalDocumentNotice(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.attach_file_rounded, size: 20, color: Colors.amber.shade900),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: Colors.amber.shade900))),
    ]),
  );

  Future<void> _requestStatus(String targetStatus) async {
    final requiresDocument = targetStatus == 'SUSPENDED' || targetStatus == 'CLOSED';
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          CircleAvatar(child: Icon(targetStatus == 'ACTIVE' ? Icons.play_arrow_rounded : targetStatus == 'SUSPENDED' ? Icons.pause_rounded : Icons.lock_outline_rounded)),
          const SizedBox(width: 12),
          Expanded(child: Text('Request ${targetStatus == 'CLOSED' ? 'Closure' : targetStatus[0] + targetStatus.substring(1).toLowerCase()}')),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Reason / Notes'), maxLines: 4),
            if (requiresDocument) ...[
              const SizedBox(height: 12),
              _approvalDocumentNotice('Suspension and closure require supporting documentation in the Documents tab.'),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit for Approval')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      final attachments = requiresDocument
          ? await _membershipService.getGroupSocietyAttachmentIds(widget.societyId)
          : <String>[];
      if (requiresDocument && attachments.isEmpty) {
        throw AppException('Attach at least one supporting document before requesting this status change.');
      }
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'requestedBy': prefs.getString('userId') ?? 'unknown',
        'notes': notesController.text.trim(),
        'supportingAttachmentIds': attachments,
      };
      if (targetStatus == 'ACTIVE') {
        await _membershipService.activateGroupSociety(widget.societyId, payload);
      } else if (targetStatus == 'SUSPENDED') {
        await _membershipService.suspendGroupSociety(widget.societyId, payload);
      } else {
        await _membershipService.closeGroupSociety(widget.societyId, payload);
      }
      await _fetchDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$targetStatus request submitted for approval.')));
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$error'))));
      }
    }
  }

  Future<void> _printAgreement() async {
    try {
      final Uint8List bytes = await _membershipService.downloadGroupSocietyAgreement(widget.societyId);
      await Printing.layoutPdf(
        name: 'Group Society Agreement - ${_society?.groupNo ?? widget.societyId}',
        onLayout: (_) async => bytes,
      );
      await _fetchDetails();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Agreement could not be printed: $error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_partner?.fullName ?? _society?.displayName ?? 'Society Details'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
          if (_society != null)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditDialog();
                if (val == 'agreement') _printAgreement();
                if (val == 'activate') _requestStatus('ACTIVE');
                if (val == 'suspend') _requestStatus('SUSPENDED');
                if (val == 'close') _requestStatus('CLOSED');
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Details'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'agreement', child: ListTile(leading: Icon(Icons.description_outlined), title: Text('Print Agreement'), contentPadding: EdgeInsets.zero)),
                if (_society!.pendingAction == null && _society!.status != 'ACTIVE') const PopupMenuItem(value: 'activate', child: ListTile(leading: Icon(Icons.play_circle_outline), title: Text('Request Activation'), contentPadding: EdgeInsets.zero)),
                if (_society!.pendingAction == null && _society!.status != 'SUSPENDED') const PopupMenuItem(value: 'suspend', child: ListTile(leading: Icon(Icons.pause_circle_outline), title: Text('Request Suspension'), contentPadding: EdgeInsets.zero)),
                if (_society!.pendingAction == null && _society!.status != 'CLOSED') const PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Request Closure'), contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Contacts'), Tab(text: 'Documents'), Tab(text: 'Statement')],
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _society != null ? _buildOverviewTab(colorScheme) : const Center(child: Text('No data available')),
                    _buildContactsTab(colorScheme),
                    _buildDocumentsTab(),
                    _buildHistoryTab(colorScheme)
                  ],
                ),
      floatingActionButton: _buildMultiActionFAB(colorScheme),
    );
  }

  Widget _buildMultiActionFAB(ColorScheme colorScheme) {
    if (_society == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'pay') _showAddPaymentDialog();
        if (val == 'adjust') _showAdjustmentDialog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white),
            SizedBox(width: 8),
            Text('TRANSACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'pay', child: ListTile(leading: Icon(Icons.add_card, color: Colors.green), title: Text('Record Payment'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'adjust', child: ListTile(leading: Icon(Icons.tune, color: Colors.blue), title: Text('Request Balance Adjustment'), contentPadding: EdgeInsets.zero)),
      ],
    );
  }

  Widget _buildOverviewTab(ColorScheme colorScheme) {
    final s = _society!;
    return RefreshIndicator(
      onRefresh: _fetchDetails,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHeader(s, colorScheme),
            if (s.pendingAction != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.shade200)),
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Approval pending${s.requestedStatus == null ? '' : ' for ${s.requestedStatus}'}', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber.shade900))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _buildQuickStats(s),
            const SizedBox(height: 32),
            _buildSectionHeader(Icons.business_rounded, 'Group Partner'),
            const SizedBox(height: 12),
            if (_partner != null) _buildPartnerProfileCard(_partner!, colorScheme),
            const SizedBox(height: 32),
            _buildSectionHeader(Icons.analytics_outlined, 'Activity Context'),
            const SizedBox(height: 12),
            _buildContextGrid(s),
            const SizedBox(height: 100), // FAB spacing
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHeader(GroupSociety s, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Balance', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
              _buildStatusPill(s.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'R ${s.availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _buildHeaderInfoItem(Icons.group_outlined, 'Group No', s.groupNo),
              _buildHeaderInfoItem(Icons.category_outlined, 'Type', s.societyType),
              _buildHeaderInfoItem(
                Icons.inventory_2_outlined,
                'Product',
                [s.productCode, s.productDescription]
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .join(' - ')
                        .trim()
                        .isEmpty
                    ? 'Not linked'
                    : [s.productCode, s.productDescription]
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .join(' - '),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.6), size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickStats(GroupSociety s) {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Total Paid', 'R ${s.totalPaid.toStringAsFixed(2)}', Icons.arrow_upward, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Total Claims', 'R ${s.totalClaimed.toStringAsFixed(2)}', Icons.arrow_downward, Colors.red)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _buildPartnerProfileCard(Partner p, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => PartnerDetailScreen(
              partnerId: p.id,
              title: 'Group Partner Details',
              isMemberContext: false,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(p.fullName.substring(0, 1).toUpperCase(), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Member ID: ${p.number}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextGrid(GroupSociety s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildContextRow(Icons.calendar_today_outlined, 'Last Payment Date', s.lastPaymentDate ?? 'No payments yet'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildContextRow(Icons.money_off_csred_outlined, 'Last Claim Date', s.lastClaimDate ?? 'No claims yet'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildContextRow(Icons.history_outlined, 'Created On', s.createdAt),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildContextRow(Icons.person_outline, 'Created By', s.createdBy),
        ],
      ),
    );
  }

  Widget _buildContextRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color c;
    switch (status.toUpperCase()) {
      case 'ACTIVE': c = Colors.green; break;
      case 'SUSPENDED': c = Colors.orange; break;
      case 'CLOSED': c = Colors.red; break;
      default: c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[800]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[800], letterSpacing: 0.2)),
      ],
    );
  }

  Widget _buildContactsTab(ColorScheme colorScheme) {
    return Stack(children: [
      if (_contacts.isEmpty) _buildEmptyWidget(Icons.contact_phone_outlined, 'No contacts listed')
      else ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final c = _contacts[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: c.primaryContact ? Colors.amber[50] : colorScheme.primaryContainer.withOpacity(0.3),
                child: Icon(c.primaryContact ? Icons.star_rounded : Icons.person_outline_rounded, color: c.primaryContact ? Colors.amber[700] : colorScheme.primary),
              ),
              title: Text(c.contactName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(c.role ?? "Representative"),
              trailing: c.mobileNo != null ? IconButton(icon: const Icon(Icons.phone_outlined, size: 20), onPressed: () {}) : null,
            ),
          );
        },
      ),
      Positioned(bottom: 16, right: 16, child: FloatingActionButton.small(onPressed: _showAddContactDialog, child: const Icon(Icons.person_add))),
    ]);
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const CircleAvatar(child: Icon(Icons.description_outlined)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Group Society Agreement', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Printed ${_society?.agreementPrintCount ?? 0} time(s)${_society?.agreementLastPrintedAt == null ? '' : ' • Last ${_society!.agreementLastPrintedAt}'}'),
              ])),
              FilledButton.icon(onPressed: _printAgreement, icon: const Icon(Icons.print_outlined), label: const Text('Print')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text('Signed Agreement & Supporting Documents', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        AttachmentSection(
          objectId: widget.societyId,
          documentTypeField: 'DOCUMENT-TYPE-GROUP-SOCIETY',
          onAttachmentCountChanged: (count) {
            if (mounted) setState(() => _attachmentCount = count);
          },
        ),
        if (_attachmentCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Upload the signed agreement and supporting documents here.', style: TextStyle(color: Colors.grey.shade600)),
          ),
      ]),
    );
  }

  Widget _buildHistoryTab(ColorScheme colorScheme) {
    if (_payments.isEmpty) return _buildEmptyWidget(Icons.history, 'No transactions found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final isCredit = p.direction.toUpperCase() == 'CREDIT';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isCredit ? Icons.add_rounded : Icons.remove_rounded, color: isCredit ? Colors.green : Colors.red),
            ),
            title: Text('R ${p.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: isCredit ? Colors.green : Colors.red)),
            subtitle: Text('${p.txnType} • ${p.txnDate}', style: const TextStyle(fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Reference', p.referenceNo ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Balance After', 'R ${p.balanceAfter.toStringAsFixed(2)}'),
                    if (p.notes != null && p.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                        child: Text(p.notes!, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700])),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.grey[600], fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]);
  Widget _buildEmptyWidget(IconData i, String m) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 48, color: Colors.grey[200]), const SizedBox(height: 12), Text(m, style: const TextStyle(color: Colors.grey))]));
  Widget _buildErrorWidget() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY'))]));

  Future<void> _showEditDialog() async {
    if (_society == null) return;
    String selectedType = _society!.societyType;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [CircleAvatar(child: Icon(Icons.edit_outlined)), SizedBox(width: 12), Text('Edit Society Details')]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(initialValue: _society!.groupNo, enabled: false, decoration: const InputDecoration(labelText: 'Group Number', helperText: 'The allocated group number cannot be changed.')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Society Type'),
                items: ['GROUP', 'SOCIETY', 'BURIAL'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setDialogState(() => selectedType = value!),
              ),
              const SizedBox(height: 12),
              const Text('Status changes are submitted separately for approval.', style: TextStyle(color: Colors.grey)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () async {
              try {
                await _membershipService.postGroupSocietyUpdate(widget.societyId, {
                  'partnerId': _society!.partnerId,
                  'groupNo': _society!.groupNo,
                  'societyType': selectedType,
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Update failed: $error'))));
              }
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == true) await _fetchDetails();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }
}
