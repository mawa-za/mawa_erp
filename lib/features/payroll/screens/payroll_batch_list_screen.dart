import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payroll_batch.dart';
import '../services/payroll_service.dart';
import 'payroll_batch_detail_screen.dart';
import 'payroll_batch_create_screen.dart';

class PayrollBatchListScreen extends StatefulWidget {
  const PayrollBatchListScreen({super.key});

  @override
  State<PayrollBatchListScreen> createState() => _PayrollBatchListScreenState();
}

class _PayrollBatchListScreenState extends State<PayrollBatchListScreen> {
  bool _isLoading = true;
  List<PayrollBatchSummary> _allBatches = [];
  List<PayrollBatchSummary> _batches = [];
  String _selectedStatus = 'ALL';
  final List<String> _statuses = ['ALL', 'NEW', 'DRAFT', 'AWAITING-APPROVAL', 'APPROVED', 'PROCESSED', 'PAID', 'FAILED'];
  String? _error;
  late String _selectedPayPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPayPeriod = DateFormat('yyyyMM').format(DateTime.now());
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final batches = await PayrollService().getPayrollBatches(payPeriod: _selectedPayPeriod);
      batches.sort((a, b) {
        final byDate = b.paymentDate.compareTo(a.paymentDate);
        return byDate != 0 ? byDate : b.batchNo.compareTo(a.batchNo);
      });
      setState(() {
        _allBatches = batches;
        _applyStatusFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load payroll batches: $e';
        _isLoading = false;
      });
    }
  }

  void _applyStatusFilter() {
    _batches = _selectedStatus == 'ALL'
        ? List<PayrollBatchSummary>.from(_allBatches)
        : _allBatches.where((batch) => batch.status.toUpperCase() == _selectedStatus).toList();
  }

  Future<void> _selectPayPeriod() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        int.parse(_selectedPayPeriod.substring(0, 4)),
        int.parse(_selectedPayPeriod.substring(4)),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select Pay Period Month',
    );

    if (picked != null) {
      final newPeriod = DateFormat('yyyyMM').format(picked);
      if (newPeriod != _selectedPayPeriod) {
        setState(() {
          _selectedPayPeriod = newPeriod;
        });
        _fetchBatches();
      }
    }
  }

  Future<void> _copyBatch(PayrollBatchSummary batch) async {
    final batchNoController = TextEditingController(text: '${batch.batchNo}-COPY');
    final descriptionController = TextEditingController(text: 'Copy of ${batch.description}');
    final payPeriodController = TextEditingController(text: batch.payPeriod);
    final notesController = TextEditingController(text: 'Copied from batch ${batch.batchNo}');
    DateTime paymentDate = DateTime.now();
    bool copyExcludedItems = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Copy Payroll Batch', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create a new payroll run based on this existing batch.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),
                TextField(
                  controller: batchNoController,
                  decoration: InputDecoration(
                    labelText: 'New Batch No',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payPeriodController,
                  decoration: InputDecoration(
                    labelText: 'Pay Period (YYYYMM)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => paymentDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Payment Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(paymentDate)),
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Copy Excluded Items', style: TextStyle(fontSize: 14)),
                  value: copyExcludedItems,
                  onChanged: (val) => setDialogState(() => copyExcludedItems = val ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('COPY BATCH'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final payload = {
          'batchNo': batchNoController.text,
          'description': descriptionController.text,
          'payPeriod': payPeriodController.text,
          'paymentDate': DateFormat('yyyy-MM-dd').format(paymentDate),
          'notes': notesController.text,
          'copyExcludedItems': copyExcludedItems,
        };
        await PayrollService().copyPayrollBatch(batch.id, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payroll batch copied successfully'), behavior: SnackBarBehavior.floating),
          );
          _fetchBatches();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Payroll Batches'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _selectPayPeriod,
            tooltip: 'Select Period',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBatches,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodIndicator(colorScheme),
          _buildStatusFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PayrollBatchCreateScreen()),
          );
          if (result == true) _fetchBatches();
        },
        label: const Text('New Payroll Run'),
        icon: const Icon(Icons.add_rounded),
        elevation: 4,
      ),
    );
  }

  Widget _buildPeriodIndicator(ColorScheme colorScheme) {
    String formattedDate = '';
    try {
      final year = int.parse(_selectedPayPeriod.substring(0, 4));
      final month = int.parse(_selectedPayPeriod.substring(4));
      formattedDate = DateFormat('MMMM yyyy').format(DateTime(year, month));
    } catch (e) {
      formattedDate = _selectedPayPeriod;
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Showing batches for: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            formattedDate,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
          const Spacer(),
          TextButton(
            onPressed: _selectPayPeriod,
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          return ChoiceChip(
            label: Text(status.replaceAll('-', ' '), style: const TextStyle(fontSize: 10)),
            selected: _selectedStatus == status,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _selectedStatus = status;
              _applyStatusFilter();
            }),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchBatches, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No payroll batches found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 8),
            Text('For period $_selectedPayPeriod',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _batches.length,
      itemBuilder: (context, index) {
        final batch = _batches[index];
        return _buildBatchCard(batch);
      },
    );
  }

  Widget _buildBatchCard(PayrollBatchSummary batch) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PayrollBatchDetailScreen(batchId: batch.id)),
            );
            if (result == true) _fetchBatches();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.batchNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            batch.description,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(batch.status),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAYMENT DATE', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(batch.paymentDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TOTAL AMOUNT', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(
                          'R ${batch.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${batch.itemCount} Employees', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      onSelected: (val) async {
                        if (val == 'copy') {
                          _copyBatch(batch);
                        } else if (val == 'edit') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PayrollBatchCreateScreen(batchId: batch.id),
                            ),
                          );
                          if (result == true) _fetchBatches();
                        }
                      },
                      itemBuilder: (context) => [
                        if (batch.status == 'NEW' || batch.status == 'DRAFT')
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_rounded, size: 20),
                              title: Text('Edit Batch'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            )
                          ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: ListTile(
                            leading: Icon(Icons.copy_rounded, size: 20),
                            title: Text('Duplicate Batch'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PROCESSED':
      case 'PAID':
        color = Colors.green;
        break;
      case 'FAILED':
        color = Colors.red;
        break;
      case 'AWAITING-APPROVAL':
      case 'NEW':
      case 'DRAFT':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.replaceAll('-', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
