import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../models/invoice_detail.dart';
import '../../partners/models/partner.dart';
import 'invoice_create_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _isLoading = true;
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
          _error = 'Failed to load invoice details: ${response.statusCode}';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_detail?.number ?? 'Invoice Details', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_detail != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InvoiceCreateScreen(existingInvoice: _detail),
                  ),
                );
                if (result == true) {
                  _fetchInvoiceDetails();
                }
              },
            ),
        ],
      ),
      body: _buildBody(colorScheme),
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
              onPressed: _fetchInvoiceDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_detail == null) {
      return const Center(child: Text('No details found.'));
    }

    final detail = _detail!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.person, 'Customer Information'),
                const SizedBox(height: 8),
                _buildCustomerCard(detail, colorScheme),
                const SizedBox(height: 16),

                _buildSectionHeader(Icons.description, 'General Details'),
                const SizedBox(height: 8),
                _buildGeneralDetailsCard(detail, colorScheme),
                const SizedBox(height: 16),

                _buildSectionHeader(Icons.list_alt, 'Invoice Items'),
                const SizedBox(height: 8),
                _buildItemHeaderRow(),
                ...detail.items.asMap().entries.map((entry) => _buildItemRow(entry.key, entry.value)),

                if (detail.payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(Icons.payment, 'Payment History'),
                  const SizedBox(height: 8),
                  ...detail.payments.map((p) => _buildPaymentRow(p, colorScheme)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _buildBottomSummary(detail, colorScheme),
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

  Widget _buildCustomerCard(InvoiceDetail detail, ColorScheme colorScheme) {
    final customerName = _partner?.fullName ?? detail.customerName;
    final customerNumber = _partner?.number ?? detail.customerNumber;
    final email = _partner?.email;
    final phone = _partner?.phone;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primaryContainer.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.person, size: 20),
            ),
            title: Text(
              customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'No: $customerNumber',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: _buildStatusChip(detail.status),
          ),
          if (email != null && email.isNotEmpty || phone != null && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Row(
                children: [
                  if (email != null && email.isNotEmpty) ...[
                    const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                  ],
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          if (_partner != null && _partner!.addresses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_partner!.addresses.first.line1}, ${_partner!.addresses.first.city}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeneralDetailsCard(InvoiceDetail detail, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildReadOnlyField('Reference', detail.reference.isEmpty ? 'N/A' : detail.reference, Icons.tag),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('Invoice Date', DateFormat('yyyy-MM-dd').format(detail.invoiceDate), Icons.calendar_month)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnlyField('Due Date', detail.dueDate != null ? DateFormat('yyyy-MM-dd').format(detail.dueDate!) : 'N/A', Icons.timer_outlined)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18, child: Text('#', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const Expanded(flex: 30, child: Text('PRODUCT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 40, child: Text('DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 25, child: Text('PRICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const SizedBox(width: 30, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(width: 4),
          const Expanded(flex: 25, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, InvoiceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            child: Text('${index + 1}', 
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400])),
          ),
          Expanded(flex: 30, child: Text(item.productCode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Expanded(flex: 40, child: Text(item.productName, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Expanded(flex: 25, child: Text('R ${item.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10))),
          const SizedBox(width: 4),
          SizedBox(width: 30, child: Text(item.quantity.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
          const SizedBox(width: 4),
          Expanded(flex: 25, child: Text('R ${item.lineTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(InvoicePayment payment, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentMethod, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(payment.paymentDate), style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          Text(payment.referenceNo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(width: 8),
          Text('R ${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildBottomSummary(InvoiceDetail detail, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildSummaryLine('Subtotal', detail.subtotalAmount)),
                const SizedBox(width: 16),
                Expanded(child: _buildSummaryLine('VAT', detail.vatAmount)),
              ],
            ),
            if (detail.discountAmount > 0)
              _buildSummaryLine('Discount', detail.discountAmount, color: Colors.red),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  'R ${detail.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.primary),
                ),
              ],
            ),
            if (detail.paidAmount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                  Text('R ${detail.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(
                    'R ${detail.balanceAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.primary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, double value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        Text('R ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PAID':
        color = Colors.green;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
