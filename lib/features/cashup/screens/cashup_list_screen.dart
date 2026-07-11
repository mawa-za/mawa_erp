import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/user_service.dart';
import '../models/cashup.dart';
import '../services/cashup_service.dart';
import 'cashup_detail_screen.dart';

class CashupListScreen extends StatefulWidget {
  const CashupListScreen({super.key});

  @override
  State<CashupListScreen> createState() => _CashupListScreenState();
}

class _CashupListScreenState extends State<CashupListScreen> {
  final CashupService _cashupService = CashupService();
  final UserService _userService = UserService();
  List<Cashup> _cashups = [];
  final Map<String, String> _userNames = {};
  bool _isLoading = true;
  String? _error;

  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCashups();
  }

  Future<void> _fetchCashups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fromStr = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      
      final cashups = await _cashupService.getCashups(
        userId: _userIdController.text.isEmpty ? null : _userIdController.text,
        fromDate: fromStr,
        toDate: toStr,
      );

      // Fetch user details for unique user IDs
      final userIds = cashups.map((c) => c.userId).toSet();
      for (final id in userIds) {
        if (!_userNames.containsKey(id)) {
          try {
            final user = await _userService.getUser(id);
            _userNames[id] = user.displayName ?? user.username;
          } catch (e) {
            debugPrint('Error fetching user $id: $e');
            _userNames[id] = id; // Fallback to ID
          }
        }
      }

      setState(() {
        _cashups = cashups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Cashups'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCashups,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _cashups.isEmpty
                  ? _buildEmptyWidget()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cashups.length,
                      itemBuilder: (context, index) {
                        final cashup = _cashups[index];
                        return _buildCashupCard(cashup);
                      },
                    ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchCashups, child: const Text('RETRY')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No cashups found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCashupCard(Cashup cashup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CashupDetailScreen(cashupId: cashup.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cashup #${cashup.cashupNo}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(cashup.cashupDate, 
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (cashup.status.toLowerCase() == 'completed' ? Colors.green : Colors.blue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cashup.status.toUpperCase(),
                      style: TextStyle(
                        color: cashup.status.toLowerCase() == 'completed' ? Colors.green.shade700 : Colors.blue.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniInfo('Receipts', cashup.receiptCount.toString()),
                  _buildMiniInfo('User', _userNames[cashup.userId] ?? cashup.userId),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(
                        'R ${cashup.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Filter Cashups', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _selectDate(context, true);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_fromDate == null 
                          ? 'From' 
                          : DateFormat('MMM dd').format(_fromDate!)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _selectDate(context, false);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_toDate == null 
                          ? 'To' 
                          : DateFormat('MMM dd').format(_toDate!)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _userIdController.clear();
                  _fromDate = null;
                  _toDate = null;
                });
                Navigator.pop(context);
                _fetchCashups();
              },
              child: const Text('CLEAR ALL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _fetchCashups();
              },
              child: const Text('APPLY FILTERS'),
            ),
          ],
        ),
      ),
    );
  }
}
