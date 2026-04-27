import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../models/payment_request.dart';
import 'payment_request_detail_screen.dart';

class PaymentRequestListScreen extends StatefulWidget {
  const PaymentRequestListScreen({super.key});

  @override
  State<PaymentRequestListScreen> createState() => _PaymentRequestListScreenState();
}

class _PaymentRequestListScreenState extends State<PaymentRequestListScreen> {
  bool _isLoading = true;
  List<PaymentRequestSummary> _payments = [];
  String? _error;
  String _selectedStatus = 'AWAITING-APPROVAL';

  final List<String> _statuses = [
    'ALL',
    'NEW',
    'AWAITING-APPROVAL',
    'PROCESSED',
    'REJECTED',
    'APPROVED',
    'SENT-TO-BANK'
  ];

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String path = '/v2/payment-request';
      if (_selectedStatus != 'ALL') {
        path += '?status=$_selectedStatus';
      }

      final response = await ApiClient().get(path);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _payments = data.map((json) => PaymentRequestSummary.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load payments: ${response.statusCode}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statuses.length,
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status.replaceAll('-', ' '), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatus = status);
                  _fetchPayments();
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.white,
            ),
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
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchPayments, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return const Center(child: Text('No payment requests found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return ListTile(
          title: Text(payment.recipient, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${payment.paymentReason} - ${payment.reference}'),
              Text('Due: ${payment.dueDate}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R ${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              _buildStatusChip(payment.status),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaymentRequestDetailScreen(paymentId: payment.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PROCESSED':
      case 'APPROVED':
        color = Colors.green;
        break;
      case 'REJECTED':
      case 'FAILED':
        color = Colors.red;
        break;
      case 'AWAITING-APPROVAL':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
