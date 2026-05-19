import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../partners/models/partner.dart';
import '../services/payroll_service.dart';
import '../../../core/widgets/app_dropdown.dart';

class PayrollBatchCreateScreen extends StatefulWidget {
  const PayrollBatchCreateScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _payPeriodController.text = DateFormat('yyyyMM').format(now);
    _batchNoController.text = 'PAY-${_payPeriodController.text}-001';
    _descriptionController.text = 'Salary Payment - ${DateFormat('MMMM yyyy').format(now)}';
  }

  void _addItem() {
    setState(() {
      _items.add({
        'partner': null, // Selected Partner
        'amount': TextEditingController(),
        'paymentReference': TextEditingController(),
        'salaryReference': TextEditingController(),
        'bankName': null,
        'branchCode': TextEditingController(),
        'accountNo': TextEditingController(),
        'accountType': null,
        'accountHolderName': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
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
    if (query.length < 2) return [];
    try {
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching employees: $e');
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one employee payment'), behavior: SnackBarBehavior.floating),
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
            'employeeId': partner?.id,
            'employeeNo': partner?.number,
            'employeeName': partner?.fullName,
            'bankName': item['bankName'],
            'branchCode': (item['branchCode'] as TextEditingController).text,
            'accountNo': (item['accountNo'] as TextEditingController).text,
            'accountType': item['accountType'],
            'accountHolderName': (item['accountHolderName'] as TextEditingController).text,
            'amountCents': (amountDouble * 100).round(),
            'paymentReference': (item['paymentReference'] as TextEditingController).text,
            'salaryReference': (item['salaryReference'] as TextEditingController).text,
          };
        }).toList(),
      };

      await PayrollService().createPayrollBatch(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll batch created successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('New Payroll Run'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
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
      bottomNavigationBar: _buildBottomBar(colorScheme),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: hasEmployee ? colorScheme.primary.withOpacity(0.1) : Colors.transparent),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: hasEmployee ? colorScheme.primary.withOpacity(0.05) : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: hasEmployee ? colorScheme.primary : Colors.grey[300],
                  child: Text((index + 1).toString(), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text(
                  hasEmployee ? (item['partner'] as Partner).fullName : 'Select Employee',
                  style: TextStyle(fontWeight: FontWeight.bold, color: hasEmployee ? Colors.black87 : Colors.grey[500]),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildEmployeeSearch(index, colorScheme),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInputLabel('Amount', 
                        TextFormField(
                          controller: item['amount'],
                          decoration: _inputDecoration('0.00').copyWith(prefixText: 'R '),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        )
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildInputLabel('Acc Type', 
                        AppDropdownField(
                          field: 'BANK-ACCOUNT-TYPE',
                          label: 'Select Type',
                          value: item['accountType'],
                          onChanged: (val) => setState(() => item['accountType'] = val),
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputLabel('Bank Name', 
                        AppDropdownField(
                          field: 'BANK-NAME',
                          label: 'Select Bank',
                          value: item['bankName'],
                          onChanged: (val) => setState(() => item['bankName'] = val),
                        )
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputLabel('Branch Code', 
                        TextFormField(
                          controller: item['branchCode'],
                          decoration: _inputDecoration('Code'),
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputLabel('Account Number', 
                  TextFormField(
                    controller: item['accountNo'],
                    decoration: _inputDecoration('Enter account number'),
                  )
                ),
                const SizedBox(height: 12),
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

  Widget _buildEmployeeSearch(int index, ColorScheme colorScheme) {
    final item = _items[index];
    return SearchAnchor(
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
          onTap: () {
            setState(() {
              item['partner'] = p;
              (item['accountHolderName'] as TextEditingController).text = p.fullName;
              (item['paymentReference'] as TextEditingController).text = 'SALARY ${DateFormat('MMM yyyy').format(_paymentDate).toUpperCase()}';
              (item['salaryReference'] as TextEditingController).text = '${_batchNoController.text}-${p.number}';
              controller.closeView(p.fullName);
            });
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
              : const Text('CREATE PAYROLL BATCH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
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
      (item['branchCode'] as TextEditingController).dispose();
      (item['accountNo'] as TextEditingController).dispose();
      (item['accountHolderName'] as TextEditingController).dispose();
    }
    super.dispose();
  }
}
