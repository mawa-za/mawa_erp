import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../models/payment_request.dart';

class PaymentRequestDetailScreen extends StatefulWidget {
  final String paymentId;
  const PaymentRequestDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentRequestDetailScreen> createState() => _PaymentRequestDetailScreenState();
}

class _PaymentRequestDetailScreenState extends State<PaymentRequestDetailScreen> {
  bool _isLoading = true;
  PaymentRequestDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient().get('/v2/payment-request/${widget.paymentId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _detail = PaymentRequestDetail.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load details: ${response.statusCode}';
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
        title: Text(_detail != null ? 'Request #${_detail!.number}' : 'Payment Detail'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchDetail, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_detail == null) return const Center(child: Text('No data found'));

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryHeader(colorScheme),
          const SizedBox(height: 24),
          _buildSectionTitle('General Information'),
          _buildInfoCard([
            _buildInfoRow('Reference', _detail!.reference),
            _buildInfoRow('Payment Reason', _detail!.paymentReason['description'] ?? ''),
            _buildInfoRow('Payment Method', _detail!.paymentMethod['description'] ?? ''),
            _buildInfoRow('Branch', _detail!.branch['description'] ?? ''),
            _buildInfoRow('Created Date', _detail!.createdDate),
            _buildInfoRow('Due Date', _detail!.dueDate),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Recipient Details'),
          _buildInfoCard([
            _buildInfoRow('Name', '${_detail!.recipient['name2'] ?? ''} ${_detail!.recipient['name1'] ?? ''}'),
            _buildInfoRow('ID Number', _detail!.recipient['identity']?['number'] ?? 'N/A'),
            _buildInfoRow('Partner Number', _detail!.recipient['number'] ?? ''),
            _buildInfoRow('Status', _detail!.recipient['status']?['description'] ?? ''),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Audit Trail'),
          _buildInfoCard([
            _buildInfoRow('Created By', '${_detail!.createdBy['name2'] ?? ''} ${_detail!.createdBy['name1'] ?? ''}'),
            if (_detail!.employeeResponsible != null)
              _buildInfoRow('Responsible', '${_detail!.employeeResponsible!['name2'] ?? ''} ${_detail!.employeeResponsible!['name1'] ?? ''}'),
            _buildInfoRow('Instruction ID', _detail!.instructionId, isSmall: true),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'R ${_detail!.amount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _detail!.paymentReason['code'] ?? 'PAYMENT',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 11 : 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
