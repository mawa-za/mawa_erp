import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../models/invoice.dart';
import 'invoice_create_screen.dart';
import 'invoice_detail_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final String? partnerId;
  final String? partnerName;

  const InvoiceListScreen({super.key, this.partnerId, this.partnerName});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  bool _isLoading = true;
  List<Invoice> _invoices = [];
  String? _error;
  String _selectedStatus = 'ALL';
  DateTime? _selectedDate;

  final List<String> _statuses = ['ALL', 'DRAFT', 'PAID', 'NEW', 'OVERDUE'];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<String, String> queryParams = {};

      if (_selectedStatus != 'ALL') {
        queryParams['status'] = _selectedStatus;
      }

      if (widget.partnerId != null) {
        queryParams['partnerId'] = widget.partnerId!;
      }

      if (_selectedDate != null) {
        queryParams['invoiceDate'] = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      String url = '/v2/invoice';
      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }

      final response = await ApiClient().get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _invoices = data.map((json) => Invoice.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load invoices: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.partnerName != null ? 'Invoices: ${widget.partnerName}' : 'Invoices'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _selectedDate == null ? Icons.calendar_today : Icons.calendar_month,
              size: 20,
              color: _selectedDate == null ? null : colorScheme.primary,
            ),
            onPressed: _pickDate,
            tooltip: 'Filter by Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _fetchInvoices,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const InvoiceCreateScreen()),
          );
          if (result == true) {
            _fetchInvoices();
          }
        },
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ..._statuses.map((status) {
            final isSelected = _selectedStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedStatus = status;
                    });
                    _fetchInvoices();
                  }
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(
                  DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onDeleted: () {
                  setState(() {
                    _selectedDate = null;
                  });
                  _fetchInvoices();
                },
                deleteIconColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchInvoices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No invoices found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            if (_selectedDate != null)
              Text(
                'on ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildSectionHeader(Icons.list_alt, 'Invoice Overview'),
        ),
        _buildListHeaderRow(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            itemCount: _invoices.length,
            itemBuilder: (context, index) {
              final invoice = _invoices[index];
              return _buildInvoiceCard(invoice, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildListHeaderRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        children: [
          SizedBox(width: 44), // Match icon + padding
          Expanded(child: Text('CUSTOMER / REFERENCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          SizedBox(width: 8),
          Text('DATE / DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          SizedBox(width: 100, child: Text('AMOUNT / STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InvoiceDetailScreen(invoiceId: invoice.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${invoice.transactionNumber}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy-MM-dd').format(invoice.date),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  if (invoice.dueDate != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined, 
                          size: 10, 
                          color: (invoice.dueDate!.isBefore(DateTime.now()) && invoice.status.toUpperCase() != 'PAID')
                              ? Colors.red[300]
                              : Colors.grey[400]
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy-MM-dd').format(invoice.dueDate!),
                          style: TextStyle(
                            fontSize: 10, 
                            color: (invoice.dueDate!.isBefore(DateTime.now()) && invoice.status.toUpperCase() != 'PAID')
                                ? Colors.red[700]
                                : Colors.grey[500],
                            fontWeight: (invoice.dueDate!.isBefore(DateTime.now()) && invoice.status.toUpperCase() != 'PAID')
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R ${invoice.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(invoice.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PAID':
        color = Colors.green;
        break;
      case 'OVERDUE':
        color = Colors.red;
        break;
      case 'NEW':
        color = Colors.blue;
        break;
      case 'DRAFT':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
