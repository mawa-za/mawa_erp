import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../partners/models/partner.dart';
import '../models/payroll_batch.dart';
import '../services/payroll_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PayrollBatchCreateScreen extends StatefulWidget {
  final String? batchId;
  const PayrollBatchCreateScreen({super.key, this.batchId});

  @override
  State<PayrollBatchCreateScreen> createState() => _PayrollBatchCreateScreenState();
}

class _PayrollBatchCreateScreenState extends State<PayrollBatchCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Batch Headers
  final _batchNoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _payPeriodController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();

  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;
  bool _isLoading = false;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.batchId != null) {
      _loadBatchData();
    } else {
      final now = DateTime.now();
      _payPeriodController.text = DateFormat('yyyyMM').format(now);
      _batchNoController.text = 'PAY-${_payPeriodController.text}-001';
      _descriptionController.text = 'Salary Payment - ${DateFormat('MMMM yyyy').format(now)}';
    }
  }

  Future<void> _loadBatchData() async {
    setState(() => _isLoading = true);
    try {
      final detail = await PayrollService().getPayrollBatch(widget.batchId!);
      setState(() {
        _batchNoController.text = detail.batchNo;
        _descriptionController.text = detail.description;
        _payPeriodController.text = detail.payPeriod;
        _notesController.text = detail.notes;
        try {
          _paymentDate = DateFormat('yyyy-MM-dd').parse(detail.paymentDate);
        } catch (_) {
          _paymentDate = DateTime.now();
        }

        _items.clear();
        for (var item in detail.items) {
          _items.add({
            'id': item.id,
            'partner': Partner(
              id: item.employeeId ?? '',
              number: item.employeeNo ?? '',
              type: 'INDIVIDUAL',
              name1: '',
              name2: item.employeeName ?? '',
              name3: '',
              identityNumber: '',
              status: 'ACTIVE',
            ),
            'amount': TextEditingController(text: item.amount.toStringAsFixed(2)),
            'paymentReference': TextEditingController(text: item.paymentReference),
            'salaryReference': TextEditingController(text: item.salaryReference),
            'bankName': item.bankName,
            'branchCode': item.branchCode,
            'accountNo': item.accountNo,
            'accountType': item.accountType,
            'accountHolderName': item.accountHolderName,
          });
        }
        if (_items.isNotEmpty) {
          _expandedIndex = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error loading batch: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addItem() {
    setState(() {
      _items.add({
        'partner': null, // Selected Partner
        'amount': TextEditingController(),
        'paymentReference': TextEditingController(),
        'salaryReference': TextEditingController(),
        'bankName': null,
        'branchCode': null,
        'accountNo': null,
        'accountType': null,
        'accountHolderName': null,
      });
      _expandedIndex = _items.length - 1;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    for (var item in _items) {
      total += double.tryParse((item['amount'] as TextEditingController).text) ?? 0.0;
    }
    return total;
  }

  Future<List<Partner>> _searchEmployees(String query) async {
    try {
      final response = await ApiClient().get('/v2/employment/employees');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final term = query.trim().toLowerCase();
        return data
            .map((json) => Partner.fromJson(Map<String, dynamic>.from(json)))
            .where((partner) => term.isEmpty ||
                partner.fullName.toLowerCase().contains(term) ||
                partner.number.toLowerCase().contains(term))
            .take(50)
            .toList();
      }
      throw AppException('Failed to load active employees');
    } catch (e) {
      debugPrint('Error searching employees: $e');
      return [];
    }
  }

  Future<void> _loadApprovedBankDetails(int index, Partner partner) async {
    try {
      final employmentResponse = await ApiClient().get(
        '/v2/employment',
        queryParameters: {'partnerId': partner.id, 'status': 'ACTIVE'},
      );
      if (employmentResponse.statusCode != 200) {
        throw AppException('Unable to locate active employment');
      }
      final employments = jsonDecode(employmentResponse.body) as List<dynamic>;
      if (employments.isEmpty) throw AppException('Employee has no active employment record');
      final employmentId = (employments.first['id'] ?? '').toString();
      final bankResponse = await ApiClient().get('/v2/employment/$employmentId/bank-details');
      if (bankResponse.statusCode != 200) throw AppException('Unable to load approved banking details');
      final body = jsonDecode(bankResponse.body);
      final accounts = body is Map && body['partnerBankAccountDtoList'] is List
          ? body['partnerBankAccountDtoList'] as List<dynamic>
          : const <dynamic>[];
      final active = accounts.cast<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) =>
          (e['status'] ?? '').toString().toUpperCase() == 'ACTIVE').toList();
      if (active.isEmpty) throw AppException('Employee has no approved active banking details');
      final bank = active.first;
      if (!mounted || index >= _items.length) return;
      setState(() {
        final item = _items[index];
        item['bankName'] = bank['bankName']?.toString();
        item['branchCode'] = bank['branchCode']?.toString();
        item['accountNo'] = bank['accountNumber']?.toString();
        item['accountType'] = bank['accountType']?.toString();
        item['accountHolderName'] = bank['accountHolder']?.toString();
        item['bankError'] = null;
      });
    } catch (e) {
      if (!mounted || index >= _items.length) return;
      setState(() {
        _items[index]['bankError'] = friendlyErrorMessage(e);
        _items[index]['bankName'] = null;
        _items[index]['accountNo'] = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_items[index]['bankError'])));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one employee payment'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final missingBank = _items.where((item) => (item['accountNo'] ?? '').toString().isEmpty).toList();
    if (missingBank.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every employee must have approved banking details before the payroll batch can be created.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'batchNo': _batchNoController.text,
        'description': _descriptionController.text,
        'payPeriod': _payPeriodController.text,
        'paymentDate': DateFormat('yyyy-MM-dd').format(_paymentDate),
        'notes': _notesController.text,
        'items': _items.map((item) {
          final partner = item['partner'] as Partner?;
          final amountDouble = double.tryParse((item['amount'] as TextEditingController).text) ?? 0.0;
          return {
            'id': item['id'],
            'employeeId': partner?.id,
            'employeeNo': partner?.number,
            'employeeName': partner?.fullName,
            'bankName': item['bankName'],
            'branchCode': item['branchCode'],
            'accountNo': item['accountNo'],
            'accountType': item['accountType'],
            'accountHolderName': item['accountHolderName'],
            'amountCents': (amountDouble * 100).round(),
            'paymentReference': (item['paymentReference'] as TextEditingController).text,
            'salaryReference': (item['salaryReference'] as TextEditingController).text,
          };
        }).toList(),
      };

      if (widget.batchId != null) {
        await PayrollService().updatePayrollBatch(widget.batchId!, payload);
      } else {
        await PayrollService().createPayrollBatch(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payroll batch ${widget.batchId != null ? 'updated' : 'created'} successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.batchId != null ? 'Edit Payroll Run' : 'New Payroll Run'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: Column(
              children: [
                _buildQuickSummary(colorScheme),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionHeader(Icons.info_outline_rounded, 'BATCH DETAILS'),
                      const SizedBox(height: 12),
                      _buildBatchHeader(colorScheme),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(Icons.people_outline_rounded, 'EMPLOYEE PAYMENTS'),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('ADD EMPLOYEE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        _buildEmptyState()
                      else
                        ...List.generate(_items.length, (index) => _buildItemCard(index, colorScheme)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(colorScheme),
    );
  }

  Widget _buildQuickSummary(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem('Employees', _items.length.toString(), colorScheme),
          _buildSummaryItem('Total Amount', 'R ${_calculateTotal().toStringAsFixed(2)}', colorScheme, isPrimary: true),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, ColorScheme colorScheme, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: isPrimary ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          fontSize: isPrimary ? 16 : 14, 
          fontWeight: isPrimary ? FontWeight.w900 : FontWeight.bold,
          color: isPrimary ? colorScheme.primary : Colors.black87,
        )),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.group_add_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No employees added yet', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addItem,
              style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: Colors.grey[100], foregroundColor: Colors.black87),
              child: const Text('Add Your First Employee'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputLabel('Batch Number', 
                  TextFormField(
                    controller: _batchNoController,
                    decoration: _inputDecoration('e.g. PAY-202503-001'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  )
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputLabel('Pay Period', 
                  TextFormField(
                    controller: _payPeriodController,
                    decoration: _inputDecoration('YYYYMM'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputLabel('Description', 
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration('Purpose of this payroll run'),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            )
          ),
          const SizedBox(height: 16),
          _buildInputLabel('Payment Date', 
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _paymentDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEEE, d MMMM yyyy').format(_paymentDate), style: const TextStyle(fontSize: 14)),
                    Icon(Icons.calendar_month_rounded, size: 20, color: colorScheme.primary),
                  ],
                ),
              ),
            )
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, ColorScheme colorScheme) {
    final item = _items[index];
    final bool hasEmployee = item['partner'] != null;
    final bool isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: isExpanded ? colorScheme.primary.withOpacity(0.1) : Colors.transparent),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
            borderRadius: isExpanded 
                ? const BorderRadius.vertical(top: Radius.circular(16)) 
                : BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasEmployee ? (isExpanded ? colorScheme.primary.withOpacity(0.05) : Colors.white) : Colors.grey[50],
                borderRadius: isExpanded 
                    ? const BorderRadius.vertical(top: Radius.circular(16)) 
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: hasEmployee ? colorScheme.primary : Colors.grey[300],
                    child: Text((index + 1).toString(), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasEmployee ? (item['partner'] as Partner).fullName : 'Select Employee',
                          style: TextStyle(fontWeight: FontWeight.bold, color: hasEmployee ? Colors.black87 : Colors.grey[500]),
                        ),
                        if (!isExpanded && hasEmployee)
                          Text(
                            'Amount: R ${(double.tryParse((item['amount'] as TextEditingController).text) ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildEmployeeSearch(index, colorScheme),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputLabel('Amount',
                          TextFormField(
                            controller: item['amount'],
                            decoration: _inputDecoration('0.00').copyWith(prefixText: 'R '),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildApprovedBankCard(item, colorScheme),
                  const SizedBox(height: 16),
                  _buildInputLabel('Payment Reference', 
                    TextFormField(
                      controller: item['paymentReference'],
                      decoration: _inputDecoration('Appears on their statement'),
                    )
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovedBankCard(Map<String, dynamic> item, ColorScheme colorScheme) {
    final error = item['bankError']?.toString();
    final account = item['accountNo']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error == null ? colorScheme.primary.withOpacity(0.05) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error == null ? colorScheme.primary.withOpacity(0.2) : Colors.red.shade200),
      ),
      child: account == null || account.isEmpty
          ? Text(error ?? 'Select an employee to load approved banking details.',
              style: TextStyle(color: error == null ? Colors.black54 : Colors.red.shade700))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('APPROVED BANKING DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${item['accountHolderName'] ?? '-'} • ${item['bankName'] ?? '-'}'),
                Text('$account • ${item['accountType'] ?? '-'} • Universal branch ${item['branchCode'] ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
    );
  }

  Widget _buildEmployeeSearch(int index, ColorScheme colorScheme) {
    final item = _items[index];
    final controller = TextEditingController(text: item['partner']?.fullName ?? '');
    
    return SearchAnchor(
      isFullScreen: false,
      viewConstraints: const BoxConstraints(maxHeight: 420),
      builder: (context, controller) {
        return TextField(
          controller: controller,
          onTap: () => controller.openView(),
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Search by name or number...',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final employees = await _searchEmployees(controller.text);
        if (employees.isEmpty && controller.text.length >= 2) {
          return [const ListTile(title: Text('No employees found'))];
        }
        return employees.map((p) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
          title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(p.number),
          onTap: () async {
            setState(() {
              item['partner'] = p;
              item['bankName'] = null;
              item['accountNo'] = null;
              item['bankError'] = null;
              (item['paymentReference'] as TextEditingController).text = 'SALARY ${DateFormat('MMM yyyy').format(_paymentDate).toUpperCase()}';
              (item['salaryReference'] as TextEditingController).text = '${_batchNoController.text}-${p.number}';
              controller.closeView(p.fullName);
            });
            await _loadApprovedBankDetails(index, p);
          },
        )).toList();
      },
    );
  }

  Widget _buildInputLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Text(widget.batchId != null ? 'UPDATE PAYROLL BATCH' : 'CREATE PAYROLL BATCH', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _batchNoController.dispose();
    _descriptionController.dispose();
    _payPeriodController.dispose();
    _notesController.dispose();
    for (var item in _items) {
      (item['amount'] as TextEditingController).dispose();
      (item['paymentReference'] as TextEditingController).dispose();
      (item['salaryReference'] as TextEditingController).dispose();
    }
    super.dispose();
  }
}
