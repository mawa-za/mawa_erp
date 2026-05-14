import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group_society.dart';
import '../models/group_society_contact.dart';
import '../models/group_society_payment.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../../partners/screens/partner_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _membershipService.getGroupSocietyById(widget.societyId),
        _membershipService.getGroupSocietyContacts(widget.societyId),
        _membershipService.getGroupSocietyStatement(widget.societyId),
      ]);

      final society = results[0] as GroupSociety;
      if (mounted) {
        setState(() {
          _society = society;
          _contacts = results[1] as List<GroupSocietyContact>;
          _payments = results[2] as List<GroupSocietyPayment>;
          _isLoading = false;
        });

        // Lazy load partner
        _partnerService.getPartnerById(society.partnerId).then((p) {
          if (mounted) setState(() => _partner = p);
        }).catchError((_) => null);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
                TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: 'Mobile Number')),
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
                final payload = {
                  "contactName": nameController.text.trim(),
                  "role": roleController.text.trim(),
                  "mobileNo": phoneController.text.trim(),
                  "email": emailController.text.trim(),
                  "primaryContact": isPrimary
                };
                try {
                  await _membershipService.addGroupSocietyContact(widget.societyId, payload);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final periodController = TextEditingController(text: DateFormat('yyyyMM').format(DateTime.now()));
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMethod = 'CASH';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (R)'), keyboardType: TextInputType.number),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Payment Date'),
                    child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: ['CASH', 'EFT', 'DEBIT_ORDER', 'OTHER'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setDialogState(() => selectedMethod = v!),
                ),
                TextFormField(controller: periodController, decoration: const InputDecoration(labelText: 'Period (YYYYMM)')),
                TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final payload = {
                  "amountCents": (double.tryParse(amountController.text)! * 100).toInt(),
                  "paymentDate": DateFormat('yyyy-MM-dd').format(selectedDate),
                  "paymentMethod": selectedMethod,
                  "period": periodController.text.trim(),
                  "referenceNo": refController.text.trim(),
                  "notes": notesController.text.trim()
                };
                await _membershipService.addGroupSocietyPayment(widget.societyId, payload);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('RECORD'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _fetchDetails();
  }

  Future<void> _showClaimDebitDialog() async {
    final amountController = TextEditingController();
    final claimNoController = TextEditingController();
    final notesController = TextEditingController();
    DateTime claimDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Debit Claim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: amountController, decoration: const InputDecoration(labelText: 'Claim Amount (R)'), keyboardType: TextInputType.number),
              TextFormField(controller: claimNoController, decoration: const InputDecoration(labelText: 'Claim Number')),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: claimDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setDialogState(() => claimDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Claim Date'),
                  child: Text(DateFormat('yyyy-MM-dd').format(claimDate)),
                ),
              ),
              TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final payload = {
                  "amountCents": (double.tryParse(amountController.text)! * 100).toInt(),
                  "claimDate": DateFormat('yyyy-MM-dd').format(claimDate),
                  "claimNo": claimNoController.text.trim(),
                  "notes": notesController.text.trim()
                };
                await _membershipService.debitGroupSocietyClaim(widget.societyId, payload);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('DEBIT'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _fetchDetails();
  }

  Future<void> _showAdjustmentDialog() async {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    String direction = 'CREDIT';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Balance Adjustment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: direction,
                items: const [DropdownMenuItem(value: 'CREDIT', child: Text('Credit (Add)')), DropdownMenuItem(value: 'DEBIT', child: Text('Debit (Remove)'))],
                onChanged: (v) => setDialogState(() => direction = v!),
              ),
              TextFormField(controller: amountController, decoration: const InputDecoration(labelText: 'Adjustment Amount (R)'), keyboardType: TextInputType.number),
              TextFormField(controller: refController, decoration: const InputDecoration(labelText: 'Reference')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () async {
                final payload = {
                  "amountCents": (double.tryParse(amountController.text)! * 100).toInt(),
                  "adjustmentDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  "direction": direction,
                  "referenceNo": refController.text.trim(),
                };
                await _membershipService.adjustGroupSocietyBalance(widget.societyId, payload);
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('APPLY'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _fetchDetails();
  }

  Future<void> _statusAction(Future<void> Function(String) action, String msg) async {
    setState(() => _isLoading = true);
    try {
      await action(widget.societyId);
      _fetchDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_partner?.fullName ?? 'Society Details'),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
          if (_society != null)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditDialog();
                if (val == 'activate') _statusAction(_membershipService.activateGroupSociety, 'Society activated');
                if (val == 'suspend') _statusAction(_membershipService.suspendGroupSociety, 'Society suspended');
                if (val == 'close') _statusAction(_membershipService.closeGroupSociety, 'Account closed');
                if (val == 'delete') _deleteSociety();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                if (_society!.status != 'ACTIVE') const PopupMenuItem(value: 'activate', child: ListTile(leading: Icon(Icons.play_circle_outline), title: Text('Activate'), contentPadding: EdgeInsets.zero)),
                if (_society!.status != 'SUSPENDED') const PopupMenuItem(value: 'suspend', child: ListTile(leading: Icon(Icons.pause_circle_outline), title: Text('Suspend'), contentPadding: EdgeInsets.zero)),
                if (_society!.status != 'CLOSED') const PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Close Account'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete'), contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Contacts'), Tab(text: 'Statement')], labelColor: colorScheme.primary, unselectedLabelColor: Colors.grey),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _error != null ? _buildErrorWidget() : TabBarView(
        controller: _tabController,
        children: [ _buildOverviewTab(colorScheme), _buildContactsTab(colorScheme), _buildHistoryTab(colorScheme) ],
      ),
      floatingActionButton: _buildMultiActionFAB(colorScheme),
    );
  }

  Widget _buildMultiActionFAB(ColorScheme colorScheme) {
    if (_society == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'pay') _showAddPaymentDialog();
        if (val == 'claim') _showClaimDebitDialog();
        if (val == 'adjust') _showAdjustmentDialog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, color: Colors.white), SizedBox(width: 8), Text('TRANSACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'pay', child: ListTile(leading: Icon(Icons.add_card, color: Colors.green), title: Text('Record Payment'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'claim', child: ListTile(leading: Icon(Icons.money_off, color: Colors.red), title: Text('Debit Claim'), contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'adjust', child: ListTile(leading: Icon(Icons.tune, color: Colors.blue), title: Text('Adjustment'), contentPadding: EdgeInsets.zero)),
      ],
    );
  }

  Widget _buildOverviewTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildStatusBanner(_society!),
        const SizedBox(height: 20),
        _buildFinancialGrid(_society!),
        const SizedBox(height: 24),
        _buildSectionHeader(Icons.business_outlined, 'Linked Partner'),
        const SizedBox(height: 12),
        if (_partner != null) _buildPartnerCard(_partner!, colorScheme),
        const SizedBox(height: 24),
        _buildSectionHeader(Icons.info_outline, 'Activity Context'),
        const SizedBox(height: 12),
        _buildInfoCard(_society!),
      ]),
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
          return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: ListTile(leading: CircleAvatar(backgroundColor: c.primaryContact ? Colors.amber[50] : colorScheme.primaryContainer.withOpacity(0.3), child: Icon(c.primaryContact ? Icons.star : Icons.person, color: c.primaryContact ? Colors.amber[700] : colorScheme.primary)), title: Text(c.contactName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(c.role ?? "Representative"), trailing: c.mobileNo != null ? const Icon(Icons.phone, size: 16) : null));
        },
      ),
      Positioned(bottom: 16, right: 16, child: FloatingActionButton.small(onPressed: _showAddContactDialog, child: const Icon(Icons.person_add))),
    ]);
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
          elevation: 0, margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ExpansionTile(
            leading: Icon(isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isCredit ? Colors.green : Colors.red),
            title: Text('R ${p.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: isCredit ? Colors.green : Colors.red)),
            subtitle: Text('${p.txnType} • ${p.txnDate}'),
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                _buildInfoRow('Reference', p.referenceNo ?? 'N/A'),
                _buildInfoRow('Balance After', 'R ${p.balanceAfter.toStringAsFixed(2)}'),
                if (p.notes != null) Text(p.notes!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ])),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(GroupSociety s) {
    Color c; switch(s.status.toUpperCase()){case 'ACTIVE': c=Colors.green; break; case 'SUSPENDED': c=Colors.grey; break; case 'CLOSED': c=Colors.red; break; default: c=Colors.orange;}
    return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Center(child: Text(s.status.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.bold, letterSpacing: 1))));
  }

  Widget _buildFinancialGrid(GroupSociety s) => GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6, children: [_buildStatCard('Balance', 'R ${s.availableBalance.toStringAsFixed(2)}', Colors.green), _buildStatCard('Total Paid', 'R ${s.totalPaid.toStringAsFixed(2)}', Colors.blue), _buildStatCard('Total Claims', 'R ${s.totalClaimed.toStringAsFixed(2)}', Colors.red), _buildStatCard('Group No', s.groupNo, Colors.grey[800]!)]);
  Widget _buildStatCard(String l, String v, Color c) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(l, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 4), FittedBox(child: Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 17)))])));
  Widget _buildPartnerCard(Partner p, ColorScheme cs) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PartnerDetailScreen(partnerId: p.id))), leading: CircleAvatar(backgroundColor: cs.secondaryContainer, child: const Icon(Icons.business, size: 20)), title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text('No: ${p.number}'), trailing: const Icon(Icons.chevron_right, size: 16)));
  Widget _buildInfoCard(GroupSociety s) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [_buildInfoRow('Type', s.societyType), _buildInfoRow('Last Payment', s.lastPaymentDate ?? 'Never'), _buildInfoRow('Last Claim', s.lastClaimDate ?? 'Never')])));
  Widget _buildInfoRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.grey[600], fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]);
  Widget _buildSectionHeader(IconData i, String t) => Row(children: [Icon(i, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5))]);
  Widget _buildEmptyWidget(IconData i, String m) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text(m, style: const TextStyle(color: Colors.grey))]));
  Widget _buildErrorWidget() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY'))]));
  
  Future<void> _deleteSociety() async {
    final bool? confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Society'), content: const Text('Permanently delete this society?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('DELETE'))]));
    if (confirm == true) { setState(() => _isLoading = true); try { await _membershipService.deleteGroupSociety(widget.societyId); if (mounted) Navigator.pop(context, true); } catch (e) { if (mounted) setState(() => _isLoading = false); } }
  }

  Future<void> _showEditDialog() async {
    if (_society == null) return;
    final groupNoController = TextEditingController(text: _society!.groupNo);
    final balanceController = TextEditingController(text: _society!.availableBalance.toStringAsFixed(2));
    String selectedType = _society!.societyType; String selectedStatus = _society!.status;
    final result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: const Text('Edit Society'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: groupNoController, decoration: const InputDecoration(labelText: 'Group Number')), DropdownButtonFormField<String>(value: selectedType, items: ['GROUP', 'SOCIETY', 'BURIAL'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setDialogState(() => selectedType = v!)), DropdownButtonFormField<String>(value: selectedStatus, items: ['ACTIVE', 'INACTIVE', 'DORMANT'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setDialogState(() => selectedStatus = v!))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), FilledButton(onPressed: () async { final payload = {"partnerId": _society!.partnerId, "groupNo": groupNoController.text, "societyType": selectedType, "status": selectedStatus, "openingBalanceCents": (double.tryParse(balanceController.text)! * 100).toInt() }; await _membershipService.postGroupSocietyUpdate(widget.societyId, payload); if (context.mounted) Navigator.pop(context, true); }, child: const Text('SAVE'))])));
    if (result == true) _fetchDetails();
  }

  @override void dispose() { _tabController.dispose(); super.dispose(); }
}
